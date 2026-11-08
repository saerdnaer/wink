# frozen_string_literal: true

require "rails_helper"
require "tmpdir"

RSpec.describe "Create product from URL" do
  let(:png) { Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==") }
  let(:image_dir) { Pathname.new(Dir.mktmpdir) }
  let(:url) { "https://shop.example/de/Eurobehaelter/ED-4317-HG.html" }
  let(:json_ld) do
    [
      { "@context" => "https://schema.org", "@type" => "BreadcrumbList", "itemListElement" => [] },
      { "@context" => "https://schema.org", "@type" => "Product", "name" => "Eurobehälter ED 43/17 HG",
        "image" => [ "/images/box.png" ],
        "description" => "Außenmaße<br>40 x 30 cm - <span class=\"x\">Volumen</span>: 15 Liter",
        "url" => "https://shop.example/de/Eurobehaelter/ED-4317-HG.html",
        "sku" => "SKU-1", "mpn" => "ED 43/17 HG", "gtin14" => "4260109960629",
        "brand" => { "@type" => "Thing", "name" => "AUER Packaging" },
        "manufacturer" => { "@type" => "Organization", "name" => "AUER Packaging" },
        "offers" => { "@type" => "Offer", "priceCurrency" => "EUR", "price" => "11.32" } }
    ]
  end
  let(:html) { %(<html><head><script type="application/ld+json">#{json_ld.to_json}</script></head><body></body></html>) }

  before do
    allow(ProductImageStore).to receive(:root).and_return(image_dir)
    allow(SafeFetch).to receive(:get) do |requested, **|
      if requested.end_with?(".png")
        SafeFetch::Response.new(png.b, "image/png", requested)
      else
        SafeFetch::Response.new(html, "text/html; charset=utf-8", requested)
      end
    end
  end

  after { FileUtils.rm_rf(image_dir) }

  it "has an input field on the product list" do
    get "/products"

    expect(response.body).to include("create_product_from_url", %(action="/products/from_url"))
  end

  it "creates the product from the schema.org metadata and opens it for review" do
    post "/products/from_url", params: { url: url }

    product = Product.find_by!(gtin: 4_260_109_960_629)
    expect(response).to redirect_to("/products/#{product.id}/edit")
    expect(product).to have_attributes(name: "Eurobehälter ED 43/17 HG", manufacturer: "AUER Packaging",
                                       product_number: "ED 43/17 HG", price: BigDecimal("11.32"),
                                       description: nil, details: "Außenmaße 40 x 30 cm - Volumen: 15 Liter",
                                       product_link: "https://shop.example/de/Eurobehaelter/ED-4317-HG.html")
    expect(product.meta["source_url"]).to eq url
  end

  it "downloads the product image" do
    post "/products/from_url", params: { url: url }

    product = Product.find_by!(gtin: 4_260_109_960_629)
    expect(Dir.children(image_dir)).to eq [ product.image ]
    expect(flash[:notice]).to include("The image was downloaded")
  end

  it "asks before importing a product that already exists" do
    post "/products/from_url", params: { url: url }
    post "/products/from_url", params: { url: url }

    expect(Product.where(gtin: 4_260_109_960_629).count).to eq 1
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Similar products already exist", "merge_into")
  end

  it "creates a second product when confirmed" do
    Product.create!(name: "Eurobehälter ED 43/17 HG")
    count = Product.count

    post "/products/from_url", params: { url: url, create_anyway: "1" }

    expect(Product.count).to eq count + 1
  end

  it "merges the page into an existing product, filling only empty fields" do
    existing = Product.create!(name: "ED 43/17 HG", manufacturer: "Auer", model: "ED 43/17 HG")
    count = Product.count

    post "/products/from_url", params: { url: url, merge_into: existing.id }

    expect(response).to redirect_to("/products/#{existing.id}")
    expect(existing.reload).to have_attributes(name: "ED 43/17 HG", manufacturer: "Auer",
                                               gtin: 4_260_109_960_629, details: "Außenmaße 40 x 30 cm - Volumen: 15 Liter")
    expect(existing.image).to be_present
    expect(Product.count).to eq count
  end

  it "still creates the product when the image cannot be used" do
    json_ld.last["image"] = "/images/box.txt"
    allow(SafeFetch).to receive(:get).with(url, any_args).and_return(SafeFetch::Response.new(html, "text/html", url))
    allow(SafeFetch).to receive(:get).with("https://shop.example/images/box.txt", any_args)
                                     .and_return(SafeFetch::Response.new("not an image", "text/plain", url))

    post "/products/from_url", params: { url: url }

    expect(Product.find_by!(gtin: 4_260_109_960_629).image).to be_nil
    expect(flash[:notice]).to include("The image was not used")
  end

  it "reports pages without product data" do
    allow(SafeFetch).to receive(:get).and_return(SafeFetch::Response.new("<html><body>nothing</body></html>", "text/html", url))

    post "/products/from_url", params: { url: url }

    expect(response).to redirect_to("/products")
    expect(flash[:alert]).to include("Import failed", "no schema.org product data")
  end

  it "reports blocked URLs" do
    allow(SafeFetch).to receive(:get).and_call_original

    post "/products/from_url", params: { url: "http://127.0.0.1:80/admin" }

    expect(flash[:alert]).to include("not a public address")
  end

  it "reports invalid input" do
    allow(SafeFetch).to receive(:get).and_call_original

    post "/products/from_url", params: { url: "not a url" }

    expect(flash[:alert]).to include("Import failed")
  end
end
