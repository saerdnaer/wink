class Product < ActiveRecord::Base
  has_many :vendor_links, class_name: "ProductVendorLink"
  has_many :items

  validates :gtin, uniqueness: true, allow_nil: true

  # `manufacturer` stays a free text. It is linked to an Organisation by its name
  # (ignoring case and surrounding spaces): the name is the identifier.
  def self.normalize_manufacturer(name)
    name.to_s.strip.downcase.presence
  end

  # Hash {normalized name => Organisation} to link many products without a query each
  def self.organisations_by_name
    Organisation.existing.index_by { |organisation| normalize_manufacturer(organisation.name) }
  end

  def manufacturer_organisation
    key = self.class.normalize_manufacturer(manufacturer)
    Organisation.existing.find_by("lower(btrim(name)) = ?", key) if key
  end

  scope :existing, -> { where(deleted: false) }
  scope :deleted, -> { where(deleted: true) }

  # Existing products that look like the given attributes (same GTIN, product link,
  # model of the same manufacturer, or same name). Used to offer a merge instead of
  # creating a duplicate. The table is small, so the comparison happens in Ruby
  # (ignoring case, spaces and punctuation).
  def self.similar_to(attributes, except: nil)
    attrs = attributes.to_h.symbolize_keys
    norm = ->(value) { value.to_s.downcase.gsub(/[^[:alnum:]]/, "") }

    existing.where.not(id: except).select do |product|
      same_gtin = attrs[:gtin].present? && product.gtin.to_s == attrs[:gtin].to_s
      same_link = attrs[:product_link].present? && product.product_link == attrs[:product_link]
      same_model = norm.call(attrs[:model]).present? && norm.call(product.model) == norm.call(attrs[:model]) &&
                   (norm.call(attrs[:manufacturer]).blank? || norm.call(product.manufacturer).blank? ||
                    norm.call(product.manufacturer) == norm.call(attrs[:manufacturer]))
      same_name = norm.call(attrs[:name]).present? && norm.call(product.name) == norm.call(attrs[:name])
      same_gtin || same_link || same_model || same_name
    end
  end

  def deleted?
    self[:deleted]
  end
end
