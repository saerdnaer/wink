# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Dashboard" do
  let(:case_type) { CaseType.create!(name: "Kiste") }
  let(:today) { Time.zone.today }
  let(:running) { Event.create!(name: "Running Event", start_date: today - 1, end_date: today + 1, location: "Hall") }
  let(:past) { Event.create!(name: "Past Event", start_date: today - 30, end_date: today - 28, location: "Hall") }

  def kit(name)
    Case.create!(name: name, acronym: name.first(3).upcase, case_type: case_type)
  end

  def list_for(event, kit, checked: [], total: 2, finished: false)
    check_list = CheckList.create!(advisor: "andi", checked: finished)
    EventCase.create!(event: event, case: kit, check_list: check_list)
    total.times do |index|
      item = Item.create!(name: "#{kit.name} item #{index}", case: kit)
      CheckListItem.create!(check_list: check_list, item: item, checked: checked.include?(index))
    end
    check_list
  end

  it "has no running section without a running event" do
    past
    get "/dashboard"

    expect(response.body).not_to include("Running events")
  end

  it "lists the running event with its sets, checklists and their status" do
    EventCase.create!(event: running, case: kit("Without List"))
    list_for(running, kit("Not Started"))
    list_for(running, kit("In Progress"), checked: [ 0 ])
    list_for(running, kit("Is Finished"), checked: [ 0, 1 ], finished: true)

    get "/dashboard"

    expect(response.body).to include("Running events", "Running Event", "1 of 4 checklists finished")
    expect(response.body).to include("no checklist yet", "not started (2 items)", "1 of 2 checked", "finished (2 of 2 checked)")
    expect(response.body).to include("create checklist", "start checking", "continue checking", "show result")
  end

  it "does not show events that are not running" do
    list_for(past, kit("Old Kit"))

    get "/dashboard"

    expect(response.body).not_to include("Running events")
  end

  it "does not count shelves and deleted items" do
    kit_record = kit("Counting")
    check_list = list_for(running, kit_record, total: 1)
    shelf = Item.create!(name: "Shelf", case: kit_record, item_type: ItemType.find_or_create_by!(name: "Box"))
    gone = Item.create!(name: "Gone", case: kit_record, deleted: true)
    [ shelf, gone ].each { |item| CheckListItem.create!(check_list: check_list, item: item) }

    expect(CheckList.find(check_list.id).progress).to eq(checked: 0, total: 1)
  end

  it "says so when an event has no sets" do
    running

    get "/dashboard"

    expect(response.body).to include("No sets are assigned")
  end
end
