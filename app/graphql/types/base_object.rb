# frozen_string_literal: true

module Types
  class BaseObject < GraphQL::Schema::Object
    # Record types are named "<Name>Object" in Ruby (to not clash with the models
    # of the same name), but exposed as "<Name>" in the schema.
    def self.default_graphql_name
      super.delete_suffix("Object")
    end
  end
end
