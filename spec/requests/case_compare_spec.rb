# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Comparing two sets" do
  let(:case_type) { CaseType.create!(name: "Kiste") }
  let(:kit_a) { Case.create!(name: "Kit A", acronym: "KA", case_type: case_type) }
  let(:kit_b) { Case.create!(name: "Kit B", acronym: "KB", case_type: case_type) }
  let(:box_type) { ItemType.find_or_create_by!(name: "Box") }

  def add(kit, name, **attrs)
    Item.create!(name: name, case: kit, **attrs)
  end

  def rows(comparison = CaseComparison.new(kit_a, kit_b))
    comparison.rows.to_h { |row| [ row.name, row.status ] }
  end

  describe "CaseComparison" do
    it "tells identical, different, and exclusive items apart" do
      2.times { add(kit_a, "XLR cable", model: "3m") }
      2.times { add(kit_b, "XLR cable", model: "3m") }
      3.times { add(kit_a, "Adapter") }
      add(kit_b, "Adapter")
      add(kit_a, "Only in A")
      add(kit_b, "Only in B")

      expect(rows).to eq("XLR cable" => :same, "Adapter" => :different, "Only in A" => :only_a, "Only in B" => :only_b)
    end

    it "puts items with the same name but different models in one row and calls it different" do
      add(kit_a, "Headphones", manufacturer: "Beyerdynamic", model: "DT770-M")
      add(kit_b, "Headphones", manufacturer: "Philips", model: "Philips something")

      row = CaseComparison.new(kit_a, kit_b).rows.sole
      expect(row).to have_attributes(status: :different, models_differ?: true, count_a: 1, count_b: 1)
      expect(row.details(row.items_a)).to eq "Beyerdynamic DT770-M"
      expect(row.details(row.items_b)).to eq "Philips Philips something"
    end

    it "calls a row different when only some of the items have another model" do
      add(kit_a, "Cable", model: "3m")
      add(kit_a, "Cable", model: "3m")
      add(kit_b, "Cable", model: "3m")
      add(kit_b, "Cable", model: "5m")

      expect(CaseComparison.new(kit_a, kit_b).rows.sole.status).to eq :different
    end

    it "ignores case, spaces and a model of \"-\"" do
      add(kit_a, "XLR  Cable", model: "-", manufacturer: "Acme")
      add(kit_b, "xlr cable", model: "", manufacturer: "ACME")

      expect(CaseComparison.new(kit_a, kit_b).rows.map(&:status)).to eq [ :same ]
    end

    it "matches items of the same product even if they are named differently" do
      product = Product.create!(name: "Cam")
      add(kit_a, "Camera", product: product)
      add(kit_b, "Kamera", product: product)

      expect(CaseComparison.new(kit_a, kit_b).rows.map(&:status)).to eq [ :same ]
    end

    it "leaves out containers, hidden and deleted items" do
      add(kit_a, "Shelf box", item_type: box_type)
      add(kit_a, "Hidden", hidden: true)
      add(kit_a, "Gone", deleted: true)

      expect(CaseComparison.new(kit_a, kit_b).rows).to be_empty
    end

    it "counts the rows per status" do
      add(kit_a, "Same")
      add(kit_b, "Same")
      add(kit_a, "Only in A")

      expect(CaseComparison.new(kit_a, kit_b).summary).to eq(same: 1, different: 0, only_a: 1, only_b: 0)
    end
  end

  describe "GET /cases/compare" do
    before do
      add(kit_a, "XLR cable", inventory_number: "VOC1")
      add(kit_a, "XLR cable", inventory_number: "VOC2")
      add(kit_b, "XLR cable", inventory_number: "VOC3")
      add(kit_a, "Same thing")
      add(kit_b, "Same thing")
      add(kit_b, "Extra in B")
    end

    it "asks for two sets first" do
      get "/cases/compare"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Choose two sets", "Kit A", "Kit B")
    end

    it "shows the comparison item by item" do
      get "/cases/compare", params: { a: kit_a.id, b: kit_b.id }

      expect(response.body).to include("XLR cable", "Same thing", "Extra in B", "VOC1", "VOC3", "only in Kit B", "-1")
      expect(response.body).to include("1 identical", "1 with a different number")
    end

    it "can be reduced to the differences" do
      get "/cases/compare", params: { a: kit_a.id, b: kit_b.id, only: "differences" }

      expect(response.body).to include("XLR cable", "Extra in B")
      expect(response.body).not_to include("Same thing")
    end

    it "says so when both sets contain the same items" do
      get "/cases/compare", params: { a: kit_b.id, b: kit_b.id }

      expect(response.body).to include("same set twice")
    end

    it "is linked from the set pages" do
      get "/cases"
      expect(response.body).to include("/cases/compare")

      get "/cases/#{kit_a.id}"
      expect(response.body).to include("/cases/compare?a=#{kit_a.id}")
    end

    it "shows the models of both sides in one row" do
      add(kit_a, "Headphones", manufacturer: "Beyerdynamic", model: "DT770-M")
      add(kit_b, "Headphones", manufacturer: "Philips", model: "Philips something")

      get "/cases/compare", params: { a: kit_a.id, b: kit_b.id }

      expect(response.body.scan(">Headphones<").size).to eq 1
      expect(response.body).to include("Beyerdynamic DT770-M", "Philips Philips something", "other model")
    end

    it "does not show a serial number of n.a." do
      add(kit_a, "Thing", inventory_number: "VOC9", serial_number: "n.a.")

      get "/cases/compare", params: { a: kit_a.id, b: kit_b.id }

      expect(response.body).to include("VOC9")
      expect(response.body).not_to include("VOC9 · n.a.")
    end
  end
end
