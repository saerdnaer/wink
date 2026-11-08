# frozen_string_literal: true

require "rails_helper"
require "support/inventory_context"

RSpec.describe "REST API v1 (JSON-LD)" do
  include_context "with inventory"

  describe "content type and context" do
    it "serves application/ld+json with the schema.org context" do
      get "/api/v1/items/#{item.id}"

      expect(response.media_type).to eq "application/ld+json"
      expect(json["@context"]).to include("https://schema.org/")
      expect(json.keys.last).to eq "@context"
    end
  end

  describe "GET /api/v1/items" do
    before { get "/api/v1/items" }

    it "is a schema.org ItemList of Products without deleted items" do
      expect(json).to include("@type" => "ItemList")
      expect(list_elements.pluck("@type").uniq).to eq [ "Item" ]
      expect(list_elements.pluck("wink:id")).to include(item.id)
      expect(list_elements.pluck("wink:id")).not_to include(deleted_item.id)
    end

    it "sets pagination headers" do
      expect(response.headers["X-Total-Count"]).to eq Item.existing.count.to_s
      expect(json["numberOfItems"]).to eq Item.existing.count
    end

    it "links to the next page" do
      get "/api/v1/items", params: { per_page: 1 }

      expect(response.headers["Link"]).to match(/page=2.*rel="next"/)
    end

    it "filters by broken" do
      get "/api/v1/items", params: { broken: "true" }

      expect(list_elements.pluck("wink:id")).to include(item.id)
    end
  end

  describe "GET /api/v1/items/:id" do
    it "maps item properties to schema.org terms" do
      get "/api/v1/items/#{item.id}"

      expect(json).to include(
        "@type" => "Item", "name" => "Kabel", "assetId" => "VOC00618", "serialNumber" => "SN-42",
        "manufacturer" => { "@type" => "Organization", "name" => "Acme" },
        "condition" => "https://schema.org/DamagedCondition", "wink:broken" => true
      )
    end

    it "references the case" do
      get "/api/v1/items/#{item.id}"

      expect(json["wink:kit"]).to include("name" => "Audio", "alternateName" => "AUD")
    end

    it "uses an absolute @id" do
      get "/api/v1/items/#{item.id}"

      expect(json["@id"]).to eq "http://www.example.com/items/#{item.id}"
    end

    it "finds by inventory number and serial number" do
      get "/api/v1/items/VOC00618"
      expect(json["wink:id"]).to eq item.id

      get "/api/v1/items/SN-42"
      expect(json["wink:id"]).to eq item.id
    end

    it "returns 404 for unknown and deleted items" do
      get "/api/v1/items/nope"
      expect(response).to have_http_status(:not_found)

      get "/api/v1/items/#{deleted_item.id}"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "products" do
    let!(:product) { Product.create!(name: "Cam", manufacturer: "Sony", product_number: "A7", gtin: 4_006_381_333_931) }

    it "lists products as ProductModel" do
      get "/api/v1/products"

      expect(list_elements.pluck("name")).to include("Cam")
      expect(list_elements.pluck("@type").uniq).to eq [ "ProductModel" ]
    end

    it "lists the web page of a product as sameAs" do
      product.update!(web_url: "https://c3voc.de/wiki/cam")

      get "/api/v1/products/#{product.id}"

      expect(json["sameAs"]).to include("https://c3voc.de/wiki/cam")
    end

    it "maps product properties to schema.org terms" do
      get "/api/v1/products/#{product.id}"

      expect(json).to include("mpn" => "A7", "gtin" => "4006381333931",
                              "manufacturer" => { "@type" => "Organization", "name" => "Sony" })
    end

    it "links items to their product via model" do
      item.update!(product: product)

      get "/api/v1/items/#{item.id}"

      expect(json["model"]).to eq("@id" => "http://www.example.com/products/#{product.id}")
    end
  end

  describe "check lists" do
    let!(:check_list) { CheckList.create!(advisor: "andi") }

    before { CheckListItem.create!(check_list: check_list, item: item, checked: true) }

    it "shows a check list as ItemList of ListItems" do
      get "/api/v1/check_lists/#{check_list.id}"

      entry = json["itemListElement"].first
      expect(json["@type"]).to eq "ItemList"
      expect(entry).to include("@type" => "ListItem", "position" => 1, "wink:checked" => true)
      expect(entry["item"]).to include("name" => "Kabel", "assetId" => "VOC00618")
    end

    it "lists check lists" do
      get "/api/v1/check_lists"

      expect(list_elements.pluck("wink:advisor")).to include("andi")
    end
  end
end
