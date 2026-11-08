# frozen_string_literal: true

# Number of pieces counted for a check list item, e.g. more adapters than expected.
# Normally NULL (nothing counted).
class AddCountToCheckListItems < ActiveRecord::Migration[8.1]
  def change
    add_column :check_list_items, :count, :integer
  end
end
