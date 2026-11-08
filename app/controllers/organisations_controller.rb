# frozen_string_literal: true

class OrganisationsController < ApplicationController
  include ImageUpload

  before_action :find_organisation, except: %i[index create new from_url]

  def index
    @role = params[:role].presence_in(Organisation::ROLES)
    @organisations = Organisation.existing.includes(:parent).order(:name)
    @organisations = @organisations.with_role(@role) if @role

    respond_to do |format|
      format.html
      format.json { render json: @organisations }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: @organisation }
    end
  end

  def new
    @organisation = Organisation.new
  end

  def edit; end

  def create
    @organisation = Organisation.new(organisation_params)

    if save_with_image(@organisation, store: OrganisationImageStore, attribute: :logo)
      redirect_to organisation_path(@organisation), notice: "Created organisation #{@organisation.name}"
    else
      render action: "new", status: :unprocessable_content
    end
  end

  def update
    @organisation.assign_attributes(organisation_params)

    if save_with_image(@organisation, store: OrganisationImageStore, attribute: :logo)
      redirect_to organisation_path(@organisation), notice: "Updated '#{@organisation.name}'"
    else
      render action: "edit", status: :unprocessable_content
    end
  end

  # Organisations are only flagged as deleted, like items and products.
  def destroy
    # the sub-organisations move up one level
    @organisation.children.update_all(parent_id: @organisation.parent_id)

    if @organisation.update(deleted: true)
      redirect_to organisations_path, notice: "Deleted '#{@organisation.name}'"
    else
      render action: "edit", status: :unprocessable_content
    end
  end

  # GET /organisations/:id/image
  def image
    send_stored_image(OrganisationImageStore, @organisation.logo)
  end

  # POST /organisations/from_url: creates an organisation from the schema.org
  # metadata of its web page and opens it for review.
  def from_url
    result = OrganisationImporter.call(params[:url].to_s)

    existing = find_existing(result)
    return redirect_to(organisation_path(existing), notice: "This organisation already exists.") if existing

    meta = { "source_url" => result.source_url, "imported_at" => Time.current.iso8601 }
    organisation = Organisation.new(result.attributes.merge(meta: meta, parent: find_parent(result)))
    unless organisation.save
      return redirect_to(organisations_path,
                         alert: "Could not create the organisation: #{organisation.errors.full_messages.to_sentence}")
    end

    logo_note = import_logo(organisation, result.logo_url)
    redirect_to edit_organisation_path(organisation),
                notice: "Imported '#{organisation.name}' from #{URI.parse(result.source_url).host}. " \
                        "#{logo_note} Please check the data and choose its roles."
  rescue SafeFetch::Error, OrganisationImporter::Error => e
    redirect_to organisations_path, alert: "Import failed: #{e.message}"
  end

  private

  def find_organisation
    @organisation = Organisation.unscoped.find(params[:id])
  end

  def organisation_params
    params.expect(organisation: [ :name, :legal_name, :description, :url, :email, :telephone, :address,
                                  :parent_id, { roles: [] } ])
  end

  def find_existing(result)
    url = result.attributes[:url]
    name = result.attributes[:name]

    (Organisation.existing.find_by(url: url) if url) ||
      Organisation.existing.find_by("lower(name) = ?", name.downcase)
  end

  # The parent organisation named in the schema.org data, if we know it already.
  def find_parent(result)
    name = result.parent_name
    Organisation.existing.find_by("lower(name) = ?", name.downcase) if name.present?
  end

  # Downloads the logo of the page, returns a sentence for the flash message.
  def import_logo(organisation, logo_url)
    return "The page has no logo." if logo_url.blank?

    page = SafeFetch.get(logo_url, max_bytes: OrganisationImageStore::MAX_SIZE)
    file = StringIO.new(page.body)
    error = OrganisationImageStore.check(file)
    return "The logo was not used (#{error})." if error

    organisation.update!(logo: OrganisationImageStore.store(file))
    "The logo was downloaded."
  rescue SafeFetch::Error => e
    "The logo could not be downloaded (#{e.message})."
  end
end
