# frozen_string_literal: true

module Api
  module V1
    class ItemsController < BaseController
      # GET /api/v1/items
      #   q, case_id, item_type_id, broken, missing, page, per_page
      def index
        items = Item.existing.includes(:case, :item_type, :product, :item, :location).order(:id)
        items = items.search(params[:q]) if params[:q].present?
        items = items.where(case_id: params[:case_id]) if params[:case_id].present?
        items = items.where(item_type_id: params[:item_type_id]) if params[:item_type_id].present?
        items = items.where(broken: truthy_param?(:broken)) if params[:broken].present?
        items = items.where(missing: truthy_param?(:missing)) if params[:missing].present?

        render_list(items, "Items") { |item| ItemSerializer.call(item, urls: self) }
      end

      # GET /api/v1/items/:id  (numeric id, inventory number or serial number)
      def show
        item = Item.existing.lookup!(params[:id])

        render_jsonld ItemSerializer.call(item, urls: self, detail: true)
      end
    end
  end
end
