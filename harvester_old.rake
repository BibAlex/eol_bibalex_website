require 'uri'
$sql_commands= File.new('commands.sql', 'w')

def main_method_2
  batches_log = File.new('batches_log', 'a')
  nodes_log = File.new('nodes_log', 'a')
  is_updates = check_for_upadtes
  nodes_ids = []
  if is_updates == "true"
    finish = false
    start_key = -1
    last_harvested_time = DateTime.now.strftime('%Q')

    # json_content = get_latest_updates_from_hbase(last_harvested_time, start_key) 
    # json_content = get_nodes_of_resource_from_hbase(471)
    # 
    batches_log.write("batch done: #{start_key}\n")
    # if json_content.empty?
      # finish = true          
    # end
    while !finish do              
      # unless json_content == false
      json_content=File.read("node(1).json")
        nodes = JSON.parse(json_content)
        # debugger
        # batches_log.write("batch done: #{start_key}: #{nodes.count}\n")
        current_node = nil
        nodes.each do |node|          
          # load_occurrence(node)
          # debugger
          # nodes_ids << node["generatedNodeId"]
          current_node = node
          nodes_ids << node["generatedNodeId"]
          res = Node.where(generated_node_id: node["generatedNodeId"])        
          if res.count > 0
            nodes_log.write("#{node["generatedNodeId"]}: found\n")
            created_node = res.first
          else
            params = { resource_id: node["resourceId"],
                     scientific_name: node["taxon"]["scientificName"], canonical_form: node["taxon"]["canonicalName"],
                     rank: node["taxon"]["taxonRank"], generated_node_id: node["generatedNodeId"],taxon_id: node["taxonId"],
                     page_id: node["taxon"]["pageEolId"] }
            created_node = create_node(params)
            if created_node.valid?
              nodes_log.write("#{node["generatedNodeId"]}: success\n")
            else
              nodes_log.write("#{node["generatedNodeId"]}: fail\n")
            end
          end
          
          #node["taxon"]["pageEolId"] return null so set it static until solved
          # node["taxon"]["pageEolId"]= "1"
          
          unless node["taxon"]["pageEolId"].nil? 
            page_id = create_page({ resource_id: node["resourceId"], node_id: created_node.id, id: node["taxon"]["pageEolId"] }) # iucn status, medium_id
            create_scientific_name({ node_id: created_node.id, page_id: page_id, canonical_form: node["taxon"]["canonicalName"],
                                   node_resource_pk: node["taxon_id"], scientific_name: node["taxon"]["scientificName"],resource_id: node["resourceId"] })
            create_pages_nodes({resource_id: node["resourceId"], node_id: created_node.id, page_id: page_id})      
            unless node["vernaculars"].nil?
              create_vernaculars({vernaculars: node["vernaculars"], node_id: created_node.id, page_id: page_id, resource_id: node["resourceId"] })
            end
            
            unless node["media"].nil?
              create_media({media: node["media"],resource_id: node["resourceId"],page_id: page_id, references: node["references"]})
            end
            node_params = { page_id: node["taxon"]["pageEolId"], resource_id: node["resourceId"],
                scientific_name: node["taxon"]["scientificName"] }
            add_neo4j(node_params, node["occurrences"], node["measurementOrFacts"], node["associations"]) 
          end
          
          
        end
        # 
        # start_key = "#{current_node["resourceId"]}_#{current_node["generatedNodeId"]}"
        # json_content = get_latest_updates_from_hbase(last_harvested_time,start_key)
        # batches_log.write("batch done: #{start_key}\n")
        # nodes = JSON.parse(json_content)
        # if nodes.count <= 1
          finish = true     
        end
      end
    end
    # build_hierarchy(nodes_ids)    
  # end
# end


def get_dynamic_heirarchy_nodes
  node_ids = []
  json_content = get_nodes_of_resource_from_hbase(519)
  nodes = JSON.parse(json_content)
  nodes.map do |node|
     node_ids << node["generatedNodeId"]
  end
  build_hierarchy(node_ids) 
end

def build_ancestors_for_sql_solution
  node_ids = []
  #node_ids = Node.all.pluck(:generated_node_id)
  node_ids =  Node.where(resource_id: 543).pluck(:generated_node_id)
  build_hierarchy(node_ids) 
end

# def load_occurrence(node)
  # unless node["occurrences"].nil?
     # node["occurrences"].each do |occurrence|
#        
       # if occurrence["deltaStatus"] == "I"
         # OccurrencePageMapping.create(resource_id: node["resourceId"], occurrence_id: occurrence["occurrenceId"], page_id: node["taxon"]["pageEolId"])
#          
       # else               
         # res = OccurrencePageMapping.where(resource_id: node["resourceId"], occurrence_id: occurrence["occurrenceId"])
         # unless res.nil?
           # old_occurrence_mapping = res.first
           # unless old_occurrence_mapping.nil?
             # if occurrence["deltaStatus"] == "U"
               # old_occurrence_mapping.update_attributes(page_id: node["taxon"]["pageEolId"])
             # else
               # old_occurrence_mapping.destroy
             # end
           # end
         # end               
       # end
     # end
   # end
# end

def load_occurrence(occurrences, page_id, resource_id)
  unless occurrences.nil?
     occurrences.each do |occurrence|
       
       if occurrence["deltaStatus"] == "I"
         OccurrencePageMapping.create(resource_id: resource_id, occurrence_id: occurrence["occurrenceId"], page_id: page_id)
         
       else               
         res = OccurrencePageMapping.where(resource_id: resource_id, occurrence_id: occurrence["occurrenceId"])
         unless res.nil?
           old_occurrence_mapping = res.first
           unless old_occurrence_mapping.nil?
             if occurrence["deltaStatus"] == "U"
               old_occurrence_mapping.update_attributes(page_id: page_id)
             else
               old_occurrence_mapping.destroy
             end
           end
         end               
       end
     end
   end
end

def main_method
  #442
  # nodes_ids = [1976]
  
  # is_updates = check_for_upadtes
  nodes_ids = []
  # if is_updates == "true"
    # start_key = -1
    # json_content = get_latest_updates_from_hbase(start_key)

      # json_content = get_nodes_of_resource_from_hbase(471)

     # json_content = get_nodes_of_resource_from_hbase()
     nodes_file_path = File.join(Rails.root, 'lib', 'tasks', 'publishing_api', 'node_sample.json')
     json_content = File.read(nodes_file_path)
     # unless json_content == false
       nodes = JSON.parse(json_content)

       
       # load_occurrences
       nodes.each do |node|
         load_occurrence(node)
       end

       
       
      nodes.each do |node|

        # if node["resourceId"] == 452
        
         # node=nodes[0]
         # node["taxon"]["pageEolId"]="1"
         # measurements = node["measurementOrFacts"]
         # measurements[0]["parentMeasurementId"]="912"
         
         # node["taxon"]["pageEolId"]= "1"
         
         nodes_ids << node["generatedNodeId"]
         res = Node.where(generated_node_id: node["generatedNodeId"])        
         if res.count > 0
           created_node = res.first
         else
           params = { resource_id: node["resourceId"],
                     scientific_name: node["taxon"]["scientificName"], canonical_form: node["taxon"]["canonicalName"],
                     rank: node["taxon"]["taxonRank"], generated_node_id: node["generatedNodeId"],taxon_id: node["taxonId"],
                     page_id: node["taxon"]["pageEolId"] }
          created_node = create_node(params)
        end          
#           
         unless node["taxon"]["pageEolId"].nil?
       
          page_id = create_page({ resource_id: node["resourceId"], node_id: created_node.id, id: node["taxon"]["pageEolId"] }) # iucn status, medium_id
          create_scientific_name({ node_id: created_node.id, page_id: page_id, canonical_form: node["taxon"]["canonicalName"],
                                 node_resource_pk: node["taxon_id"], scientific_name: node["taxon"]["scientificName"],resource_id: node["resourceId"] }) 
          create_pages_nodes({resource_id: node["resourceId"], node_id: created_node.id, page_id: page_id})     
          # unless node["vernaculars"].nil?
            # create_vernaculars({vernaculars: node["vernaculars"], node_id: created_node.id, page_id: page_id, resource_id: node["resourceId"] })
          # end
#           
          # unless node["media"].nil?
            # create_media({media: node["media"],resource_id: node["resourceId"],page_id: page_id, references: node["references"]})
          # end
#           
          node_params = { page_id: node["taxon"]["pageEolId"], resource_id: node["resourceId"],
                          scientific_name: node["taxon"]["scientificName"] }
          add_neo4j(node_params, node["occurrences"], node["measurementOrFacts"], node["associations"])           
          end      
         # end
      # end # end of nodes loop

       # build_hierarchy(nodes_ids)
       

    end
   # end    
 end

  


def check_for_upadtes
  scheduler_uri = "#{SCHEDULER_ADDRESS}/#{CHECK_FOR_UPDATES}"
  last_harvested_time = "1536650663000"
   begin    
    request =RestClient::Request.new(
        :method => :get,
        :timeout => -1,
        :url => "#{scheduler_uri}/#{last_harvested_time}"
      )
      response = request.execute
      response.body
  rescue => e
    false
  end  
end

def get_latest_updates_from_hbase(last_harvested_time, start_key)
  hbase_uri = "#{HBASE_ADDRESS}#{HBASE_GET_LATEST_UPDATES_ACTION}"
  start_harvested_time = "1510150973451"
  # last_harvested_time = "#{DateTime.now.strftime('%Q')}"
  begin    
    request =RestClient::Request.new(
        :method => :get,
        :timeout => -1,
        :url => "#{hbase_uri}/#{start_harvested_time}/#{last_harvested_time}/#{start_key}"
      )
      response = request.execute
      response.body
  rescue => e
  debugger
    c="l"
    false
  end
end

def get_latest_updates_from_mysql(start_harvested_time , end_harvested_time)
  # debugger
  mysql_uri = "#{MYSQL_ADDRESS}#{MYSQL_GET_LATEST_UPDATES_ACTION}"
  begin    
    request =RestClient::Request.new(
        :method => :get,
        :timeout => -1,
         :url => "#{mysql_uri}/#{start_harvested_time}/#{end_harvested_time}"
      )
      response = request.execute
      response.body
  rescue => e
  debugger
    c="l"
    false
  end 
end

def get_end_time
  mysql_uri = "#{MYSQL_ADDRESS}#{MYSQL_GET_END_TIME}"
  begin    
    request =RestClient::Request.new(
        :method => :get,
        :timeout => -1,
         :url => "#{mysql_uri}"
      )
      response = request.execute
      response.body
  rescue => e
  debugger
    c="l"
    false
  end 
end

def get_nodes_of_resource_from_hbase(resource_id)
  hbase_uri = "#{HBASE_ADDRESS}#{HBASE_GET_NODES_OF_RESOURCE_ACTION}"
  begin    
    request =RestClient::Request.new(
        :method => :get,
        :timeout => -1,
        :url => "#{hbase_uri}/#{resource_id}"
      )
      response = request.execute
      response.body
  rescue => e
    false
  end
end

def build_hierarchy(nodes_ids)
  # set_parents(nodes_ids)
  set_ancestors(nodes_ids)
end

# def set_parents(nodes_ids)
#   
  # nodes_ids_parents = nil
  # # get nodes_parents from neo4j  
  # neo4j_uri = "#{NEO4J_ADDRESS}/#{NEO4J_GET_PARENTS_OF_NODES_ACTION}"
  # nodes_ids.each_slice(1000) do |sub_arr|
    # begin 
      # debugger   
      # request =RestClient::Request.new(
          # :method => :get,
          # :timeout => -1,
          # :url => "#{neo4j_uri}",
          # headers: { content_type: 'application/json', accept: 'application/json'},
          # :payload =>  sub_arr.to_json
        # )
        # response = request.execute
        # nodes_ids_parents = JSON.parse(response.body)
    # rescue => e
      # false
    # end 
    # unless nodes_ids_parents.nil?
      # nodes_ids_parents.each do |key,value|
        # child_res = Node.where(generated_node_id: key.to_i)
        # parent_res = Node.where(generated_node_id: value)
        # if child_res.count > 0 && parent_res.count > 0
          # child_node = child_res.first
          # parent_node = parent_res.first
          # child_node.update_attributes(parent_id: parent_node.id)
        # end
      # end
    # end
  # end
# end


def set_ancestors(nodes_ids)
  # get nodes_parents from neo4j  
  neo4j_uri = "#{NEO4J_ADDRESS}/#{NEO4J_GET_ANCESTORS_OF_NODES_ACTION}"
  
  nodes_ids.each_slice(1000) do |sub_arr|
    begin    
      request =RestClient::Request.new(
          :method => :post,
          :timeout => -1,
          :url => "#{neo4j_uri}",
          headers: { content_type: 'application/json', accept: 'application/json'},
          :payload =>  sub_arr.to_json
        )
        
        response = request.execute
        nodes_ids_ancestors = JSON.parse(response.body)
    rescue => e
      false
    end
    
    unless nodes_ids_ancestors.nil?
      nodes_ids_ancestors.each do |group|
        current_node = nil
        ancestor_node = nil
        group.each do |key,value|
          res = Node.where(generated_node_id: value.to_i)
          if key.to_i == 0  
            if  res.count > 0 
              current_node = res.first 
            end
          else
            if res.count > 0 
              ancestor_node = res.first
              NodeAncestor.find_or_create_by(node: current_node, ancestor: ancestor_node, depth: key.to_i, resource_id: current_node.resource_id)
            else
              NodeAncestor.find_or_create_by(node_generated_node_id: current_node.generated_node_id, ancestor_generated_node_id: value.to_i, depth: key.to_i, resource_id: current_node.resource_id)
            end
          end 
        end      
      end
    end
  end
  
end


def create_vernaculars(params)
  params[:vernaculars].each do |vernacular|
    language_id= vernacular["language"].nil? ? create_language("eng") : create_language(vernacular["language"])
    create_vernacular({ string: vernacular["name"], node_id: params[:node_id], page_id: params[:page_id],
                        is_preferred_by_resource: vernacular["isPreferred"], language_id: language_id, resource_id: params[:resource_id]})
  end
end

def create_media(params)
    params[:media].each do |medium|
      language_id = medium["language"].nil? ? create_language("eng") : create_language(medium["language"])
      license_id = medium["license"].nil? ? create_license("test") : create_license(medium["license"])
      location_id = medium["locationCreated"].nil? ? nil : create_location(location: medium["locationCreated"],
                    spatial_location: medium["genericLocation"],latitude: medium["latitude"],longitude: medium["longitude"],
                    altitude: medium["altitude"], resource_id: params[:resource_id])
                    
      #base_url need to have default value
      medium_id = create_medium({ format: medium["format"],description: medium["description"],owner: medium["owner"],
                     resource_id: params[:resource_id],guid: medium["guid"],resource_pk: medium["mediaId"],source_page_url: medium["furtherInformationURI"],
                     language_id: language_id, license_id: license_id,location_id: location_id, base_url: "http://#{STORAGE_LAYER_IP}#{medium["storageLayerPath"]}",
                     bibliographic_citation_id: nil})
      #need to check  value , position
      fill_page_contents({resource_id: params[:resource_id],page_id: params[:page_id],source_page_id: params[:page_id],content_type: "Medium", content_id: medium_id})
#       
      unless medium["agents"].nil?
        create_agents({resource_id: params[:resource_id], agents: medium["agents"], content_id: medium_id, content_type: "Medium",content_resource_fk: medium["mediaId"]})
      end
#       
      #to show literature and references tab need to fill pages_referents table which won't be filled by us 
      unless params[:references].nil?
        create_referents({references: params[:references],resource_id: params[:resource_id], reference_id: medium["referenceId"],parent_id: medium_id,parent_type: "Medium",page_id: params[:page_id]})
      end
      
    end
  
end

def create_agents(params)
  params[:agents].each do |agent|
    create_agent(resource_id: params[:resource_id],role: agent["role"],content_id: params[:content_id], 
                 content_type: params[:content_type], resource_pk: agent["agentId"],value: agent["fullName"],url: agent["homepage"],content_resource_fk:params[:content_resource_fk])
  end
  
end

def create_agent(params)
  # need role default name
  # role_id = params[:role].nil? ? create_role("roletest") : create_role(params[:role]) 
  role_name = params[:role].nil? ? "roletest" : params[:role]
  create_attribution({resource_id: params[:resource_id],content_id: params[:content_id] ,content_type: params[:content_type],
                      role_name: role_name,url: params[:url], resource_pk: params[:resource_pk], value: params[:value], content_resource_fk: params[:content_resource_fk]})
end

def create_referents(params)
  unless params[:reference_id].nil?
    reference_ids=params[:reference_id].split(';')
    reference_ids.each do|reference_id|
      params[:references].each do |reference|
        if reference["referenceId"] == reference_id
          body = "#{reference["primaryTitle"]} #{reference["secondaryTitle"]} #{reference["pages"]} #{reference["pageStart"]} "+
                "#{reference["pageEnd"]} #{reference["volume"]} #{reference["editor"]} #{reference["publisher"]} "+
                "#{reference["authorsList"]} #{reference["editorsList"]} #{reference["dataCreated"]} #{reference["doi"]}"
          referent_id = create_referent(body: body ,resource_id: params[:resource_id])
          create_references({referent_id: referent_id,parent_id: params[:parent_id],parent_type: params[:parent_type], resource_id: params[:resource_id]})
        end
      end
    end
  end
end

def create_referent(params)
    res = Referent.where(body: params[:body],resource_id: params[:resource_id])
    if res.count > 0
      res.first.id
    else
      referent = Referent.create(body: params[:body],resource_id: params[:resource_id])
      referent.id
    end
    
end 

def create_references(params)
  #check searching parameters
  res = Reference.where(parent_id: params[:parent_id],parent_type: params[:parent_type],referent_id: params[:referent_id])
  if res.count > 0
    res.first.id
  else
    # id attribute must be autoincrement need to be edited in schema
    reference = Reference.create(parent_id: params[:parent_id],referent_id: params[:referent_id] ,parent_type: params[:parent_type],resource_id: params[:resource_id], id: 1)
    reference.id
  end
   
end

  

def create_node(params)
  # fill parent id with generated node id as place holder and this value will be changed after calling build hierarchy
  rank_id = params[:rank].nil? ? nil : create_rank(params[:rank])
  resource_pk = params[:taxon_id].nil? ? "missed_taxon_id" : params[:taxon_id] 
  node = Node.create(
    resource_id: params[:resource_id],
    rank_id: rank_id,
    scientific_name: params[:scientific_name],
    canonical_form: params[:canonical_form],
    resource_pk: resource_pk,
    generated_node_id: params[:generated_node_id])
    node                          
end

def create_role(name)
  res=Role.where(name: name)
  if res.count > 0
    res.first.id
  else
    role = Role.create(name: name)
    role.id 
  end
end

def create_rank(name)
  res = Rank.where(name: name)
  if res.count > 0
    res.first.id
  else
    rank = Rank.create(name: name)
    # Rank.fill_in_missing_treat_as
    rank.id
  end  
end

def create_language(code)
  res = Language.where(code: code)
  if res.count > 0
    res.first.id
  else
    language = Language.create(code: code, group: code)
    language.id
  end
end

def create_license(source_url)
  res = License.where(source_url: source_url)
  if res.count > 0
    res.first.id
  else
    #in the name attribute , put the word "license" . to be able to edit it
    license = License.create(source_url: source_url, name: "license") 
    license.id
  end
end

def create_location(params)
  #need to add resource_id in seach??????
  res = Location.where(location: params[:location] ,longitude: params[:longitude],latitude: params[:latitude],
                       altitude: params[:altitude],spatial_location: params[:spatial_location])
  if res.count > 0
    res.first.id
  else
    location_id = Location.create(location: params[:location] ,longitude: params[:longitude],latitude: params[:latitude],
                                  altitude: params[:altitude],spatial_location: params[:spatial_location],resource_id: params[:resource_id])
    location_id
  end
end

def create_page(params)
  unless params[:id].nil?
    res = Page.where(id: params[:id])
    if res.count > 0
      res.first.id
    else
      # if params[:resource_id] == DYNAMIC_HIERARCHY_RESOURCE_ID
        page = Page.create(id: params[:id].to_i, node_id: params[:node_id].to_i)
        page.id
      # end
    end
    else
      nil    
  end
end

def create_pages_nodes(params)
  is_native = params[:resource_id] == DYNAMIC_HIERARCHY_RESOURCE_ID ? true : false
  PagesNode.find_or_create_by(page_id: params[:page_id], node_id: params[:node_id], is_native: is_native)
end  

def create_attribution(params)
  # search in attributions not final parameters
  res= Attribution.where(content_id: params[:content_id],content_type: params [:content_type],value: params[:value])
  if res.first
    res.first.id
  else
    attribution=Attribution.create(content_id: params[:content_id],content_type: params[:content_type],role_name: params[:role_name],
                                   value: params[:value], url: params[:url], resource_id: params[:resource_id], resource_pk: params[:resource_pk], 
                                   content_resource_fk: params[:content_resource_fk])
    attribution.id
  end
end

def create_vernacular(params)
  res = Vernacular.where(string: params[:string], node_id: params[:node_id])
  if res.count > 0
    res.first.id
  else
    vernacular_attributes = { string: params[:string] , language_id: params[:language_id] , node_id: params[:node_id], 
                              page_id: params[:page_id], resource_id: params[:resource_id] }
    unless params[:is_preferred_by_resource].nil?
      vernacular_attributes[:is_preferred_by_resource] = params[:is_preferred_by_resource]
    end
    
    vernacular = Vernacular.create(vernacular_attributes)
    vernacular.id
  end
  
end

def create_medium(params)
  res = Medium.where(guid: params[:guid])
  if res.count > 0
    res.first.id
  else
    medium= Medium.create(params)
    medium.id
  end
end



def create_scientific_name(params)
  # node_resource_pk = taxon_id
  # for now, we set italicized by canonical form but we should use global names tool
  # to separate scientific name and authority an surrond canonical form part with <i> </i> tags
  
  res = ScientificName.where(node_id: params[:node_id], canonical_form: params[:canonical_form])
  if res.count > 0
    res.first.id
  else
    canonical_form = params[:canonical_form].nil? ? params[:scientific_name] : params[:canonical_form]
    scientific_name = ScientificName.create(node_id: params[:node_id], page_id: params[:page_id], resource_id: params[:resource_id],canonical_form: canonical_form,
                                            node_resource_pk: params[:node_resource_pk], italicized: canonical_form , taxonomic_status_id: 1)
    scientific_name.id
  end  
end

def fill_page_contents(params)
  #need to add resource_id in seach??????
    res = PageContent.where(content_type:params[:content_type],content_id: params[:content_id]  ,page_id: params[:page_id] )
    if res.count > 0
      res.first.id
    else
      page_contents = PageContent.create(resource_id: params[:resource_id], content_type:params[:content_type],content_id: params[:content_id],page_id: params[:page_id],source_page_id: params[:source_page_id])
      page_contents.id
    end
      
end


def create_measurement(occurrence_of_measurement , measurement)
  # debugger
    options = { 
                predicate: { name:"predicate_name_#{measurement["measurementId"]}", uri: measurement["measurementType"],
                              section_ids:[1,2,3],definition:"predicate definition"}
                 }
    if numeric?(measurement["measurementValue"])
      options[:measurement] = measurement["measurementValue"]
    elsif uri?(measurement["measurementValue"])
      options[:object_term] = { name: "temp object term_#{measurement["measurementId"]}",
                               uri: measurement["measurementValue"], section_ids:[1,2,3],definition:"object_term definition"}
    else
      #TODO update this part after discussing it with stakeholders
      options[:literal] = measurement["measurementValue"]            
    end
    if measurement["unit"]
      options[:units] = {name: "unit_#{measurement["measurementId"]}",uri: measurement["unit"],
                         section_ids:[1,2,3],definition:"test units"}            
    end
    unless measurement["citation"].nil?
      options[:citation] = measurement["citation"]
    end
    unless measurement["source"].nil?
      options[:source] = measurement["source"]
    end
    unless measurement["measurementMethod"].nil?
      options[:measurementMethod] = measurement["measurementMethod"]
    end
    
    # if occurrence_of_measurement && occurrence_of_measurement["lifeStage"]
      # options[:lifestage_term] = { name: "lifeStage_#{measurement["measurementId"]}",
                             # uri: occurrence_of_measurement["lifeStage"], section_ids:[1,2,3],definition:"lifeStage term object_term definition"}
    # end
#     
    # if occurrence_of_measurement && occurrence_of_measurement["sex"]
      # options[:sex_term] = { name: "sex_#{measurement["measurementId"]}",
                             # uri: occurrence_of_measurement["sex"], section_ids:[1,2,3],definition:"sex term object_term definition"}
    # end
#     
    # if occurrence_of_measurement && occurrence_of_measurement["statisticalMethod"]
      # options[:statistical_method_term] = { name: "statisticalMethod_#{measurement["measurementId"]}",
                             # uri: occurrence_of_measurement["statisticalMethod"], section_ids:[1,2,3],definition:"statisticalMethod term object_term definition"}
    # end
    options
end


def add_neo4j(node_params, occurrences, measurements, associations)

  unless (occurrences.nil? || occurrences.empty?)
    # load occurrences
    occurrences_hash = {}    
    occurrences.each do |occurrence|
      occurrences_hash[occurrence["occurrenceId"]] = occurrence
    end
    

    page = TraitBank.create_page(node_params[:page_id].to_i)
    resource = TraitBank.create_resource(node_params[:resource_id].to_i)
    unless (associations.nil? || associations.empty?)
      # debugger
      associations.each do |association|
        res = OccurrencePageMapping.where(resource_id: node_params[:resource_id], occurrence_id: association["targetOccurrenceId"])
        unless res.empty?
          occurrence_mapping = res.first
          object_page_id = occurrence_mapping.page_id
        end
        options = { supplier: { "data" => { "resource_id" =>node_params[:resource_id] } },
                      resource_pk: association["associationId"].to_i, page: node_params[:page_id] ,
                      occurrence_id:association["occurrenceId"],
                      eol_pk: "A_#{association["occurrenceId"]}_#{association["associationId"]}",
                      # eol_pk: "\"#{measurement["occurrenceId"]}\"", 
                      scientific_name: node_params[:scientific_name], object_page_id: object_page_id,
                      predicate: { name: "predicate_name_#{association["associationId"]}", uri: association["associationType"], section_ids:[1,2,3],definition:"predicate definition"}
                       }
                       
          occurrence_of_association = occurrences_hash[association["occurrenceId"]]
          if occurrence_of_association && occurrence_of_association["sex"]
            options[:sex_term] = { name: "sex_#{association["associationId"]}",
                                   uri: occurrence_of_association["sex"], section_ids:[1,2,3],definition:"sex term object_term definition"}
          end
          
          if occurrence_of_association && occurrence_of_association["lifeStage"]
            options[:lifestage_term] = { name: "lifeStage_#{association["associationId"]}",
                                   uri: occurrence_of_association["lifeStage"], section_ids:[1,2,3],definition:"lifeStage term object_term definition"}
          end
          
          # if occurrence_of_association && occurrence_of_association["statisticalMethod"]
            # options[:statistical_method_term] = { name: "statisticalMethod_#{association["associationId"]}",
                                   # uri: occurrence_of_association["statisticalMethod"], section_ids:[1,2,3],definition:"statisticalMethod term object_term definition"}
          # end
          unless association["citation"].nil?
            options[:citation] = association["citation"]
          end
          unless association["source"].nil?
            options[:source] = association["source"]
          end
          unless association["measurementMethod"].nil?
            options[:measurementMethod] = association["measurementMethod"]
          end
          trait=TraitBank.create_trait(options)
      end
    end
    
    unless (measurements.nil? || measurements.empty?)
      measurements_array = []
      measurements.each do |measurement|
        occurrence_of_measurement = occurrences_hash[measurement["occurrenceId"]]
        
        
        # if measurement["measurementOfTaxon"] == "true" || measurement["measurementOfTaxon"] == "TRUE" || measurement["measurementOfTaxon"].nil?
        if (!measurement["measurementOfTaxon"].nil?) && (VALID_ARRAY.include?((measurement["measurementOfTaxon"]).downcase))    
          options = create_measurement(occurrence_of_measurement , measurement)
          options[:supplier] = { "data" => { "resource_id" =>node_params[:resource_id] } }
          options[:resource_pk] =  measurement["measurementId"]
          options[:page] = node_params[:page_id]
          options[:eol_pk] = "M_#{measurement["occurrenceId"]}_#{measurement["measurementId"]}"
          # options[:eol_pk] = "\"#{measurement["occurrenceId"]}\""
          options[:scientific_name] =  node_params[:scientific_name]
          options[:occurrence_id]= measurement["occurrenceId"]
          
          if occurrence_of_measurement && occurrence_of_measurement["lifeStage"]
            options[:lifestage_term] = { name: "lifeStage_#{measurement["measurementId"]}",
                             uri: occurrence_of_measurement["lifeStage"], section_ids:[1,2,3],definition:"lifeStage term object_term definition"}
          end
    
          if occurrence_of_measurement && occurrence_of_measurement["sex"]
            options[:sex_term] = { name: "sex_#{measurement["measurementId"]}",
                                   uri: occurrence_of_measurement["sex"], section_ids:[1,2,3],definition:"sex term object_term definition"}
          end
  
          if measurement["statisticalMethod"]
            options[:statistical_method_term] = { name: "statisticalMethod_#{measurement["measurementId"]}",
                                   uri: measurement["statisticalMethod"], section_ids:[1,2,3],definition:"statisticalMethod term object_term definition"}
          end
          trait=TraitBank.create_trait(options)

        # elsif (measurement["measurementOfTaxon"] == "false" || measurement["measurementOfTaxon"] == "FALSE") && !(measurement["parentMeasurementId"].nil?)
        elsif (measurement["measurementOfTaxon"].nil? ||NON_VALID_ARRAY.include?((measurement["measurementOfTaxon"]).downcase)) && !(measurement["parentMeasurementId"].nil?)
            # debugger
          measurements_array << measurement
        else
           # debugger
          measurements_array << measurement
 
        end
      end
      
      measurements_array.each do |measurement|
        occurrence_of_measurement = occurrences_hash[measurement["occurrenceId"]]
        options = create_measurement(occurrence_of_measurement , measurement)
        # if (measurement["measurementOfTaxon"] == "false" || measurement["measurementOfTaxon"] == "FALSE") && !(measurement["parentMeasurementId"].nil?)
        if (measurement["measurementOfTaxon"].nil? || NON_VALID_ARRAY.include?((measurement["measurementOfTaxon"]).downcase)) && !(measurement["parentMeasurementId"].nil?)
            #Update this condidtion to insert metadata of a given measurement : measurementOfTaxon = true and measurementparent is not null
          parent_eol_pk = "M_#{measurement["occurrenceId"]}_#{measurement["parentMeasurementId"]}"
          res = TraitBank.find_trait(parent_eol_pk, node_params[:resource_id]) 

          # options.each { |md| TraitBank.add_metadata_to_trait(res, md) }
          # options[:eol_pk]= measurement["measurementId"]
          options[:eol_pk] = "M_#{measurement["occurrenceId"]}_#{measurement["measurementId"]}"
          TraitBank.add_metadata_to_trait(res, options)
          
        else
          # debugger
          traits = TraitBank.find_traits(measurement["occurrenceId"], node_params[:resource_id]) 
          traits.each do |element|
            # debugger
            # options[:eol_pk]= measurement["measurementId"]
            options[:eol_pk] = "M_#{measurement["occurrenceId"]}_#{measurement["measurementId"]}"
            options_copy = options.clone
            TraitBank.add_metadata_to_trait(element, options_copy)
            # options.each { |md| TraitBank.add_metadata_to_trait(element, md) }
          end   
        end
      end
      
    end
    
    
  
    
  end
  
  
  
  
  
  # tb_page = TraitBank.create_page(1)
  # # tbb_page = TraitBank.create_page(2)
  # resource = TraitBank.create_resource(147)
#   
  # # options = {supplier:{"data"=>{"resource_id"=>147}},
             # # resource_pk:123 , page:1, eol_pk:" 124", scientific_name: "scientific_name", object_page_id: 2,
             # # predicate:{"name"=>"event date","uri"=>"test/event",section_ids:[1,2,3],definition:"test predicate definition"}}
#   
# #   
  # options = {supplier:{"data"=>{"resource_id"=>147}},
             # resource_pk:123 , page:1, eol_pk:" 124", scientific_name: "scientific_name",
             # predicate:{"name"=>"event date","uri"=>"test/event",section_ids:[1,2,3],definition:"test predicate definition"},
             # object_term:{"name"=>"5/2/15","uri"=>"test/date",section_ids:[1,2,3],definition:"test object_term definition"},
             # units: {"name"=>"cm","uri"=>"http://purl.obolibrary.org/obo/UO_0000008",section_ids:[1,2,3],definition:"test units"},
             # literal:"10",
             # metadata:[{predicate:{"name"=>"md_event","uri"=>"test/md_event",section_ids:[1,2,3],definition:"test predicate definition"},
                        # object_term:{"name"=>"md_length1","uri"=>"test/md_length1",section_ids:[1,2,3],definition:"test object_term definition"},
                        # units: {"name"=>"cm","uri"=>"http://eol.org/schema/terms/squarekilometer",section_ids:[1,2,3],definition:"test units"},
                        # literal:"15"}] } 
# 
#   
  # trait=TraitBank.create_trait(options)
end

def numeric?(str)
  Float(str) != nil rescue false
end

def uri?(str)
  if str =~ URI::regexp
    true
  else
    false
  end
end


# def main_method_3
#   $sql_commands.write("use ba_eol_development;\n")
#   nodes_ids = []
  
#   file_path = File.join(Rails.root, 'lib', 'tasks', 'publishing_api', 'mysql.json')
#   tables = JSON.parse(File.read(file_path))
  

#   # start_harvested_time = "1536850285303"
#   # json_content = get_latest_updates_from_mysql(start_harvested_time)
#   # debugger
#   # tables = JSON.parse(json_content)
  
#   licenses = tables["licenses"]
#   ranks = tables["ranks"]
#   nodes = tables["nodes"]
#   pages = tables["pages"]
#   pages_nodes = tables["pages_nodes"]
#   scientific_names = tables["scientific_names"]
#   languages = tables["languages"]
#   vernaculars = tables["vernaculars"]
#   locations = tables["locations"]
#   media = tables["media"]
#   page_contents = tables["page_contents"]
#   attributions = tables["attributions"]
#   referents = tables["referents"]
#   references = tables["references"]
  
#   unless licenses.nil?
#     licenses.each do |license|
#       cols = license.keys
#       values = license.values
#       insert_mysql_query("licenses",cols,values)
#         # License.create!(license)
#     end
#   end
  
#   unless ranks.nil? 
#     ranks.each do |rank|
#       cols = rank.keys
#       values = rank.values
#       insert_mysql_query("ranks",cols,values)      
#        # Rank.create!(rank)
#     end
#   end
  
#   unless nodes.nil? 
#     nodes.each do |node|
#       nodes_ids << node["generated_node_id"]
#       cols = node.keys
#       values = node.values
#       insert_mysql_query("nodes",cols,values)
#        # Node.create!(node)
#     end
#   end
  
#   unless pages.nil? 
#     pages.each do |page|
#       cols = page.keys
#       values = page.values
#       insert_mysql_query("pages",cols,values)
#        # Page.create!(page)
#     end
#   end
  
#   unless pages_nodes.nil? 
#     pages_nodes.each do |pages_node|
#       cols = pages_node.keys
#       values = pages_node.values
#       insert_mysql_query("pages_nodes",cols,values)
#        # PagesNode.create!(pages_node)
#     end
#   end
#   unless scientific_names.nil? 
#     scientific_names.each do |scientific_name|
#       cols = scientific_name.keys
#       values = scientific_name.values
#       insert_mysql_query("scientific_names",cols,values)
#        # ScientificName.create!(scientific_name)
#     end
#   end

#   unless languages.nil? 
#     languages.each do |language|
#       cols = language.keys
#       cols = cols.map { |x| x == "group" ? "languages.group" : x }
#       values = language.values
#       insert_mysql_query("languages",cols,values)
#        # Language.create!(language)
#     end
#   end
  
#   unless vernaculars.nil? 
#     vernaculars.each do |vernacular|
#       cols = vernacular.keys
#       values = vernacular.values
#       insert_mysql_query("vernaculars",cols,values)
#        # Vernacular.create!(vernacular)
#     end
#   end
  
#   unless locations.nil? 
#     locations.each do |location|
#       cols = location.keys
#       values = location.values
#       insert_mysql_query("locations",cols,values)
#        # Location.create!(location)
#     end
#   end
  
#   unless media.nil? 
#     media.each do |medium|
#       cols = medium.keys
#       values = medium.values
#       insert_mysql_query("media",cols,values)
#        # Medium.create!(medium)
#     end
#   end
  
#   unless page_contents.nil? 
#     page_contents.each do |page_content|
#       cols = page_content.keys
#       values = page_content.values
#       insert_mysql_query("page_contents",cols,values)
#        # PageContent.create!(page_content)
#     end
#   end  
  
#   unless attributions.nil? 
#     attributions.each do |attribution|
#       cols = attribution.keys
#       values = attribution.values
#       insert_mysql_query("attributions",cols,values)
#        # Attribution.create!(attribution)
#     end
#   end 
    
#   unless referents.nil? 
#     referents.each do |referent|
#       cols = referent.keys
#       values = referent.values
#       insert_mysql_query("referents",cols,values)
#        # Referent.create!(referent)
#     end
#   end
  
#   unless references.nil? 
#     references.each do |reference|
#       cols = reference.keys
#       values = reference.values
#       insert_mysql_query("ba_eol_development.references",cols,values)
#        # Reference.create!(reference)
#     end
#   end 
#   # ActiveRecord::Base.connection.execute(IO.read($sql_commands))
#   load_data_into_mysql()
#   debugger
#   build_hierarchy(nodes_ids)

   


# end

def main_method_3
  # $sql_commands.write("use ba_eol_development;\n")
  nodes_ids = []
  
  # file_path = File.join(Rails.root, 'lib', 'tasks', 'publishing_api', 'mysql.json')
  # tables = JSON.parse(File.read(file_path))
  
  file_path = File.join(Rails.root, 'lib', 'tasks', 'publishing_api', 'traits_mysql.json')
  tables = JSON.parse(File.read(file_path))

   

   # start_harvested_time = "1540211584000"
   # start_harvested_time = "1544350385000"
  # # end_harvested_time = "1540400200000"
    # end_harvested_time = get_end_time
  # # debugger
#   
  # while (start_harvested_time.to_i <= end_harvested_time.to_i) do 
    # #start_harvested_time is included 
    # #end_harvested_time is excluded therefore we keep it to next loop
    # json_content = get_latest_updates_from_mysql(start_harvested_time,(start_harvested_time.to_i + 30000).to_s)
    # # json_content = get_latest_updates_from_mysql(start_harvested_time, end_harvested_time)
    # tables = JSON.parse(json_content)

    licenses = tables["licenses"]
    ranks = tables["ranks"]
    nodes = tables["nodes"]
    pages = tables["pages"]
    pages_nodes = tables["pages_nodes"]
    scientific_names = tables["scientific_names"]
    languages = tables["languages"]
    vernaculars = tables["vernaculars"]
    locations = tables["locations"]
    media = tables["media"]
    articles = tables["articles"]
    page_contents = tables["page_contents"]
    attributions = tables["attributions"]
    referents = tables["referents"]
    references = tables["references"]
    traits = tables["traits"]

    
    unless licenses.nil?
      License.bulk_insert(licenses, :validate => true, :use_provided_primary_key => true)
    end
    
    unless ranks.nil? 
      Rank.bulk_insert(ranks, :validate => true, :use_provided_primary_key => true)
    end
    
    unless nodes.nil? 
      Node.bulk_insert(nodes,:validate => true ,:use_provided_primary_key => true)
    end
    
    unless pages.nil? 
      Page.bulk_insert(pages,:validate => true , :use_provided_primary_key => true)
    end
    
    unless pages_nodes.nil? 
      PagesNode.bulk_insert(pages_nodes,:validate => true , :use_provided_primary_key => true)
    end
    unless scientific_names.nil? 
      ScientificName.bulk_insert(scientific_names,:validate => true , :use_provided_primary_key => true)
    end
  
    unless languages.nil? 
      languages.each do |language|
        Language.create(language)
      end
      # languages.each do |language|
        # language["languages.group"] = language.delete("group")
      # end
      # Language.bulk_insert(languages,:validate => true , :use_provided_primary_key => true)
      # languages.each do |language|
        # cols = language.keys
        # cols = cols.map { |x| x == "group" ? "languages.group" : x }
        # values = language.values
        # insert_mysql_query("languages",cols,values)
         # # Language.create!(language)
      # end
    end
    
    unless vernaculars.nil? 
      Vernacular.bulk_insert(vernaculars,:validate => true , :use_provided_primary_key => true)
    end
    
    unless locations.nil?
      Location.bulk_insert(locations,:validate => true , :use_provided_primary_key => true) 
    end
    
    unless media.nil? 
      Medium.bulk_insert(media,:validate => true , :use_provided_primary_key => true, ignore: true)
    end
    
    unless articles.nil? 
      # debugger
       Article.bulk_insert(articles,:validate => true , :use_provided_primary_key => true, ignore: true)
    end
    
    unless page_contents.nil? 
      PageContent.bulk_insert(page_contents,:validate => true , :use_provided_primary_key => true)
    end  
    
    unless attributions.nil? 
      Attribution.bulk_insert(attributions,:validate => true , :use_provided_primary_key => true)
    end 
      
    unless referents.nil? 
      Referent.bulk_insert(referents,:validate => true , :use_provided_primary_key => true)
    end
    
    unless references.nil? 
      Reference.bulk_insert(references,:validate => true , :use_provided_primary_key => true)
    end 
  
    unless traits.nil?
      traits.each do|trait|
        generated_node_id = trait["generated_node_id"]
        occurrences = "["+trait["occurrences"]+"]"
       if JSON.parse(occurrences).nil?
         debugger
       end
        occurrences = JSON.parse(occurrences)
        node = Node.where(generated_node_id: generated_node_id).first
        node_id = node.id
        resource_id = node.resource_id
        scientific_name = node.scientific_name
        page_id = PagesNode.where(node_id: node_id).first.page_id
        load_occurrence(occurrences, page_id, resource_id)
      end
      traits.each do|trait|   
        generated_node_id = trait["generated_node_id"]
        occurrences = "["+trait["occurrences"]+"]"
        occurrences = JSON.parse(occurrences)
        associations = "["+trait["associations"]+"]"
        associations = JSON.parse(associations)
        measurements = "["+trait["measurementOrFacts"]+"]"
        measurements = JSON.parse(measurements)
        node = Node.where(generated_node_id: generated_node_id).first
        node_id = node.id
        resource_id = node.resource_id
        scientific_name = node.scientific_name
        page_id = PagesNode.where(node_id: node_id).first.page_id
        node_params = { page_id: page_id, resource_id: resource_id, scientific_name: scientific_name}
        add_neo4j(node_params, occurrences, measurements, associations)
      end
    end

  
    # build_hierarchy(nodes_ids)
    
     # start_harvested_time = (start_harvested_time.to_i + 30000).to_s
  # end
   
end


def load_data_into_mysql()
  # db = YAML::load( File.open( File.join(Rails.root, 'config', 'database.yml') ) )
  # password = db["development"]["password"] 
  # file = "commands.sql"
  # username = db["development"]["username"]
  # database = db["development"]['database']
  # exec "mysql -u #{username} -p'#{password}' #{database} < #{file}"
  
  db = YAML.load_file('config/database.yml')
  config = db["development"]
  config[:flags] = Mysql2::Client::MULTI_STATEMENTS
  client = Mysql2::Client.new(config)
  sql = File.read("commands.sql")
  client.query sql
end

def insert_mysql_query(table_name,cols,results)
  cols << "created_at"
  cols << "updated_at"
  values = ""
  # last_element = results.pop
  results.each do |result|

    # res= result.is_a? String ? "\"#{result}\"" : result.to_s
    if(result.nil?)
      res = "null"
    elsif (result.is_a? String)
      res = "\"#{result}\""
    else
      res = result.to_s
    end
    values = values + res + ","
  end

  values = values + "now()," + "now()"

  $sql_commands.write("insert into #{table_name} (#{cols.join(",")}) VALUES (#{values});\n")
  
end


namespace :harvester do
  desc "TODO"  
  task get_latest_updates: :environment do
    
    # o1 = "{\"occurrenceId\":\"Plakobranchus 803\",\"eventId\":null,\"institutionCode\":null,\"collectionCode\":null,\"catalogNumber\":null,\"sex\":null,\"lifeStage\":null,\"reproductiveCondition\":null,\"behavior\":null,\"establishmentMeans\":null,\"remarks\":\"sp, \\\"white\",\"countOfIndividuals\":null,\"preparations\":null,\"fieldNotes\":null,\"samplingProtocol\":null,\"samplingEffort\":null,\"recordedBy\":null,\"identifiedBy\":null,\"dateIdentified\":null,\"eventDate\":null,\"modifiedDate\":null,\"locality\":\"Oceania\",\"decimalLatitude\":\"13\",\"decimalLongitude\":null,\"verbatimLatitude\":null,\"verbatimLongitude\":null,\"verbatimElevation\":null,\"deltaStatus\":\"I\"}"
    # o2 = JSON.parse(o1)
    # remarks = o2["remarks"]
    # debugger
    # remarks.include?"\""
    main_method_3
    # main_method
    # main_method_4
    # main_method_2
    # build_hierarchy(Node.all.limit(50).pluck(:generated_node_id))
     # main_method
    # get_dynamic_heirarchy_nodes

  
     # build_ancestors_for_sql_solution


  end
end
