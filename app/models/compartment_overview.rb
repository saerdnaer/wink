# frozen_string_literal: true

# Number of items per compartment for every set (case).
#
# A compartment is a section item (ItemType::SECTIONS, e.g. "Compartment Audio").
# Items point to their container with `location_item_id`: directly to the
# compartment or to a box/bag (ItemType::BAGS) which in turn sits in the compartment.
# Containers themselves are not counted as items, boxes are counted separately.
class CompartmentOverview
  Row = Struct.new(:compartment, :boxes, :direct, :in_boxes, keyword_init: true) do
    def total = direct + in_boxes
  end
  Entry = Struct.new(:case_record, :rows, :unplaced, keyword_init: true) do
    def total = rows.sum(&:total) + unplaced
  end

  # Returns one Entry per case (ordered by name) with a Row per compartment.
  # `unplaced` counts the items that are in no compartment (and no box in one).
  def self.call(cases = Case.includes(:case_type).order(:name))
    new(cases).entries
  end

  def initialize(cases)
    @cases = cases.to_a
  end

  def entries
    items = Item.existing.includes(:item_type).where(case_id: @cases.map(&:id)).group_by(&:case_id)
    @cases.map { |case_record| entry(case_record, items.fetch(case_record.id, [])) }
  end

  private

  def entry(case_record, items)
    by_location = items.group_by(&:location_item_id)
    sections = items.select { |item| type_of(item).in?(ItemType::SECTIONS) }
    placed = Set.new

    rows = sections.sort_by { |section| [ type_of(section).to_s, section.name.to_s ] }.map do |section|
      children = by_location.fetch(section.id, [])
      boxes = children.select { |child| type_of(child).in?(ItemType::BAGS) }
      direct = children.reject { |child| container?(child) }
      in_boxes = boxes.flat_map { |box| by_location.fetch(box.id, []).reject { |child| container?(child) } }
      placed.merge((direct + in_boxes).map(&:id))
      Row.new(compartment: section, boxes: boxes.size, direct: direct.size, in_boxes: in_boxes.size)
    end

    unplaced = items.count { |item| !container?(item) && placed.exclude?(item.id) }
    Entry.new(case_record: case_record, rows: rows, unplaced: unplaced)
  end

  def type_of(item) = item.item_type&.name

  def container?(item) = type_of(item).in?(ItemType::LOCATIONS)
end
