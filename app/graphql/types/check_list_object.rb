# frozen_string_literal: true

module Types
  class CheckListObject < BaseObject
    field :id, ID, null: false
    field :advisor, String
    field :checked, Boolean, null: false
    field :comment, String
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false
    field :case, CaseObject, resolver_method: :resolve_case
    field :event_name, String, description: "Name of the event this check list belongs to"
    field :items, [ CheckListItemObject ], null: false

    def resolve_case
      object.case
    end

    def event_name
      object.event&.name
    end

    def items
      object.check_list_items.includes(:item)
    end
  end
end
