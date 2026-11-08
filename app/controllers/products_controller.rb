# frozen_string_literal: true

class ProductsController < ApplicationController
  include ImageUpload

  before_action :find_product, except: %i[index create new from_url]

  def index
    respond_to do |format|
      format.html do
        @products = Product.existing.order(:name)
      end

      format.json do
        render json: Product.existing
      end
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: @product.to_json }
    end
  end

  def new
    @product = Product.new
  end

  def edit; end

  # POST /products/from_url: creates a product from the schema.org metadata of a
  # product page and opens it for review.
  def from_url
    result = ProductImporter.call(params[:url].to_s)

    existing = find_existing(result)
    return redirect_to(product_path(existing), notice: "This product already exists.") if existing

    product = Product.new(result.attributes.merge(meta: { "source_url" => result.source_url,
                                                          "imported_at" => Time.current.iso8601 }))
    unless product.save
      return redirect_to(products_path, alert: "Could not create the product: #{product.errors.full_messages.to_sentence}")
    end

    image_note = import_image(product, result.image_url)
    redirect_to edit_product_path(product),
                notice: "Imported '#{product.name}' from #{URI.parse(result.source_url).host}. #{image_note} Please check the data."
  rescue SafeFetch::Error, ProductImporter::Error => e
    redirect_to products_path, alert: "Import failed: #{e.message}"
  end

  def create
    @product = Product.new(product_params)

    if save_with_image(@product, store: ProductImageStore, attribute: :image)
      redirect_to product_path(@product), notice: "Created product #{@product.name}"
    else
      render action: "new", status: :unprocessable_content
    end
  end

  def update
    @product.assign_attributes(product_params)

    if save_with_image(@product, store: ProductImageStore, attribute: :image)
      redirect_to product_path(@product), notice: "Updated '#{@product.name}'"
    else
      render action: "edit", status: :unprocessable_content
    end
  end

  # Products are only flagged as deleted, like items.
  def destroy
    if @product.update(deleted: true)
      redirect_to products_path, notice: "Deleted '#{@product.name}'"
    else
      render action: "edit", status: :unprocessable_content
    end
  end

  # GET /products/:id/image
  def image
    send_stored_image(ProductImageStore, @product.image)
  end

  private

  def find_product
    @product = Product.unscoped.find(params[:id])
  end

  def product_params
    params.expect(product: %i[name description manufacturer model product_number gtin asin
                              price insurance_value product_link url web_url voc_class])
  end

  def find_existing(result)
    gtin = result.attributes[:gtin]
    link = result.attributes[:product_link]

    (Product.existing.find_by(gtin: gtin) if gtin) || (Product.existing.find_by(product_link: link) if link)
  end

  # Downloads the product image of the page, returns a sentence for the flash message.
  def import_image(product, image_url)
    return "The page has no image." if image_url.blank?

    page = SafeFetch.get(image_url, max_bytes: ProductImageStore::MAX_SIZE)
    file = StringIO.new(page.body)
    error = ProductImageStore.check(file)
    return "The image was not used (#{error})." if error

    product.update!(image: ProductImageStore.store(file))
    "The image was downloaded."
  rescue SafeFetch::Error => e
    "The image could not be downloaded (#{e.message})."
  end
end
