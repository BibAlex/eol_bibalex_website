class TraitBank
  class Terms
    class << self
      delegate :connection, to: TraitBank
      delegate :limit_and_skip_clause, to: TraitBank
      delegate :query, to: TraitBank

      CACHE_EXPIRATION_TIME = 1.day

      def count(options = {})
        hidden = options[:include_hidden]
        key = "trait_bank/terms_count"
        key << "/include_hidden" if hidden
        Rails.cache.fetch(key, expires_in: CACHE_EXPIRATION_TIME) do
          res = query(
            "MATCH (term:Term#{hidden ? '' : ' { is_hidden_from_glossary: false }'}) "\
            "WITH count(distinct(term.uri)) AS count "\
            "RETURN count"
          )
          res && res["data"] ? res["data"].first.first : false
        end
      end

      def full_glossary(page = 1, per_page = nil, options = {})
        options ||= {} # callers may pass nil, bypassing the default
        page ||= 1
        per_page ||= Rails.configuration.data_glossary_page_size
        hidden = options[:include_hidden]
        key = "trait_bank/full_glossary/#{page}"
        key << "/include_hidden" if hidden
        Rails.cache.fetch(key, expires_in: CACHE_EXPIRATION_TIME) do
          q = "MATCH (term:Term#{hidden ? '' : ' { is_hidden_from_glossary: false }'}) "\
            "RETURN DISTINCT(term) ORDER BY LOWER(term.name), LOWER(term.uri)"
          q << limit_and_skip_clause(page, per_page)
          result = query(q)
          result["data"] ? result["data"].map {|term| term.first["data"].symbolize_keys} : false
        end
      end

      def sub_glossary(type, page = 1, per_page = nil, options = {})
        count = options[:count]
        qterm = options[:qterm]
        page ||= 1
        per_page ||= Rails.configuration.data_glossary_page_size
        key = "trait_bank/#{type}_glossary/"\
          "#{count ? :count : "#{page}/#{per}"}/#{qterm ? qterm : :full}"
        Rails.logger.info("KK TraitBank key: #{key}")
        Rails.cache.fetch(key, expires_in: CACHE_EXPIRATION_TIME) do
          q = "MATCH (term:Term"
          q << " { is_hidden_from_glossary: false }" unless qterm
          q << ")<-[:#{type}]-(n) "
          q << "WHERE LOWER(term.name) CONTAINS \"#{qterm.gsub(/"/, '').downcase}\" " if qterm
          if count
            q << "WITH COUNT(DISTINCT(term.uri)) AS count RETURN count"
          else
            q << "RETURN DISTINCT(term) ORDER BY LOWER(term.name), LOWER(term.uri)"
            q << limit_and_skip_clause(page, per_page)
          end
          result = query(q)
          if result["data"]
            if count
              result["data"].first.first
            else
              all = result["data"].map {|term| term.first["data"].symbolize_keys }
              all.map! {|h| {name: h[:name], uri: h[:uri]}} if qterm
              all
            end
          else
            false
          end
        end
      end

      def predicate_glossary(page = nil, per_page = nil, qterm = nil)
        sub_glossary("predicate", page, per_page, qterm: qterm)
      end

      def name_for_pred_uri(uri)
        key = "trait_bank/predicate_uris_to_names"
        map = Rails.cache.fetch(key, expires_in: CACHE_EXPIRATION_TIME) do
          predicate_glossary.map {|item| [item[:uri], item[:name]] }.to_h
        end

        map[uri]
      end

      def name_for_obj_uri(uri)
        key = "trait_bank/object_uris_to_names"
        map = Rails.cache.fetch(key, :expires_in => CACHE_EXPIRATION_TIME) do
          object_term_glossary.map { |item| [item[:uri], item[:name]] }.to_h
        end

        map[uri]
      end

      def name_for_units_uri(uri)
        key = "trait_bank/units_uris_to_names"
        map = Rails.cache.fetch(key, expires_in: CACHE_EXPIRATION_TIME) do
          units_glossary.map {|item| [item[:uri], item[:name]]}.to_h
        end
        map[uri]
      end

      def object_term_glossary(page = nil, per_page = nil, qterm = nil)
        sub_glossary("object_term", page, per_page, qterm: qterm)
      end

      def units_glossary(page = nil, per_page = nil, qterm = nil)
        sub_glossary("units_term", page, per_page, qterm: qterm)
      end

      def predicate_glossary_count
        sub_glossary("predicate", nil, nil, count: true)
      end

      def object_term_glossary_count
        sub_glossary("object_term", nil, nil, count: true)
      end

      def units_glossary_count
        sub_glossary("units_term", nil, nil, count: true)
      end

      # NOTE: I removed the units from this query after ea27411f8110b74 (q.v.)
      def page_glossary(page_id)
        q = "MATCH (page:Page { page_id: #{page_id} })-[:trait]->(trait:Trait) "\
          "MATCH (trait:Trait)-[:predicate]->(predicate:Term) "\
          "OPTIONAL MATCH (trait)-[:object_term]->(object_term:Term) "\
          "RETURN predicate, object_term"
        res = query(q)
        uris = {}
        res["data"].each do |row|
          row.each do |col|
            uris[col["data"]["uri"]] ||= col["data"].symbolize_keys if
              col && col["data"] && col["data"]["uri"]
          end
        end
        uris
      end

      def obj_terms_for_pred(pred_uri, qterm = nil)
        key = "trait_bank/obj_terms_for_pred/#{pred_uri}"
        Rails.cache.fetch(key, expires_in: CACHE_EXPIRATION_TIME) do
          q = "MATCH (predicate:Term { uri: \"#{pred_uri}\" })<-[:predicate|:parent_term*0..#{CHILD_TERM_DEPTH}]-"\
            "(trait:Trait)"\
            "-[:object_term|parent_term*0..#{CHILD_TERM_DEPTH}]->(object:Term) "
          q << "WHERE LOWER(object.name) CONTAINS \"#{qterm.gsub(/"/, '').downcase}\" " if qterm
          q <<  "RETURN DISTINCT(object) "\
            "ORDER BY LOWER(object.name), LOWER(object.uri)"

          res = query(q)
          res["data"] ? res["data"].map { |t| t.first["data"].symbolize_keys } : []
        end
      end

      # TODO: DRY up this and the above method
      def units_for_pred(pred_uri)
        key = "trait_bank/normal_unit_for_pred/#{pred_uri}"

        Rails.cache.fetch(key, expires_in: CACHE_EXPIRATION_TIME) do
          res = query(
            "MATCH (predicate:Term { uri: \"#{pred_uri}\" })<-[:predicate|:parent_term*0..#{CHILD_TERM_DEPTH}]-"\
            "(trait:Trait)"\
            "-[:units_term]->(units_term:Term) "\
            "OPTIONAL MATCH (trait)-[:normal_units_term]->(normal_units_term:Term) "\
            "RETURN units_term.name, units_term.uri, normal_units_term.name, normal_units_term.uri "\
            "LIMIT 1"
          )

          result = res["data"]&.first || nil

          result = {
            units_name: result[0],
            units_uri: result[1],
            normal_units_name: result[2],
            normal_units_uri: result[3]
          } if result

          result
        end
      end
    end
  end
end
