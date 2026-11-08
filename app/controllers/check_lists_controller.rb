# frozen_string_literal: true

class CheckListsController < ApplicationController
  before_action :find_check_list, except: %i[index create new]
  before_action :remove_hidden_items, only: %i[show edit update]

  def index
    @check_lists = CheckList.includes(:check_list_items, event_case: %i[event case])
                            .sort_by do |check_list|
      date = check_list.event&.start_date
      [ date ? -date.to_time.to_i : 0, -check_list.id ]
    end

    respond_to do |format|
      format.html
      format.json { render json: @check_lists.to_json }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: @check_list.to_json }
    end
  end

  def new
    @event_case = EventCase.find_by(event_id: params[:event], case_id: params[:case])

    if @event_case.check_list
      redirect_to check_list_path(@event_case.check_list)
    else
      @event_case.check_list = CheckList.new
    end
  end

  def edit
    shelfs = @check_list.locations
    @check_list_items = @check_list.check_list_items - shelfs
    @check_list_items = @check_list_items.reject { |cli| cli.item.deleted? }

    @grouped_items = @check_list_items.group_by do |cli|
      next if cli.item.shelf?

      if cli.item.location.nil?
        ""
      else
        cli.item.location.name.to_s
      end
    end
  end

  def create
    @event_case = EventCase.find(event_case_params[:event_case])
    @event_case.check_list = CheckList.new(check_list_params)

    # show the form again with an error message, e.g. when the advisor is missing
    if @event_case.check_list.valid? && @event_case.save
      # TODO: move that into the model
      @event_case.check_list.copy_items!

      redirect_to check_list_path(@event_case.check_list)
      # rubocop:disable Layout/LineLength
      # TODO: Send mqtt message, when checklist was created.
      Wink::MqttClient.send_message(
        "'#{@event_case.check_list.advisor}' created '#{@event_case.event.name}' checklist for '#{@event_case.case.name}'"
      )
      # rubocop:enable Layout/LineLength
    else
      render action: "new", status: :unprocessable_entity
    end
  end

  # POST /check_lists/:id/add_advisor (name): puts a name on the list of advisors
  def add_advisor
    name = params[:name].to_s.squish
    return render(json: { error: "name is missing or too long" }, status: :unprocessable_content) if name.blank? || name.length > 100

    added = @check_list.add_advisor(name)
    @check_list.save! if added

    render json: { advisor: @check_list.advisor, added: added }
  end

  # POST /check_lists/:id/finish: closes the list with the state saved so far
  def finish
    if @check_list.checked
      redirect_to check_list_path(@check_list), notice: "Checklist was already finished"
    else
      finish_check_list
      @check_list.save!
      redirect_to check_list_path(@check_list), notice: "Checklist finished"
    end
  end

  # Check checklist.
  def update
    counts = params.dig(:check_list, :counts)

    CheckList.find(params[:id]).check_list_items.includes(:item).find_each do |cli|
      cli.checked = (checked_check_list_params[:checked_check_list_items]&.include?(cli.id.to_s) || false)
      cli.count = parse_count(counts[cli.id.to_s], cli.count) if counts && cli.countable? && counts.key?(cli.id.to_s)

      next if cli.save!

        render action: "edit"
    end

    if ActiveModel::Type::Boolean.new.cast(check_list_params[:checked])
      finish_check_list
    else
      @check_list.checked = false
    end

    @check_list.save!

    if params[:return]
      redirect_to check_list_path(params[:id])
    else
      redirect_to edit_check_list_path(@check_list)
    end
  end

  def destroy
    if @check_list.destroy
      redirect_to check_lists_path,
                  notice: "Deleted '#{@check_list.event.name}' checklist for '#{@check_list.case.name}'"
    else
      render action: "show"
    end
  end

  private

  def finish_check_list
    @check_list.checked = true
    # Mark previous missing items as found and add comment.
    unmark_missing_items(@check_list)
    # Mark items as missing and add comment.
    mark_missing_items(@check_list)
    Wink::MqttClient.send_message(
      "'#{@check_list.advisor}' finished '#{@check_list.event.name}' checklist for '#{@check_list.case.name}'"
    )
  end

  def find_check_list
    @check_list = CheckList.find(params[:id])
  end

  # Items that were hidden after the check list was created do not belong on an
  # open check list any more.
  def remove_hidden_items
    removed = @check_list.remove_hidden_items!
    return if removed.zero? || action_name == "update"

    flash.now[:notice] = "#{removed} hidden #{'item'.pluralize(removed)} removed from this checklist."
  end

  def check_list_params
    params.expect(check_list: %i[comment advisor checked])
  end

  # "" -> nil (not counted), "12" -> 12, anything else keeps the old value
  def parse_count(value, old)
    text = value.to_s.strip
    return nil if text.empty?

    text.match?(/\A\d{1,6}\z/) ? text.to_i : old
  end

  def checked_check_list_params
    params.expect(check_list: [ checked_check_list_items: [] ])
  end

  def event_case_params
    params.expect(check_list: [ :event_case ])
  end

  def unmark_missing_items(checklist)
    checklist.items_without_shelfs.each do |checklist_item|
      # Unmark previously missing items
      # when checklist is finished and item on list is checked.
      item = checklist_item.item
      next unless item.missing == true and checklist_item.checked == true

      item.missing = false
      item.save!

      ItemComment.create(
        author: "WINK",
        comment: "Item was found by '#{checklist.advisor}' during '#{checklist.event.name}'.",
        item_id: checklist_item.item.id
      )
    end
  end

  def mark_missing_items(checklist)
    checklist.items_without_shelfs.each do |checklist_item|
      # Mark items as missing when checklist is finished and items on list are
      # not checked.
      next unless checklist_item.checked == false

      item = checklist_item.item
      item.missing = true
      item.save!

      ItemComment.create(
        author: "WINK",
        comment: "Item marked as missing by '#{checklist.advisor}' during '#{checklist.event.name}'.",
        item_id: checklist_item.item.id
      )
    end
    # TODO: Copy broken state to items and create
    #       a comment containing the event and checklist number.
  end
end
