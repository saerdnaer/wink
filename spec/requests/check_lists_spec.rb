# frozen_string_literal: true

require "rails_helper"
require "support/inventory_context"

RSpec.describe "Check lists" do
  include_context "with inventory"

  describe "creating a check list" do
    let(:event) { Event.create!(name: "ev", start_date: Time.zone.today, end_date: Time.zone.today, location: "x") }
    let!(:event_case) { EventCase.create!(event: event, case: case_record) }

    it "shows a helpful error instead of crashing when the advisor is missing" do
      post "/check_lists", params: { check_list: { advisor: "", comment: "", event_case: event_case.id } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Advisor is missing, please enter your name")
    end

    it "creates the check list with an advisor" do
      post "/check_lists", params: { check_list: { advisor: "Bert", comment: "", event_case: event_case.id } }

      expect(response).to have_http_status(:found)
      expect(event_case.reload.check_list.advisor).to eq "Bert"
    end
  end

  describe "check list result page" do
    let(:event) { Event.create!(name: "ev", start_date: Time.zone.today, end_date: Time.zone.today, location: "x") }
    let!(:check_list) { CheckList.create!(advisor: "andi") }

    before do
      EventCase.create!(event: event, case: case_record, check_list: check_list)
      CheckListItem.create!(check_list: check_list, item: item)
    end

    it "does not list items as missing before the check was started" do
      get "/check_lists/#{check_list.id}"

      expect(response.body).to include("Not started yet (1 items to check)")
      expect(response.body).not_to include("Missing (")
    end

    it "lists unchecked items as not checked yet while checking" do
      CheckListItem.create!(check_list: check_list, item: Item.create!(name: "Zwei", case: case_record), checked: true)

      get "/check_lists/#{check_list.id}"

      expect(response.body).to include("Not checked yet (1)")
    end

    it "lists unchecked items as missing once the check list is finished" do
      check_list.update!(checked: true)

      get "/check_lists/#{check_list.id}"

      expect(response.body).to include("Missing (1)")
    end
  end

  describe "check list deep links" do
    let(:event) { Event.create!(name: "ev", start_date: Time.zone.today, end_date: Time.zone.today, location: "x") }
    let!(:check_list) { CheckList.create!(advisor: "andi") }

    before do
      EventCase.create!(event: event, case: case_record, check_list: check_list)
      CheckListItem.create!(check_list: check_list, item: item)
    end

    it "has anchors for inventory number and WINK id and a searchable item on the edit page" do
      get "/check_lists/#{check_list.id}/edit"

      expect(response.body).to include("id='VOC00618'", "id='#{item.id}'", "data-search='Kabel (Acme) VOC00618 SN-42 #{item.id}'")
      expect(response.body).to include("section_heading", "item_name", "S/N SN-42")
    end

    it "links from the item page to the checkbox of the item" do
      get "/items/#{item.id}"

      expect(response.body).to include("/check_lists/#{check_list.id}/edit#VOC00618")
    end

    it "links closed check lists to the result page" do
      check_list.update!(checked: true)

      get "/items/#{item.id}"

      expect(response.body).to include("/check_lists/#{check_list.id}#VOC00618")
    end

    it "has anchors on the result page" do
      check_list.update!(checked: true)

      get "/check_lists/#{check_list.id}"

      expect(response.body).to include("id='VOC00618'")
    end
  end

  describe "stacked items on the check list edit page" do
    let(:event) { Event.create!(name: "ev", start_date: Time.zone.today, end_date: Time.zone.today, location: "x") }
    let!(:check_list) { CheckList.create!(advisor: "andi") }

    before { EventCase.create!(event: event, case: case_record, check_list: check_list) }

    def add(name, **attrs)
      CheckListItem.create!(check_list: check_list, item: Item.create!(name: name, case: case_record, **attrs))
    end

    it "stacks identical items without inventory and serial number" do
      3.times { add("Netzkabel") }

      get "/check_lists/#{check_list.id}/edit"

      expect(response.body).to include("class='checklist_stack'", "3×")
    end

    it "stacks items with the same title even if only some have a model" do
      add("Adapter BNC T-Stück", model: "No 2525371", manufacturer: "TRU COMPONENTS")
      add("Adapter BNC T-Stück")
      add("Adapter BNC T-Stück")

      get "/check_lists/#{check_list.id}/edit"

      expect(response.body).to include("3×", "TRU COMPONENTS No 2525371")
    end

    it "does not stack items with an inventory or serial number" do
      add("Netzkabel", inventory_number: "VOC1")
      add("Netzkabel", serial_number: "42")
      add("Netzkabel")

      get "/check_lists/#{check_list.id}/edit"

      expect(response.body).not_to include("class='checklist_stack'")
    end

    it "treats serial number n.a. as no serial number" do
      2.times { add("Netzkabel", serial_number: "n.a.") }

      get "/check_lists/#{check_list.id}/edit"

      expect(response.body).to include("2×")
    end
  end

  describe "copying items into a new check list" do
    let(:event) { Event.create!(name: "ev", start_date: Time.zone.today, end_date: Time.zone.today, location: "x") }

    it "skips hidden and deleted items" do
      visible = Item.create!(name: "sichtbar", case: case_record, hidden: false)
      unset = Item.create!(name: "ungesetzt", case: case_record, hidden: nil)
      hidden = Item.create!(name: "versteckt", case: case_record, hidden: true)
      event_case = EventCase.create!(event: event, case: case_record)
      event_case.update!(check_list: CheckList.create!(advisor: "andi"))

      event_case.check_list.copy_items!

      ids = event_case.check_list.check_list_items.pluck(:item_id)
      expect(ids).to include(visible.id, unset.id, item.id)
      expect(ids).not_to include(hidden.id, deleted_item.id)
    end
  end

  describe "edit page: local storage and user name" do
    let(:event) { Event.create!(name: "ev", start_date: Time.zone.today, end_date: Time.zone.today, location: "x") }
    let!(:check_list) { CheckList.create!(advisor: "andi") }

    before do
      EventCase.create!(event: event, case: case_record, check_list: check_list)
      CheckListItem.create!(check_list: check_list, item: item)
    end

    it "marks the form so the browser can keep its state in the local storage" do
      get "/check_lists/#{check_list.id}/edit"

      expect(response.body).to include(%(data-check-list-id="#{check_list.id}"))
    end

    it "lets the browser remember the advisor name" do
      other_case = Case.create!(name: "Video", acronym: "VID", case_type: case_type)
      EventCase.create!(event: event, case: other_case)

      get "/check_lists/new", params: { event: event.id, case: other_case.id }

      expect(response.body).to include(%(data-remember-username="true"))
    end
  end

  describe "edit page: intro text" do
    let(:event) { Event.create!(name: "ev", start_date: Time.zone.today, end_date: Time.zone.today, location: "x") }
    let!(:check_list) { CheckList.create!(advisor: "andi") }

    before { EventCase.create!(event: event, case: case_record, check_list: check_list) }

    it "explains what to do" do
      get "/check_lists/#{check_list.id}/edit"

      expect(response.body).to include("check_list_intro", "Go through the set")
    end
  end

  describe "result page: unsaved changes" do
    let(:event) { Event.create!(name: "ev", start_date: Time.zone.today, end_date: Time.zone.today, location: "x") }
    let!(:check_list) { CheckList.create!(advisor: "andi") }

    before do
      EventCase.create!(event: event, case: case_record, check_list: check_list)
      CheckListItem.create!(check_list: check_list, item: item, checked: true)
    end

    it "carries the data the browser needs to compare with its local copy" do
      get "/check_lists/#{check_list.id}"

      expect(response.body).to include("unsaved_notice", "data-edit-url", "data-check-list-id='#{check_list.id}'")
    end
  end

  describe "menu" do
    let(:event) { Event.create!(name: "ev", start_date: Time.zone.today, end_date: Time.zone.today, location: "x") }
    let!(:check_list) { CheckList.create!(advisor: "andi") }

    before { EventCase.create!(event: event, case: case_record, check_list: check_list) }

    it "has a burger button and the item search on normal pages" do
      get "/check_lists/#{check_list.id}"

      expect(response.body).to include("menu_toggle", "search items")
    end

    it "hides the item search while checking a list" do
      get "/check_lists/#{check_list.id}/edit"

      expect(response.body).to include("menu_toggle")
      expect(response.body).not_to include("search items")
    end
  end

  describe "edit page: sections" do
    let(:event) { Event.create!(name: "ev", start_date: Time.zone.today, end_date: Time.zone.today, location: "x") }
    let!(:check_list) { CheckList.create!(advisor: "andi") }

    before do
      EventCase.create!(event: event, case: case_record, check_list: check_list)
      CheckListItem.create!(check_list: check_list, item: item)
    end

    it "shows who is doing the check" do
      check_list.update!(advisor: "Bert and Ernie", comment: "before the event")

      get "/check_lists/#{check_list.id}/edit"

      expect(response.body).to include("Checked by", "Bert and Ernie", "before the event")
    end

    it "has a later button and a fold triangle for every section" do
      get "/check_lists/#{check_list.id}/edit"

      expect(response.body).to include("section_later", "fold_toggle", "Long press: fold / unfold.")
    end
  end

  describe "index" do
    let(:event) { Event.create!(name: "Congress", start_date: Time.zone.today, end_date: Time.zone.today, location: "x") }

    it "lists the check lists with event, set, advisor and status" do
      open_list = CheckList.create!(advisor: "Bert")
      EventCase.create!(event: event, case: case_record, check_list: open_list)
      other_case = Case.create!(name: "Video", acronym: "VID", case_type: case_type)
      done = CheckList.create!(advisor: "Ernie", checked: true)
      EventCase.create!(event: event, case: other_case, check_list: done)

      get "/check_lists"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Congress", "Audio", "Video", "Bert", "Ernie", "not started", "finished")
    end

    it "copes with no check lists" do
      CheckList.destroy_all

      get "/check_lists"

      expect(response.body).to include("No checklists yet")
    end

    it "copes with check lists without an event" do
      CheckList.create!(advisor: "Orphan")

      get "/check_lists"

      expect(response.body).to include("Orphan")
    end
  end

  describe "edit page: pencil on sections" do
    let(:event) { Event.create!(name: "ev", start_date: Time.zone.today, end_date: Time.zone.today, location: "x") }
    let!(:check_list) { CheckList.create!(advisor: "andi") }
    let!(:shelf) { Item.create!(name: "Rack 1", case: case_record) }

    before do
      EventCase.create!(event: event, case: case_record, check_list: check_list)
      item.update!(location: shelf)
      CheckListItem.create!(check_list: check_list, item: item)
    end

    it "links the section to the edit page of its location" do
      get "/check_lists/#{check_list.id}/edit"

      expect(response.body).to include("section_edit", "/items/#{shelf.id}/edit")
    end

    it "has no pencil for items without a location" do
      item.update!(location: nil)

      get "/check_lists/#{check_list.id}/edit"

      expect(response.body).not_to include("section_edit")
    end
  end

  describe "counting countable items" do
    let(:event) { Event.create!(name: "ev", start_date: Time.zone.today, end_date: Time.zone.today, location: "x") }
    let!(:check_list) { CheckList.create!(advisor: "andi") }
    let(:entries) { check_list.check_list_items.reload }

    before { EventCase.create!(event: event, case: case_record, check_list: check_list) }

    def add_entry(name, countable: true, **attrs)
      entry_item = Item.create!(name: name, case: case_record, countable: countable)
      CheckListItem.create!(check_list: check_list, item: entry_item, **attrs)
    end

    def save_counts(counts, checked: [])
      patch "/check_lists/#{check_list.id}",
            params: { check_list: { checked: "false", checked_check_list_items: checked, counts: counts } }
    end

    it "offers a count field for countable items only" do
      add_entry("Battery AA")
      add_entry("Cable", countable: false)

      get "/check_lists/#{check_list.id}/edit"

      expect(response.body.scan("count_field").size).to eq 1
      expect(response.body).to include("placeholder='1'", "check_list[counts][")
    end

    it "counts a stack of countable items once, against the number of items in the stack" do
      first = add_entry("Adapter")
      2.times { add_entry("Adapter") }

      get "/check_lists/#{check_list.id}/edit"

      expect(response.body.scan("count_field").size).to eq 1
      expect(response.body).to include("name='check_list[counts][#{first.id}]'", "placeholder='3'")
    end

    it "stores the counted number, normally nil" do
      entry = add_entry("Battery AA")
      expect(entry.count).to be_nil

      save_counts({ entry.id => "7" })

      expect(entry.reload.count).to eq 7
    end

    it "empties the count with a blank value" do
      entry = add_entry("Battery AA", count: 3)

      save_counts({ entry.id => "" })

      expect(entry.reload.count).to be_nil
    end

    it "keeps the old value for input that is no number and ignores items that are not countable" do
      entry = add_entry("Battery AA", count: 3)
      plain = add_entry("Cable", countable: false)

      save_counts({ entry.id => "lots", plain.id => "5" })

      expect(entry.reload.count).to eq 3
      expect(plain.reload.count).to be_nil
    end

    it "leaves counts alone when the form sends none" do
      entry = add_entry("Battery AA", count: 3)

      patch "/check_lists/#{check_list.id}", params: { check_list: { checked: "false", checked_check_list_items: [ entry.id.to_s ] } }

      expect(entry.reload).to have_attributes(count: 3, checked: true)
    end

    it "validates the count" do
      entry = add_entry("Battery AA")
      entry.count = -1

      expect(entry).not_to be_valid
    end

    it "compares the counted with the expected number on the result page" do
      entry = add_entry("Adapter", count: 5)
      2.times { add_entry("Adapter") }
      add_entry("Battery", count: 1)
      add_entry("Never counted")

      get "/check_lists/#{check_list.id}"

      expect(entry.check_list.count_results.map(&:to_a)).to eq [ [ "Adapter", 5, 3 ], [ "Battery", 1, 1 ] ]
      expect(response.body).to include("Counted items", "+2", "as expected")
      expect(response.body).not_to include("Never counted")
    end

    it "gives the browser the counts the server knows" do
      entry = add_entry("Battery AA", count: 4)

      get "/check_lists/#{check_list.id}"

      expect(response.body).to include("&quot;count:#{entry.id}&quot;:&quot;4&quot;")
    end

    it "is part of the JSON-LD" do
      entry = add_entry("Battery AA", count: 4)

      get "/api/v1/check_lists/#{check_list.id}"

      listed = JSON.parse(response.body)["itemListElement"].find { |e| e["wink:checked"] == false }
      expect(listed["wink:count"]).to eq 4
      expect(entry.item.countable).to be true
    end
  end

  describe "adding your name" do
    let(:event) { Event.create!(name: "ev", start_date: Time.zone.today, end_date: Time.zone.today, location: "x") }
    let!(:check_list) { CheckList.create!(advisor: "Bert") }

    before { EventCase.create!(event: event, case: case_record, check_list: check_list) }

    def add_advisor(name)
      post "/check_lists/#{check_list.id}/add_advisor", params: { name: name }
      JSON.parse(response.body)
    end

    it "has a button on the edit page" do
      get "/check_lists/#{check_list.id}/edit"

      expect(response.body).to include("add_my_name", "advisor_names", "/check_lists/#{check_list.id}/add_advisor")
    end

    it "adds the name to the advisors" do
      expect(add_advisor("Ernie")).to eq("advisor" => "Bert and Ernie", "added" => true)
      expect(check_list.reload.advisor).to eq "Bert and Ernie"
    end

    it "lists three or more names with commas" do
      add_advisor("Ernie")

      expect(add_advisor("Grover")["advisor"]).to eq "Bert, Ernie and Grover"
    end

    it "does not add a name twice, ignoring case and spaces" do
      expect(add_advisor("  bert ")).to eq("advisor" => "Bert", "added" => false)
    end

    it "rejects empty and very long names" do
      add_advisor("")
      expect(response).to have_http_status(:unprocessable_content)

      add_advisor("x" * 101)
      expect(response).to have_http_status(:unprocessable_content)
      expect(check_list.reload.advisor).to eq "Bert"
    end

    it "knows the names in advisor strings" do
      check_list.advisor = "Bert, Ernie & Grover and Oscar"

      expect(check_list.advisor_names).to eq %w[Bert Ernie Grover Oscar]
      expect(CheckList.new(advisor: "Alexander").advisor_names).to eq [ "Alexander" ]
    end
  end

  describe "hidden items on an open check list" do
    let(:event) { Event.create!(name: "ev", start_date: Time.zone.today, end_date: Time.zone.today, location: "x") }
    let!(:check_list) { CheckList.create!(advisor: "andi") }
    let!(:visible_entry) { CheckListItem.create!(check_list: check_list, item: item) }
    let!(:hidden_entry) do
      CheckListItem.create!(check_list: check_list, item: Item.create!(name: "Versteckt", case: case_record, hidden: true))
    end

    before { EventCase.create!(event: event, case: case_record, check_list: check_list) }

    it "removes them from the check list when it is opened for checking" do
      get "/check_lists/#{check_list.id}/edit"

      expect(check_list.check_list_items.reload).to eq [ visible_entry ]
      expect(response.body).to include("1 hidden item removed from this checklist.")
      expect(response.body).not_to include("Versteckt")
    end

    it "removes them when the result page is opened" do
      get "/check_lists/#{check_list.id}"

      expect(check_list.check_list_items.reload).to eq [ visible_entry ]
    end

    it "removes them before saving, so saving does not bring them back" do
      patch "/check_lists/#{check_list.id}", params: { check_list: { checked: "false", checked_check_list_items: [ visible_entry.id.to_s ] } }

      expect(check_list.check_list_items.reload).to eq [ visible_entry ]
      expect(visible_entry.reload.checked).to be true
    end

    it "keeps the entries of a closed check list" do
      check_list.update!(checked: true)

      get "/check_lists/#{check_list.id}"

      expect(check_list.check_list_items.reload).to include(hidden_entry)
      expect(response.body).not_to include("hidden item removed")
    end

    it "does not mention anything when no item is hidden" do
      hidden_entry.item.update!(hidden: false)

      get "/check_lists/#{check_list.id}/edit"

      expect(response.body).not_to include("removed from this checklist")
      expect(check_list.check_list_items.reload.size).to eq 2
    end

    it "does not count hidden items in the progress" do
      expect(CheckList.find(check_list.id).tap { |list| list.check_list_items.load }.progress[:total]).to eq 1
      # a closed list keeps the entry, but still does not show it in the progress
      check_list.update!(checked: true)
      expect(CheckList.find(check_list.id).progress[:total]).to eq 1
    end
  end
end
