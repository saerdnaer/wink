# frozen_string_literal: true

# A kit with one (broken) item and a deleted one, plus helpers for JSON-LD responses.
RSpec.shared_context "with inventory" do
  let(:case_type) { CaseType.create!(name: "Kiste") }
  let(:case_record) { Case.create!(name: "Audio", acronym: "AUD", case_type: case_type) }
  let!(:item) do
    Item.create!(name: "Kabel", case: case_record, inventory_number: "VOC00618", serial_number: "SN-42",
                 manufacturer: "Acme", broken: true)
  end
  let!(:deleted_item) { Item.create!(name: "Alt", case: case_record, deleted: true) }

  def json
    JSON.parse(response.body)
  end

  def list_elements
    json["itemListElement"].pluck("item")
  end
end
