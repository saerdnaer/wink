# frozen_string_literal: true

# Allow other sites (e.g. https://urn.ccc.de/scan/) to read WINK pages and the
# JSON / JSON-LD / GraphQL endpoints from the browser.
#
# Only reading is opened up (GET/HEAD/OPTIONS) and no credentials are allowed,
# so cookies are never sent cross-site. GraphQL needs POST for its queries.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "*"

    resource "/graphql", headers: :any, methods: %i[post options]
    resource "*", headers: :any, methods: %i[get head options],
                  expose: %w[Link X-Total-Count X-Page X-Per-Page]
  end
end
