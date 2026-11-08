# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Items per compartment" do
  let(:case_type) { CaseType.create!(name: "Room set") }
  let(:room) { Case.create!(name: "Room 7", acronym: "R7", case_type: case_type) }
  let(:compartment_type) { ItemType.find_or_create_by!(name: "Compartment") }
  let(:box_type) { ItemType.find_or_create_by!(name: "Box") }

  def create_item(name, **attributes)
    Item.create!({ name: name, case: room }.merge(attributes))
  end

  let!(:audio) { create_item("Compartment Audio", item_type: compartment_type) }
  let!(:video) { create_item("Compartment Video", item_type: compartment_type) }
  let!(:box) { create_item("Box Mics", item_type: box_type, location: audio) }

  before do
    create_item("XLR cable", location: audio)
    create_item("Mic 1", location: box)
    create_item("Mic 2", location: box)
    create_item("Deleted", location: audio, deleted: true)
    create_item("Loose thing")
  end

  describe CompartmentOverview do
    subject(:entry) { described_class.call(Case.where(id: room.id)).first }

    it "counts items directly in a compartment, in its boxes and the boxes" do
      row = entry.rows.find { |r| r.compartment == audio }

      expect(row).to have_attributes(boxes: 1, direct: 1, in_boxes: 2, total: 3)
    end

    it "lists compartments without items with zeros" do
      expect(entry.rows.find { |r| r.compartment == video }).to have_attributes(boxes: 0, total: 0)
    end

    it "counts items outside of any compartment separately and ignores deleted ones" do
      expect(entry.unplaced).to eq 1
      expect(entry.total).to eq 4
    end
  end

  it "shows the table for every set" do
    get "/cases/compartments"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Items per compartment", "Room 7", "Compartment Audio", "Compartment Video",
                                     "not in a compartment")
  end

  it "is linked from the list of sets" do
    get "/cases"

    expect(response.body).to include("/cases/compartments")
  end
end
