class CollectedPage < ActiveRecord::Base
  
  # include Elasticsearch::Model
  # include Elasticsearch::Model::Callbacks
#   
  # index_name Rails.application.class.parent_name.underscore+"_collectedpage"
  # document_type self.name.downcase
#   
  # settings index: { number_of_shards: 10} do
  # mapping dynamic: false do
    # indexes :scientitfic_name, type: :varchar 
    # indexes :suggest, {
      # type: 'completion',
      # analyzer: 'lowercase',
      # search_analyzer: 'lowercase',
      # payloads: 'true',
      # }
  # end
# end
  # searchkick word_start: [:scientific_name]
  belongs_to :page, inverse_of: :collected_pages
  belongs_to :collection, inverse_of: :collected_pages
  require 'acts_as_list'
  validates_presence_of :collection
  validates_presence_of :page
  validates_uniqueness_of :page_id, scope: :collection_id

  has_many :collected_pages_media, inverse_of: :collected_page
  has_many :media, through: :collected_pages_media
  has_and_belongs_to_many :articles
  has_and_belongs_to_many :links


  acts_as_list scope: :collection
  counter_culture :collection, column_name: :collected_pages_count, touch: true

  # accepts_nested_attributes_for :collected_pages_media, allow_destroy: true

  # counter_culture :collection

  # NOTE: not indexed if the page is missing!
  # searchable if: :page do
  #   integer :collection_id, stored: true
  #   text(:name) { page.name }
  #   text(:scientific_name) { page.scientific_name.gsub(/<\/?i>/, "") }
  #   text(:preferred_scientific_names) { page.preferred_scientific_names.
  #     map { |n| n.canonical_form.gsub(/<\/?i>/, "") } }
  #   text(:synonyms) {page.scientific_names.synonym.map { |n| n.canonical_form.gsub(/<\/?i>/, "") } }
  #   text(:vernaculars) { page.vernaculars.preferred.map { |v| v.string } }
  # end

  def search_data

    {
     scientific_name_string: scientific_name_string.downcase
    }

  end
  def self.find_pages(q, collection_id)
    CollectedPage.search do
      q = "*#{q}.downcase" unless q[0] == "*"
      fulltext q do
        fields(:name, :scientific_name, :preferred_scientific_names, :synonyms, :vernaculars)
      end
      with(:collection_id, collection_id)
    end
  end

  # For convenience, this is duck-typed from CollectionAssociation (q.v.)
  def item
    page
  end

  # NOTE: we could achieve this with delegation, but: meh. That's not as clear.
  def name
    page.name
  end

  def scientific_name_string
    page.scientific_name
  end

  def medium
    media.first
  end

  def medium_icon_url
    medium.try(:medium_icon_url) or page.icon
  end
  alias_method :icon, :medium_icon_url

  def small_icon_url
    medium.try(:small_icon_url) or page.medium.try(:small_icon_url)
  end
end
