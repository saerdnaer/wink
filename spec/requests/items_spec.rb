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

  describe "framing" do
    it "does not send X-Frame-Options" do
      get "/items/#{item.id}"

      expect(response.headers).not_to have_key("X-Frame-Options")
    end
  end

  describe "unknown item on the HTML pages" do
    it "shows a 404 page with a search form and similar items" do
      get "/items/VOC0061"

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("Item not found", "VOC0061", "VOC00618")
    end

    it "answers .jsonld with a 404 document" do
      get "/items/nope.jsonld"

      expect(response).to have_http_status(:not_found)
      expect(json["@type"]).to eq "Error"
    end
  end
end
