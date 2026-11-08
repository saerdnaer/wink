# frozen_string_literal: true

require "csv"

class ItemsController < ApplicationController
  include JsonLdRendering

  before_action :find_item, except: %i[index create new export]

  def index
    if params["commit"].in?(%w[Export Download Preview])
      redirect_to controller: "items", action: "index", format: :csv, export: params["export"].permit!,
                  download: params["commit"] == "Download"
    end

    @query = params[:q].to_s.strip

    respond_to do |format|
      format.html do
        @items = Item.where(deleted: false).search(@query).includes(:case, :location)

        # Single hit -> jump directly to the item
        redirect_to item_path(@items.first) if @query.present? && @items.size == 1
      end

      format.json do
        @items = Item.where(deleted: false).search(@query)

        render json: @items
      end

      format.jsonld do
        items = Item.where(deleted: false).search(@query)
                    .includes(:case, :item_type, :product, :item, :location).order(:id)

        render_list(items, "Items") { |item| ItemSerializer.call(item, urls: self) }
      end

      format.csv do
        filter = ""
        headers["Content-Type"] ||= "text/csv"
        if params["download"].in?([ true, "true" ])
          headers["Content-Disposition"] = "attachment; filename=\"export.csv\""
        end

        cases = if params["export"]
          params["export"]["cases"].reject(&:empty?)
        else
          []
        end

        filter += " and price >= #{params['export']['price']}" unless params["export"]["price"].empty?

        unless params["export"]["item_type_id"].empty? || params["export"]["item_type_id"] == [ "" ]
          filter += " and item_type_id IN(#{params['export']['item_type_id'].reject(&:empty?).join(',')})"
        end

        if cases.any?
          @items = []

          cases.each do |c|
            Item.where("case_id = #{c}" + filter).where(deleted: false).find_each { |i| @items << i }
          end
          Rails.logger.debug @items
        else
          @items = Item.where(deleted: false)
        end
      end
    end
  end

  def show
    @subitems = Item.where(item: @item)

    respond_to do |format|
      format.html { load_check_lists }
      format.json { render json: @item.to_json }
      format.jsonld { render_jsonld ItemSerializer.call(@item, urls: self, detail: true) }
    end
  end

  def new
    @item = Item.new(case: Case.find(params[:case_id]))
    @item.location_item_id = params[:location] if params[:location]
    @locations = ItemType.where(case_id: @item.case).order(:name)
  end

  def edit
    return unless @item.deleted == true

      redirect_to item_path(@item), notify: "Item is still deleted!"
  end

  def create
    @item = Item.new(item_params)

    if @item.save
      redirect_to case_path(@item.case), notice: "Created item #{@item.name}"
    else
      render action: "new"
    end
  end

  def update
    if @item.case_id != item_params[:case_id]
      @item.location = nil
      @item.save
    end

    if @item.update(item_params)
      # move subitems to same case
      @item.move_sub_items

      redirect_to case_path(@item.case), notice: "Updated '#{@item.name}'"
    else
      render action: "edit"
    end
  end

  def destroy
    if @item.destroy
      redirect_to case_path(@item.case), notice: "Disabled '#{@item.name}' in case '#{@item.case.acronym}'"
    else
      render action: "show"
    end
  end

  def export
    @cases = Case.all
  end

  def clone
    new_item = @item.clone_item
    if new_item
      redirect_to edit_item_path(new_item)
    else
      redirect_to item_path(Item.find(params[:id]))
    end
  end

  private

  # Check lists of the item's kit plus all check lists the item is part of,
  # newest first. @check_list_items maps check_list_id => entry of this item.
  def load_check_lists
    entries = CheckListItem.where(item: @item).index_by(&:check_list_id)
    ids = entries.keys
    ids += @item.case.check_lists.pluck(:id) if @item.case

    @check_list_items = entries
    @check_lists = CheckList.where(id: ids.uniq).includes(event_case: %i[event case])
                            .sort_by { |cl| cl.event&.start_date ? -cl.event.start_date.to_time.to_i : 0 }

    # running events the kit takes part in, but without a check list yet
    @creatable_event_cases = if @item.case
      EventCase.where(case: @item.case, check_list_id: nil).joins(:event).merge(Event.running).includes(:event)
    else
      []
    end
  end

  def find_item
    @item = Item.unscoped.lookup!(params[:id])
  rescue ActiveRecord::RecordNotFound
    item_not_found
  end

  # 404 page that offers a search for the requested id (inventory/serial number).
  def item_not_found
    @query = params[:id].to_s

    respond_to do |format|
      format.html do
        @items = similar_items(@query)
        render :not_found, status: :not_found
      end
      format.json { render json: { error: "item not found" }, status: :not_found }
      format.jsonld { render_jsonld({ "@type" => "Error", "name" => "not found" }, status: :not_found) }
      format.any { head :not_found }
    end
  end

  def similar_items(query)
    Item.existing.search(query).includes(:case).order(:name).limit(50)
  rescue ActiveRecord::StatementInvalid
    # full text search needs PostgreSQL
    Item.none
  end

  def item_params
    params.expect(item: %i[name description manufacturer model
                           item_id case_id date_of_purchase
                           price serial_number inventory_number broken missing
                           item_type_id location_item_id])
  end
end
