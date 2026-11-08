# frozen_string_literal: true

require "rails_helper"
require "tmpdir"

RSpec.describe "Products" do
  let(:png) { Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==") }

  let(:image_dir) { Pathname.new(Dir.mktmpdir) }

  before { allow(ProductImageStore).to receive(:root).and_return(image_dir) }

  after { FileUtils.rm_rf(image_dir) }

  def upload(content, name: "pic.png", type: "image/png")
    file = Tempfile.new([ "upload", File.extname(name) ])
    file.binmode
    file.write(content)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, type, true, original_filename: name)
  end

  def stored_files
    Dir.children(image_dir)
  end

  describe "the menu" do
    it "links to the products" do
      get "/items"

      expect(response.body).to include(%(href="/products"))
    end
  end

  describe "the form" do
    it "is multipart and has an image upload" do
      get "/products/new"

      expect(response.body).to include("multipart/form-data", %(type="file"), "product[image]", "product[web_url]", "data-image-drop")
    end
  end

  describe "manufacturer and organisations" do
    let!(:organisation) { Organisation.create!(name: "Blackmagic Design", roles: [ "manufacturer" ]) }

    it "links the manufacturer to the organisation of the same name, ignoring case" do
      product = Product.create!(name: "Mini", manufacturer: " blackmagic design ")

      get "/products/#{product.id}"

      expect(response.body).to include(%(<a href="/organisations/#{organisation.id}"))
    end

    it "keeps an unknown manufacturer as plain text" do
      product = Product.create!(name: "Cable", manufacturer: "Some local shop")

      get "/products/#{product.id}"

      expect(response.body).to include("Some local shop")
      expect(response.body).not_to include(%(href="/organisations/))
    end

    it "links the manufacturer in the list" do
      Product.create!(name: "Mini", manufacturer: "Blackmagic Design")

      get "/products"

      expect(response.body).to include(%(<a href="/organisations/#{organisation.id}">Blackmagic Design</a>))
    end

    it "offers the organisations as suggestions but accepts any text" do
      get "/products/new"

      expect(response.body).to match(/list=.manufacturer_organisations.*<option value=.Blackmagic Design./m)
    end

    it "lists the products on the page of the organisation" do
      product = Product.create!(name: "Mini", manufacturer: "Blackmagic Design")

      get "/organisations/#{organisation.id}"

      expect(response.body).to match(%r{href=.\/products\/#{product.id}.})
    end

    it "keeps the products linked when the organisation is renamed" do
      product = Product.create!(name: "Mini", manufacturer: "Blackmagic Design")
      other = Product.create!(name: "Other", manufacturer: "Sony")

      organisation.update!(name: "Blackmagic")

      expect(product.reload.manufacturer).to eq "Blackmagic"
      expect(product.manufacturer_organisation).to eq organisation
      expect(other.reload.manufacturer).to eq "Sony"
    end
  end

  describe "POST /products" do
    it "creates a product with an image" do
      post "/products", params: { product: { name: "Cam", manufacturer: "Sony", image: upload(png) } }

      product = Product.find_by!(name: "Cam")
      expect(response).to redirect_to("/products/#{product.id}")
      expect(product.image).to match(/\A\h{24}\.png\z/)
      expect(stored_files).to eq [ product.image ]
    end

    it "asks to merge when a similar product exists" do
      existing = Product.create!(name: "Cam", manufacturer: "Sony", model: "Z200")
      count = Product.count

      post "/products", params: { product: { name: "Camera", manufacturer: "sony", model: "Z-200" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Similar products already exist", %(value="#{existing.id}"), "Create anyway")
      expect(Product.count).to eq count
    end

    it "creates the product anyway when confirmed" do
      Product.create!(name: "Cam")

      post "/products", params: { product: { name: "Cam" }, create_anyway: "1" }

      expect(Product.where(name: "Cam").count).to eq 2
    end

    it "merges into the existing product, filling only empty fields and keeping its image" do
      existing = Product.create!(name: "Cam", model: "Z200", image: "keep.png")
      count = Product.count

      post "/products", params: { product: { name: "Other name", model: "Z200", manufacturer: "Sony", details: "4K", image: upload(png) },
                                  merge_into: existing.id }

      expect(response).to redirect_to("/products/#{existing.id}")
      expect(existing.reload).to have_attributes(name: "Cam", manufacturer: "Sony", details: "4K", image: "keep.png")
      expect(Product.count).to eq count
      expect(stored_files).to be_empty
    end

    it "stores short description and details separately" do
      post "/products", params: { product: { name: "Box", description: "Eurobox", details: "40 x 30 cm" } }

      expect(Product.find_by!(name: "Box")).to have_attributes(description: "Eurobox", details: "40 x 30 cm")
    end

    it "creates a product without an image" do
      post "/products", params: { product: { name: "Cable" } }

      expect(Product.find_by!(name: "Cable").image).to be_nil
    end

    it "rejects files that are not images, whatever the browser claims" do
      post "/products", params: { product: { name: "Fake", image: upload("<?php echo 1;", name: "x.png", type: "image/png") } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("must be a PNG, JPEG, GIF or WebP image")
      expect(Product.find_by(name: "Fake")).to be_nil
      expect(stored_files).to be_empty
    end

    it "rejects too large images" do
      stub_const("ProductImageStore::MAX_SIZE", 10)

      post "/products", params: { product: { name: "Big", image: upload(png) } }

      expect(response.body).to include("is too large")
      expect(stored_files).to be_empty
    end
  end

  describe "PATCH /products/:id" do
    let!(:product) do
      post "/products", params: { product: { name: "Cam", image: upload(png) } }
      Product.find_by!(name: "Cam")
    end

    it "replaces the image and removes the old file" do
      old = product.image

      patch "/products/#{product.id}", params: { product: { name: "Cam II", image: upload(png) } }

      product.reload
      expect(product.name).to eq "Cam II"
      expect(product.image).not_to eq old
      expect(stored_files).to eq [ product.image ]
    end

    it "keeps the image when no new one is uploaded" do
      patch "/products/#{product.id}", params: { product: { name: "Renamed" } }

      expect(stored_files).to eq [ product.reload.image ]
    end

    it "removes the image on request" do
      patch "/products/#{product.id}", params: { product: { name: "Cam" }, remove_image: "1" }

      expect(product.reload.image).to be_nil
      expect(stored_files).to be_empty
    end

    it "keeps the old image when the update is invalid" do
      Product.create!(name: "Other", gtin: 4_006_381_333_931)

      patch "/products/#{product.id}", params: { product: { gtin: "4006381333931", image: upload(png) } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(stored_files).to eq [ product.reload.image ]
    end
  end

  describe "GET /products/:id/image" do
    it "serves the image" do
      post "/products", params: { product: { name: "Cam", image: upload(png) } }
      product = Product.find_by!(name: "Cam")

      get "/products/#{product.id}/image"

      expect(response.media_type).to eq "image/png"
      expect(response.body.b).to eq png
    end

    it "is 404 without an image" do
      product = Product.create!(name: "Cable")

      get "/products/#{product.id}/image"

      expect(response).to have_http_status(:not_found)
    end

    it "never serves files outside of the image directory" do
      product = Product.create!(name: "Evil", image: "../../../etc/hosts")

      get "/products/#{product.id}/image"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "pages" do
    it "shows the image on the product page and the list" do
      post "/products", params: { product: { name: "Cam", image: upload(png) } }
      product = Product.find_by!(name: "Cam")

      get "/products/#{product.id}"
      expect(response.body).to include("/products/#{product.id}/image")

      get "/products"
      expect(response.body).to include("/products/#{product.id}/image")
    end

    it "flags products as deleted instead of deleting them" do
      product = Product.create!(name: "Cable")

      delete "/products/#{product.id}"

      expect(product.reload.deleted).to be true
      expect(response).to redirect_to("/products")
    end
  end
end
