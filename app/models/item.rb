# frozen_string_literal: true

class Item < ApplicationRecord
  has_many :item_comments, dependent: :destroy
  has_many :items, dependent: :destroy
  has_many :location_items, dependent: :destroy, inverse_of: :location,
                            class_name: "Item", foreign_key: "location_item_id"

  belongs_to :case
  belongs_to :item, optional: true
  belongs_to :item_type, optional: true
  belongs_to :location, optional: true, inverse_of: :location_items,
                        class_name: "Item", foreign_key: "location_item_id"
  belongs_to :product, optional: true

  validates :name, presence: true
  validates :inventory_number, uniqueness: true, allow_nil: true

  scope :existing, -> { where(deleted: false) }
  scope :deleted, -> { where(deleted: true) }

  # Columns searched via Postgres full text search (prefix match per word)
  SEARCH_TEXT_COLUMNS = %w[items.name items.description items.manufacturer items.model
                           items.seller cases.name cases.acronym item_types.name].freeze
  # Columns searched via substring match (e.g. "618" finds VOC00618)
  SEARCH_SUBSTRING_COLUMNS = %w[items.inventory_number items.serial_number].freeze

  # Full text search (PostgreSQL only).
  #
  # Every whitespace separated term must match. A term matches if it is a
  # word prefix in one of the SEARCH_TEXT_COLUMNS or a substring of one of the
  # SEARCH_SUBSTRING_COLUMNS.
  scope :search, lambda { |query|
    terms = query.to_s.split
    next all if terms.empty?

    vector = "to_tsvector('simple', concat_ws(' ', #{SEARCH_TEXT_COLUMNS.join(', ')}))"
    substring_sql = SEARCH_SUBSTRING_COLUMNS.map { |column| "#{column} ILIKE :like" }.join(" OR ")

    relation = left_joins(:case, :item_type)
    terms.each do |term|
      # "AB-12" => "ab:* & 12:*"
      tsquery = term.downcase.scan(/[[:alnum:]]+/).map { |word| "#{word}:*" }.join(" & ")
      conditions = [ substring_sql ]
      conditions << "#{vector} @@ to_tsquery('simple', :tsquery)" if tsquery.present?

      relation = relation.where(conditions.join(" OR "), like: "%#{sanitize_sql_like(term)}%", tsquery: tsquery)
    end
    relation
  }

  # Finds an item by numeric id, otherwise by inventory number or serial number.
  # Respects the current scope, e.g. `Item.existing.lookup!("VOC00618")`.
  def self.lookup!(identifier)
    identifier = identifier.to_s
    return find(identifier) if identifier.match?(/\A\d+\z/)

    find_by(inventory_number: identifier) || find_by!(serial_number: identifier)
  end

  def name_with_model
    if model.blank?
      if manufacturer.blank?
        name.to_s
      else
        "#{name} (#{manufacturer})"
      end
    elsif manufacturer.blank? || manufacturer == "-"
      "#{name} (#{model})"
    else
        "#{name} (#{manufacturer} #{model})"
    end
  end

  def shelf?
    return false if item_type.nil?

    ItemType::LOCATIONS.include?(item_type.name)
  end

  def shelf_level
    return false if item_type.nil?

    ItemType::LOCATIONS.index { |x| item_type.name == x }
  end

  # Overwrite default functions.
  #
  # Items should be only disabled instead of deleted!
  def delete
    destroy
  end

  def destroy
    update_attribute(:deleted, true)
  end

  def deleted?
    self[:deleted]
  end

  def md5_sum
    Digest::MD5.hexdigest(to_json)
  end

  # Move all suitems to the same case.
  #
  # TODO: show message in view before save
  def move_sub_items
    items.each do |sub_item|
      next unless self.case != sub_item.case

      sub_item.case = self.case
      sub_item.location = nil
      sub_item.save!
    end
  end

  def clone_item
    new_item = dup
    new_item.name = name.to_s
    new_item.serial_number = ""
    new_item.items = []

    items.each do |sub_item|
      new_item.items << sub_item.clone_item
    end

    new_item.save
    new_item
  end
end
