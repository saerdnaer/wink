# frozen_string_literal: true

# Countable items (adapters, batteries, ...) can be counted on a check list.
class AddCountableToItems < ActiveRecord::Migration[8.1]
  def change
    add_column :items, :countable, :boolean, default: false, null: false
  end
end
