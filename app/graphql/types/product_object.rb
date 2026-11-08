# frozen_string_literal: true

module Types
  class ProductObject < BaseObject
    field :id, ID, null: false
    field :name, String
    field :description, String
    field :manufacturer, String
    field :model, String
    field :product_number, String
    # GTINs exceed GraphQL's 32 bit Int
    field :gtin, String
    field :asin, String
    field :price, Float
    field :insurance_value, Float
    field :image, String
    field :product_link, String
    field :url, String
    field :wiki_url, String
    field :voc_class, String
    field :alternate_ids, [ String ]
    field :alternate_urls, [ String ]
    field :meta, GraphQL::Types::JSON
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false

    def gtin
      object.gtin&.to_s
    end
  end
end
