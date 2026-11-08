# frozen_string_literal: true

class RenameProductsWikiUrlToWebUrl < ActiveRecord::Migration[8.1]
  def change
    rename_column :products, :wiki_url, :web_url

    # Column comments are only supported by Postgres
    return unless connection.adapter_name.match?(/postgres/i)

    change_column_comment :products, :web_url,
                          from: "Dazugehörige Wikiseite auf c3voc.de/wiki",
                          to: "Dazugehörige Webseite, z.B. Wikiseite auf c3voc.de/wiki"
  end
end
