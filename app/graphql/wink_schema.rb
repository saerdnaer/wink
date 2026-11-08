# frozen_string_literal: true

# Read-only GraphQL API. Served at POST /graphql.
class WinkSchema < GraphQL::Schema
  query Types::QueryType

  max_depth 10
  max_complexity 1000
  default_max_page_size 100

  use GraphQL::Dataloader
end
