class Medium < ApplicationRecord
  searchkick
  belongs_to :languages , class_name: 'Language', foreign_key: 'languages_id'
  belongs_to :locations , class_name: 'Location', foreign_key: 'locations_id'
  belongs_to :licenses , class_name: 'License', foreign_key: 'licenses_id'
  belongs_to :bibliographic_citation
  
  has_many :pages, inverse_of: :medium
  has_many :attributions, as: :content
  has_many :page_contents, as: :content
  has_many :references, as: :parent
  
  enum subclass: [ :image, :video, :sound, :map, :js_map ]
  enum format: [ :jpg, :youtube, :flash, :vimeo, :mp3, :ogg, :wav ]
  enum mime_type: [ 'image/jpeg', 'text/html', 'text/plain', 'video/mp4', 'video/x-ms-wmv', 'video/mpeg', 'video/quicktime', 'video/x-flv', 'audio/mpeg', 'audio/x-wav' ]

  scope :images, -> { where(subclass: :image) }
  scope :videos, -> { where(subclass: :video) }
  scope :sounds, -> { where(subclass: :sound) }
  
  def search_data
    {
        id: id,
        ancestry_ids: ancestry_ids 
    }
  end
  
  def ancestry_ids
      page_contents.pluck(:pages_id)
  end
  
  def is_image?
    subclass == "image"
  end

  def is_video?
    subclass == "video"
  end

  def is_sound?
    subclass == "sound"
  end

  def is_map?
    subclass == "map"
  end

  def is_js_map?
    subclass == "js_map"
  end
  
end


