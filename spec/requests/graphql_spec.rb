# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GraphQL API" do
  let(:case_type) { CaseType.create!(name: "Kiste") }
  let(:case_record) { Case.create!(name: "Audio", acronym: "AUD", case_type: case_type) }
  let!(:item) { Item.create!(name: "Kabel", case: case_record, inventory_number: "VOC00618") }

  def run(query, variables = {})
    post "/graphql", params: { query: query, variables: variables }, as: :json
    response.parsed_body
  end

  it "finds an item by inventory number" do
    result = run('{ item(inventoryNumber: "VOC00618") { name case { acronym } } }')

    expect(result.dig("data", "item")).to eq("name" => "Kabel", "case" => { "acronym" => "AUD" })
  end

  it "finds an item by identifier" do
    result = run("query($id: ID!) { item(id: $id) { name } }", { id: "VOC00618" })

    expect(result.dig("data", "item", "name")).to eq "Kabel"
  end

  it "lists items as connection and hides deleted ones" do
    Item.create!(name: "Alt", case: case_record, deleted: true)

    result = run("{ items(first: 100) { nodes { name } } }")
    names = result.dig("data", "items", "nodes").pluck("name")

    expect(names).to include("Kabel")
    expect(names).not_to include("Alt")
  end

  it "returns products" do
    Product.create!(name: "Cam", gtin: 4_006_381_333_931)

    result = run("{ products(first: 100) { nodes { name gtin } } }")

    expect(result.dig("data", "products", "nodes")).to include("name" => "Cam", "gtin" => "4006381333931")
  end

  it "returns check lists with their items" do
    check_list = CheckList.create!(advisor: "andi")
    CheckListItem.create!(check_list: check_list, item: item)

    result = run("{ checkLists(first: 100) { nodes { advisor items { item { name } } } } }")

    expect(result.dig("data", "checkLists", "nodes")).to include(
      "advisor" => "andi", "items" => [ { "item" => { "name" => "Kabel" } } ]
    )
  end

  it "returns null for unknown items" do
    expect(run('{ item(inventoryNumber: "nope") { name } }').dig("data", "item")).to be_nil
  end
end
