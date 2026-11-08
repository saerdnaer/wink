# frozen_string_literal: true

class DashboardController < ApplicationController
  def show
    @broken_or_missing_items = Item
                               .where(deleted: false)
                               .and(
                                 Item.where(broken: true)
                                     .or(Item.where(missing: true))
                               ).sort
    # items without a case (case_id is nil) end up in a group with key nil, listed last
    @grouped_items = @broken_or_missing_items.group_by(&:case)
                                             .sort_by { |c, _items| [ c.nil? ? 1 : 0, c&.name.to_s ] }
    @running_events = Event.running
                           .includes(event_cases: [ :case, { check_list: { check_list_items: { item: :item_type } } } ])
                           .order(:start_date, :name)
    @upcoming_events = Event
                       .where(end_date: (Time.zone.today - 2)..4.weeks.after).order(:start_date)
    @upcoming_transports = Transport
                           .where(pickup_time: Time.zone.today..4.weeks.after).order(:pickup_time)
  end
end
