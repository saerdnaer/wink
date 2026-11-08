# frozen_string_literal: true

class ExtendProducts< ActiveRecord::Migration[8.1]
  def change
    postgres = connection.adapter_name.match?(/postgres/i)

    add_column :products, :gtin, :bigint
    add_column :products, :manufacturer, :string
    add_column :products, :model, :string
    add_column :products, :insurance_value, :decimal
    add_column :products, :price, :decimal
    add_column :products, :image, :text
    add_column :products, :voc_class, :text
    add_column :products, :url, :text
    add_column :products, :asin, :text
    # Postgres (production) uses native text[]; SQLite (dev/test) has no array
    # type, so the same columns are stored as JSON arrays there.
    if postgres
      add_column :products, :alternate_ids, :text, array: true
      add_column :products, :alternate_urls, :text, array: true
      add_column :products, :meta, :jsonb
    else
      add_column :products, :alternate_ids, :json
      add_column :products, :alternate_urls, :json
      add_column :products, :meta, :json
    end
    add_column :products, :deleted, :boolean, default: false
    add_column :products, :wiki_url, :text

    add_index :products, :gtin, unique: true

    # Column comments are only supported by Postgres
    return unless postgres

    change_column_comment :products, :gtin, "Global Trade Item Number (GTIN)"
    change_column_comment :products, :description, "Produktkurzbescheibung, z.B. \"Kamera\""
    change_column_comment :products, :manufacturer, "Hersteller"
    change_column_comment :products, :model, "Modellnummer"
    change_column_comment :products, :insurance_value, "Wiederbeschaffungswert"
    change_column_comment :products, :price, "Ursprünglicher Beschaffungswert"
    change_column_comment :products, :image, "Dateiname für Bild des Produkts"
    change_column_comment :products, :wiki_url, "Dazugehörige Wikiseite auf c3voc.de/wiki"
  end
end
