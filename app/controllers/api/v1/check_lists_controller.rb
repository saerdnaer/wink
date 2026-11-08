# frozen_string_literal: true

module Api
  module V1
    class CheckListsController < BaseController
      def index
        check_lists = CheckList.includes(event_case: %i[event case]).order(:id)

        render_list(check_lists, "Check lists") { |check_list| CheckListSerializer.call(check_list, urls: self) }
      end

      def show
        check_list = CheckList.includes(check_list_items: :item).find(params[:id])

        render_jsonld CheckListSerializer.call(check_list, urls: self, detail: true)
      end
    end
  end
end
