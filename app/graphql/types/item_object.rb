# frozen_string_literal: true

module Types
  class ItemObject < BaseObject
    field :id, ID, null: false
    field :name, String
    field :description, String
    field :manufacturer, String
    field :model, String
    field :inventory_number, String
    field :serial_number, String
    field :price, Float
    field :date_of_purchase, GraphQL::Types::ISO8601Date
    field :seller, String
    field :broken, Boolean, null: false
    field :missing, Boolean, null: false
    field :reused, Boolean
    field :hidden, Boolean
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime

    field :case, CaseObject, resolver_method: :resolve_case
    field :item_type, ItemTypeObject
    field :product, ProductObject
    field :parent, ItemObject, description: "Item this item is a sub item of"
    field :location, ItemObject, description: "Physical location (shelf, compartment, ...) of the item"
    field :sub_items, [ ItemObject ], null: false
    field :comments, [ ItemCommentObject ], null: false

    def resolve_case
      object.case
    end

    def parent
      object.item
    end

    def sub_items
      object.items.existing
    end

    def comments
      object.item_comments
    end
  end
end
