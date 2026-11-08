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
end
