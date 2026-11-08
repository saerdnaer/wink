# frozen_string_literal: true

require "rails_helper"
require "support/inventory_context"

RSpec.describe "Item pages" do
  include_context "with inventory"

  describe "GET /items/:id.jsonld" do
    it "serves the item as JSON-LD" do
      get "/items/#{item.id}.jsonld"

      expect(response.media_type).to eq "application/ld+json"
      expect(json).to include("@type" => "Item", "assetId" => "VOC00618")
    end

    it "resolves inventory numbers" do
      get "/items/VOC00618.jsonld"

      expect(json["wink:id"]).to eq item.id
    end

    it "lists items" do
      get "/items.jsonld"

      expect(json["@type"]).to eq "ItemList"
    end
  end
end
