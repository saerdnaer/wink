# frozen_string_literal: true

# An organisation can belong to another one (department, subsidiary, ...)
class AddParentToOrganisations < ActiveRecord::Migration[8.1]
  def change
    add_reference :organisations, :parent, foreign_key: { to_table: :organisations }, index: true
  end
end
