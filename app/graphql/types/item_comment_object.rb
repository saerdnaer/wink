# frozen_string_literal: true

module Types
  class ItemCommentObject < BaseObject
    field :id, ID, null: false
    field :author, String
    field :comment, String
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
