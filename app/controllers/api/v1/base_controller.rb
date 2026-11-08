# frozen_string_literal: true

module Api
  module V1
    # Read-only, unauthenticated API. Responses are JSON-LD (schema.org vocabulary).
    class BaseController < ActionController::API
      include JsonLdRendering

      rescue_from ActiveRecord::RecordNotFound do
        render_jsonld({ "@type" => "Error", "name" => "not found" }, status: :not_found)
      end

      private

      def truthy_param?(name)
        ActiveModel::Type::Boolean.new.cast(params[name])
      end
    end
  end
end
