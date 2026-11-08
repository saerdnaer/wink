# frozen_string_literal: true

class CheckList < ApplicationRecord
  has_one :event_case, dependent: :nullify
  has_one :event, through: :event_case
  has_one :case,  through: :event_case

  has_many :check_list_items, dependent: :destroy

  validates :advisor, presence: { message: "is missing, please enter your name (or the names of everyone checking)" }

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

  # A check list is started as soon as one item was checked (or it was finished).
  def started?
    checked || check_list_items.any?(&:checked)
  end

  def items_without_shelfs
    check_list_items - locations
  end
end
