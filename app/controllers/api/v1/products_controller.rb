# frozen_string_literal: true

module Api
  module V1
    class ProductsController < BaseController
      def index
        render_list(Product.existing.order(:id), "Products") { |product| ProductSerializer.call(product, urls: self) }
      end

      def show
        render_jsonld ProductSerializer.call(Product.existing.find(params[:id]), urls: self)
      end
    end
  end
end
