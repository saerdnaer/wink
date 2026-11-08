# frozen_string_literal: true

# Compares the contents of two sets (cases, kits) item by item.
#
# Items with the same name (ignoring case and spaces) are put in the same row, and
# so are items of the same product, even if they are named differently. A row is
# "different" when the number of items differs or the items differ in manufacturer
# or model. Containers (shelves, compartments, boxes, ...) and hidden items are
# left out.
class CaseComparison
  STATUSES = %i[same different only_a only_b].freeze

  Row = Struct.new(:name, :items_a, :items_b, keyword_init: true) do
    def count_a = items_a.size
    def count_b = items_b.size

    def status
      return :only_a if items_b.empty?
      return :only_b if items_a.empty?

      count_a == count_b && signature(items_a) == signature(items_b) ? :same : :different
    end

    # same number of items, but other manufacturers or models
    def models_differ?
      count_a == count_b && status == :different
    end

    # "Neutrik NC3, Neutrik other" of the items of one side
    def details(items)
      items.filter_map { |item| CaseComparison.details(item).presence }.uniq.join(", ")
    end

    private

    def signature(items)
      items.map { |item| CaseComparison.signature(item) }.sort
    end
  end

  attr_reader :case_a, :case_b

  def self.details(item)
    [ item.manufacturer, item.model ].reject { |value| value.blank? || value == "-" }.join(" ")
  end

  def self.signature(item)
    [ item.manufacturer, item.model ].map { |value| normalize(value) }
  end

  def self.normalize(value)
    text = value.to_s.squish.downcase
    text == "-" ? "" : text
  end

  def initialize(case_a, case_b)
    @case_a = case_a
    @case_b = case_b
  end

  def rows
    @rows ||= begin
      tagged = items_of(case_a).map { |item| [ :a, item ] } + items_of(case_b).map { |item| [ :b, item ] }
      rows = cluster(tagged).map do |entries|
        row_items = ->(side) { entries.select { |tag, _| tag == side }.map(&:last) }
        Row.new(name: entries.first.last.name, items_a: row_items.call(:a), items_b: row_items.call(:b))
      end
      rows.sort_by { |row| [ row.name.to_s.downcase, row.items_a.first&.id.to_i ] }
    end
  end

  # number of rows per status
  def summary
    counts = rows.group_by(&:status).transform_values(&:size)
    STATUSES.index_with { |status| counts.fetch(status, 0) }
  end

  def identical?
    rows.all? { |row| row.status == :same }
  end

  private

  # Case#active_items would drop items without an item type (NOT IN with NULL)
  def items_of(kit)
    items = kit.not_deleted_items.not_hidden
    items = items.where(item_type_id: nil).or(items.where.not(item_type_id: ItemType.locations.select(:id)))
    # product_id is enough to match items, the products table is not needed
    items.order(:name, :id).to_a
  end

  # Items that share a name or a product end up in the same cluster.
  def cluster(tagged)
    parent = {}
    find = lambda do |key|
      parent[key] ||= key
      parent[key] = find.call(parent[key]) unless parent[key] == key
      parent[key]
    end

    tagged.map(&:last).each do |item|
      name_key = [ :name, self.class.normalize(item.name) ]
      find.call(name_key)
      parent[find.call([ :product, item.product_id ])] = find.call(name_key) if item.product_id
    end

    tagged.group_by { |_, item| find.call([ :name, self.class.normalize(item.name) ]) }.values
  end
end
