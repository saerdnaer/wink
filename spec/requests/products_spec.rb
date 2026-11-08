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

      expect(response.body).to include("multipart/form-data", %(type="file"), "product[image]")
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
