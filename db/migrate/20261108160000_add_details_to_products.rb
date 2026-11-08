# frozen_string_literal: true

# `description` is the short product kind ("Camera"). Everything longer
# (technical data, texts of shop pages) goes into the new `details` column.
class AddDetailsToProducts < ActiveRecord::Migration[8.1]
  LONG_DESCRIPTION = 120

  def up
    add_column :products, :details, :text
    # descriptions that are clearly not short anymore move to details
    execute <<~SQL.squish
      UPDATE products SET details = description, description = NULL
      WHERE description IS NOT NULL AND length(description) > #{LONG_DESCRIPTION}
    SQL
    return unless connection.adapter_name.match?(/postgres/i)

    change_column_comment :products, :details, "Ausführliche Beschreibung und allgemeine Daten, z.B. technische Angaben"
  end

  def down
    execute "UPDATE products SET description = details WHERE description IS NULL AND details IS NOT NULL"
    remove_column :products, :details
  end
end
