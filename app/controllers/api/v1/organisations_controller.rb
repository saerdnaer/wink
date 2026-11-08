# frozen_string_literal: true

module Api
  module V1
    class OrganisationsController < BaseController
      # GET /api/v1/organisations?role=manufacturer
      def index
        organisations = Organisation.existing.order(:id)
        organisations = organisations.with_role(params[:role]) if params[:role].present?

        render_list(organisations, "Organisations") { |organisation| OrganisationSerializer.call(organisation, urls: self) }
      end

      def show
        render_jsonld OrganisationSerializer.call(Organisation.existing.find(params[:id]), urls: self)
      end
    end
  end
end
