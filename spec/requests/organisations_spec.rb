# frozen_string_literal: true

require "rails_helper"
require "tmpdir"

RSpec.describe "Organisations" do
  let(:png) { Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==") }
  let(:image_dir) { Pathname.new(Dir.mktmpdir) }

  before { allow(OrganisationImageStore).to receive(:root).and_return(image_dir) }

  after { FileUtils.rm_rf(image_dir) }

  def upload(content, name: "logo.png", type: "image/png")
    file = Tempfile.new([ "upload", File.extname(name) ])
    file.binmode
    file.write(content)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, type, true, original_filename: name)
  end

  def json
    JSON.parse(response.body)
  end

  describe "menu and form" do
    it "is linked in the menu" do
      get "/items"

      expect(response.body).to include(%(href="/organisations"))
    end

    it "has role checkboxes and a logo upload" do
      get "/organisations/new"

      expect(response.body).to include("multipart/form-data", "organisation[logo]", "organisation_roles_seller",
                                       "organisation_roles_vendor", "organisation_roles_manufacturer",
                                       "organisation_roles_owner")
    end
  end

  describe "creating and updating" do
    it "creates an organisation with several roles and a logo" do
      post "/organisations", params: { organisation: { name: "AUER Packaging", roles: [ "", "manufacturer", "seller" ],
                                                       url: "https://www.auer-packaging.com", logo: upload(png) } }

      organisation = Organisation.find_by!(name: "AUER Packaging")
      expect(response).to redirect_to("/organisations/#{organisation.id}")
      expect(organisation.roles).to eq %w[manufacturer seller]
      expect(Dir.children(image_dir)).to eq [ organisation.logo ]
    end

    it "needs a name" do
      post "/organisations", params: { organisation: { name: "", roles: [ "owner" ] } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Name can")
    end

    it "rejects unknown roles" do
      post "/organisations", params: { organisation: { name: "X", roles: [ "king" ] } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("unknown roles: king")
    end

    it "rejects logos that are no images" do
      post "/organisations", params: { organisation: { name: "Fake", logo: upload("<?php", name: "x.png") } }

      expect(response.body).to include("must be a PNG, JPEG, GIF or WebP image")
      expect(Organisation.find_by(name: "Fake")).to be_nil
    end

    it "replaces and removes the logo" do
      organisation = Organisation.create!(name: "Org")
      patch "/organisations/#{organisation.id}", params: { organisation: { name: "Org", logo: upload(png) } }
      first = organisation.reload.logo

      patch "/organisations/#{organisation.id}", params: { organisation: { name: "Org", logo: upload(png) } }
      expect(Dir.children(image_dir)).to eq [ organisation.reload.logo ]
      expect(organisation.logo).not_to eq first

      patch "/organisations/#{organisation.id}", params: { organisation: { name: "Org" }, remove_image: "1" }
      expect(organisation.reload.logo).to be_nil
      expect(Dir.children(image_dir)).to be_empty
    end

    it "updates the roles" do
      organisation = Organisation.create!(name: "Org", roles: [ "seller" ])

      patch "/organisations/#{organisation.id}", params: { organisation: { roles: [ "", "owner", "vendor" ] } }

      expect(organisation.reload.roles).to eq %w[owner vendor]
    end

    it "flags organisations as deleted instead of deleting them" do
      organisation = Organisation.create!(name: "Org")

      delete "/organisations/#{organisation.id}"

      expect(organisation.reload.deleted).to be true
      expect(response).to redirect_to("/organisations")
    end
  end

  describe "pages" do
    let!(:maker) { Organisation.create!(name: "Maker GmbH", roles: [ "manufacturer" ]) }
    let!(:shop) { Organisation.create!(name: "Shop AG", roles: %w[seller vendor]) }
    let!(:gone) { Organisation.create!(name: "Gone", roles: [ "seller" ], deleted: true) }

    it "lists organisations without deleted ones" do
      get "/organisations"

      expect(response.body).to include("Maker GmbH", "Shop AG")
      expect(response.body).not_to include("Gone")
    end

    it "filters by role" do
      get "/organisations", params: { role: "seller" }

      expect(response.body).to include("Shop AG")
      expect(response.body).not_to include("Maker GmbH")
    end

    it "ignores unknown roles in the filter" do
      get "/organisations", params: { role: "king" }

      expect(response.body).to include("Maker GmbH", "Shop AG")
    end

    it "shows the roles of an organisation" do
      get "/organisations/#{shop.id}"

      expect(response.body).to include("seller", "vendor")
    end

    it "serves the logo" do
      post "/organisations", params: { organisation: { name: "Logo", logo: upload(png) } }
      organisation = Organisation.find_by!(name: "Logo")

      get "/organisations/#{organisation.id}/image"

      expect(response.media_type).to eq "image/png"
      expect(response.body.b).to eq png
    end
  end

  describe "API" do
    let!(:shop) { Organisation.create!(name: "Shop AG", legal_name: "Shop Aktiengesellschaft", roles: %w[seller vendor], url: "https://shop.example") }

    before { Organisation.create!(name: "Maker", roles: [ "manufacturer" ]) }

    it "serves an organisation as schema.org Organization" do
      get "/api/v1/organisations/#{shop.id}"

      expect(response.media_type).to eq "application/ld+json"
      expect(json).to include("@type" => "Organization", "name" => "Shop AG", "legalName" => "Shop Aktiengesellschaft",
                              "url" => "https://shop.example", "wink:roles" => %w[seller vendor])
    end

    it "lists organisations, filtered by role" do
      get "/api/v1/organisations", params: { role: "manufacturer" }

      expect(json["itemListElement"].pluck("item").pluck("name")).to eq [ "Maker" ]
    end
  end

  describe "create from URL" do
    let(:url) { "https://www.auer-packaging.com/de/" }
    let(:json_ld) do
      [ { "@type" => "WebSite", "name" => "AUER" },
        { "@context" => "https://schema.org", "@type" => "Organization", "name" => "AUER Packaging",
          "legalName" => "AUER Packaging GmbH", "url" => "https://www.auer-packaging.com/",
          "email" => "mailto:info@auer-packaging.com", "telephone" => "+49 89 123",
          "logo" => { "@type" => "ImageObject", "url" => "/logo.png" },
          "address" => { "@type" => "PostalAddress", "streetAddress" => "Am Gewerbering 1",
                         "postalCode" => "85609", "addressLocality" => "Aschheim", "addressCountry" => "DE" } } ]
    end
    let(:html) { %(<html><head><script type="application/ld+json">#{json_ld.to_json}</script></head></html>) }

    before do
      allow(SafeFetch).to receive(:get) do |requested, **|
        if requested.end_with?(".png")
          SafeFetch::Response.new(png.b, "image/png", requested)
        else
          SafeFetch::Response.new(html, "text/html; charset=utf-8", requested)
        end
      end
    end

    it "has an input field on the list" do
      get "/organisations"

      expect(response.body).to include("create_organisation_from_url", %(action="/organisations/from_url"))
    end

    it "creates the organisation from schema.org data and downloads the logo" do
      post "/organisations/from_url", params: { url: url }

      organisation = Organisation.find_by!(name: "AUER Packaging")
      expect(response).to redirect_to("/organisations/#{organisation.id}/edit")
      expect(organisation).to have_attributes(legal_name: "AUER Packaging GmbH", url: "https://www.auer-packaging.com/",
                                              email: "info@auer-packaging.com", telephone: "+49 89 123",
                                              address: "Am Gewerbering 1, 85609 Aschheim, DE")
      expect(Dir.children(image_dir)).to eq [ organisation.logo ]
      expect(organisation.meta["source_url"]).to eq url
    end

    it "does not import an organisation twice" do
      post "/organisations/from_url", params: { url: url }
      post "/organisations/from_url", params: { url: url }

      expect(Organisation.where(name: "AUER Packaging").count).to eq 1
      expect(flash[:notice]).to include("already exists")
    end

    it "falls back to the Open Graph site name" do
      allow(SafeFetch).to receive(:get).and_return(
        SafeFetch::Response.new(%(<html><head><meta property="og:site_name" content="Fallback GmbH"></head></html>), "text/html", url)
      )

      post "/organisations/from_url", params: { url: url }

      expect(Organisation.find_by(name: "Fallback GmbH")).to be_present
    end

    it "reports pages without data and blocked URLs" do
      allow(SafeFetch).to receive(:get).and_return(SafeFetch::Response.new("<html></html>", "text/html", url))
      post "/organisations/from_url", params: { url: url }
      expect(flash[:alert]).to include("Import failed")

      allow(SafeFetch).to receive(:get).and_call_original
      post "/organisations/from_url", params: { url: "http://127.0.0.1/" }
      expect(flash[:alert]).to include("not a public address")
    end
  end
end
