# frozen_string_literal: true

module Types
  class QueryType < BaseObject
    field :item, ItemObject, description: "Find an item by id, inventory number or serial number" do
      argument :id, ID, required: false
      argument :inventory_number, String, required: false
      argument :serial_number, String, required: false
    end

    field :items, ItemObject.connection_type, null: false do
      argument :search, String, required: false, description: "Full text search (PostgreSQL only)"
      argument :case_id, ID, required: false
      argument :item_type_id, ID, required: false
      argument :broken, Boolean, required: false
      argument :missing, Boolean, required: false
    end

    field :product, ProductObject do
      argument :id, ID
    end
    field :products, ProductObject.connection_type, null: false

    field :check_list, CheckListObject do
      argument :id, ID
    end
    field :check_lists, CheckListObject.connection_type, null: false

    def item(id: nil, inventory_number: nil, serial_number: nil)
      items = ::Item.existing
      return items.lookup!(id) if id
      return items.find_by(inventory_number: inventory_number) if inventory_number

      items.find_by(serial_number: serial_number) if serial_number
    rescue ActiveRecord::RecordNotFound
      nil
    end

    def items(search: nil, case_id: nil, item_type_id: nil, broken: nil, missing: nil)
      scope = ::Item.existing.includes(:case, :item_type, :product, :item, :location).order(:id)
      scope = scope.search(search) if search.present?
      scope = scope.where(case_id: case_id) if case_id
      scope = scope.where(item_type_id: item_type_id) if item_type_id
      scope = scope.where(broken: broken) unless broken.nil?
      scope = scope.where(missing: missing) unless missing.nil?
      scope
    end

    def product(id:)
      ::Product.existing.find_by(id: id)
    end

    def products
      ::Product.existing.order(:id)
    end

    def check_list(id:)
      ::CheckList.find_by(id: id)
    end

    def check_lists
      ::CheckList.includes(event_case: %i[event case]).order(:id)
    end
  end
end
