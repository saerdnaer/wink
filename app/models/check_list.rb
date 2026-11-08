# frozen_string_literal: true

class CheckList < ApplicationRecord
  has_one :event_case, dependent: :nullify
  has_one :event, through: :event_case
  has_one :case,  through: :event_case

  has_many :check_list_items, dependent: :destroy

  validates :advisor, presence: { message: "is missing, please enter your name (or the names of everyone checking)" }

  # "Bert, Ernie and Grover" => ["Bert", "Ernie", "Grover"]
  def advisor_names
    advisor.to_s.split(/\s*(?:,|&|\band\b)\s*/i).map(&:squish).compact_blank
  end

  # Adds a name to the advisors unless it is already listed (ignoring case).
  # Returns true if the name was added.
  def add_advisor(name)
    name = name.to_s.squish
    return false if name.blank? || advisor_names.any? { |existing| existing.casecmp?(name) }

    names = advisor_names + [ name ]
    self.advisor = names.size == 1 ? names.first : "#{names[0..-2].join(', ')} and #{names.last}"
    true
  end

  # rubocop:disable Naming/PredicateMethod
  def copy_items!
    return false if check_list_items.any?

    # hidden items are not part of a check list
    event_case.case.not_deleted_items.not_hidden.each do |ec_item|
      cl_item = CheckListItem.new
      cl_item.item = ec_item
      cl_item.item.broken = ec_item.broken
      cl_item.item.missing = ec_item.missing
      check_list_items << cl_item
      save!
    end

    true
  end
  # rubocop:enable Naming/PredicateMethod

  def locations
    check_list_items.select { |cli| cli.item&.shelf? }
  end

  def items
    check_list_items
  end

  # Number of checked and all items that are shown on the check list (without shelves
  # and deleted items). Preload check_list_items: { item: :item_type } for many lists.
  def progress
    shown = check_list_items.select { |entry| entry.item && !entry.item.deleted? && !entry.item.shelf? }
    { checked: shown.count(&:checked), total: shown.size }
  end

  # Counted pieces of countable items compared with the number expected (identical
  # items count as one entry per piece). Only entries that were counted show up.
  CountResult = Struct.new(:name, :counted, :expected, keyword_init: true) do
    def difference = counted - expected
  end

  def count_results
    entries = check_list_items.select { |entry| entry.countable? && !entry.item.deleted? }
    results = entries.group_by { |entry| entry.item.name.to_s.squish.downcase }.filter_map do |_name, group|
      counted = group.filter_map(&:count)
      next if counted.empty?

      CountResult.new(name: group.first.item.name, counted: counted.sum, expected: group.size)
    end
    results.sort_by { |result| result.name.to_s.downcase }
  end

  # A check list is started as soon as one item was checked (or it was finished).
  def started?
    checked || check_list_items.any?(&:checked)
  end

  def items_without_shelfs
    check_list_items - locations
  end
end
