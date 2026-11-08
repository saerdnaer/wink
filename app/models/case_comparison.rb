# frozen_string_literal: true

# Compares the contents of two sets (cases, kits) item by item.
#
# Items count as the same kind of item when they have the same product or, without
# a product, the same name, manufacturer and model. Containers (shelves,
# compartments, boxes, ...) and hidden items are left out.
class CaseComparison
  STATUSES = %i[same different only_a only_b].freeze

  Row = Struct.new(:name, :details, :items_a, :items_b, keyword_init: true) do
    def count_a = items_a.size
    def count_b = items_b.size

    def status
      return :only_a if items_b.empty?
      return :only_b if items_a.empty?

      count_a == count_b ? :same : :different
    end

    # items missing in B (positive) or more in B (negative)
    def difference = count_a - count_b
  end

  attr_reader :case_a, :case_b

  def initialize(case_a, case_b)
    @case_a = case_a
    @case_b = case_b
  end

  def rows
    @rows ||= begin
      grouped_a = group(case_a)
      grouped_b = group(case_b)

      rows = (grouped_a.keys | grouped_b.keys).map do |key|
        items_a = grouped_a.fetch(key, [])
        items_b = grouped_b.fetch(key, [])
        first = (items_a + items_b).first
        Row.new(name: first.name, details: details(first), items_a: items_a, items_b: items_b)
      end
      rows.sort_by { |row| [ row.name.to_s.downcase, row.details.to_s.downcase ] }
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
  def group(kit)
    items = kit.not_deleted_items.not_hidden
    items = items.where(item_type_id: nil).or(items.where.not(item_type_id: ItemType.locations.select(:id)))
    # product_id is enough to match items, the products table is not needed
    items.order(:name, :id).group_by { |item| key(item) }
  end

  def key(item)
    return [ :product, item.product_id ] if item.product_id

    [ :item, *[ item.name, item.manufacturer, item.model ].map { |value| normalize(value) } ]
  end

  def normalize(value)
    text = value.to_s.squish.downcase
    text == "-" ? "" : text
  end

  def details(item)
    [ item.manufacturer, item.model ].reject { |value| value.blank? || value == "-" }.join(" ")
  end
end
