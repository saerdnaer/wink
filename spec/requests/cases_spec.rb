# frozen_string_literal: true

require "rails_helper"
require "support/inventory_context"

RSpec.describe "Kit (case) page" do
  include_context "with inventory"

  describe "check lists on the kit page" do
    let(:today) { Time.zone.today }
    let(:running) { Event.create!(name: "running", start_date: today - 1, end_date: today + 1, location: "x") }
    let(:past) { Event.create!(name: "past", start_date: today - 30, end_date: today - 28, location: "x") }

    it "offers to create a check list for running events only" do
      [ running, past ].each { |event| EventCase.create!(event: event, case: case_record) }

      get "/cases/#{case_record.id}"

      expect(response.body).to include("create checklist for running")
      expect(response.body).not_to include("for past")
    end

    it "links an existing check list" do
      EventCase.create!(event: running, case: case_record, check_list: CheckList.create!(advisor: "andi"))

      get "/cases/#{case_record.id}"

      expect(response.body).to include("running")
      expect(response.body).not_to include("create checklist")
    end

    it "shows no create link when no event is running" do
      get "/cases/#{case_record.id}"

      expect(response.body).not_to include("create checklist")
    end
  end
end
