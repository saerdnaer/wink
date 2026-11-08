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
end
