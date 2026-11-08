# frozen_string_literal: true

module Types
  class CheckListItemObject < BaseObject
    field :id, ID, null: false
    field :checked, Boolean, null: false
    field :broken, Boolean, null: false
    field :missing, Boolean, null: false
    field :comment, String
    field :item, ItemObject
  end
end
