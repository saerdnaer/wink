# frozen_string_literal: true

class CheckListItem < ApplicationRecord
  belongs_to :check_list
  belongs_to :item

  # Pieces counted for a countable item (adapters, batteries, ...); normally NULL.
  validates :count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  def countable?
    item&.countable == true
  end
end
