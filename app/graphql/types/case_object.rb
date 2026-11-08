# frozen_string_literal: true

module Types
  class CaseObject < BaseObject
    field :id, ID, null: false
    field :name, String
    field :acronym, String
  end
end
