# frozen_string_literal: true

# Organisations are sellers, vendors, manufacturers, owners, ... (see Organisation::ROLES)
class CreateOrganisations < ActiveRecord::Migration[8.1]
  def change
    postgres = connection.adapter_name.match?(/postgres/i)

    create_table :organisations do |t|
      t.string :name, null: false
      t.string :legal_name
      t.text :description
      t.text :url
      t.string :email
      t.string :telephone
      t.text :address
      t.text :logo, comment: "Dateiname für das Logo der Organisation"
      # Postgres (production) uses native text[]; SQLite (dev/test) stores a JSON array
      if postgres
        t.text :roles, array: true, default: [], null: false
        t.jsonb :meta
      else
        t.json :roles, default: [], null: false
        t.json :meta
      end
      t.boolean :deleted, default: false, null: false

      t.timestamps
    end

    add_index :organisations, :name
  end
end
