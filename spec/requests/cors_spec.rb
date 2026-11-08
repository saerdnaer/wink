# frozen_string_literal: true

require "rails_helper"
require "support/inventory_context"

RSpec.describe "CORS" do
  include_context "with inventory"

  describe "CORS" do
    it "allows cross-origin reads of items" do
      get "/items/VOC00618.jsonld", headers: { "Origin" => "https://urn.ccc.de" }

      expect(response.headers["Access-Control-Allow-Origin"]).to eq "*"
    end

    it "answers preflight requests" do
      options "/items/VOC00618", headers: { "Origin" => "https://urn.ccc.de", "Access-Control-Request-Method" => "GET" }

      expect(response.headers["Access-Control-Allow-Methods"]).to include("GET")
    end

    it "does not open up writes" do
      options "/items/#{item.id}", headers: { "Origin" => "https://urn.ccc.de", "Access-Control-Request-Method" => "DELETE" }

      expect(response.headers["Access-Control-Allow-Origin"]).to be_nil
    end
  end
end
