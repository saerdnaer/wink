# frozen_string_literal: true

class ProductsController < ApplicationController
  before_action :find_product, except: %i[index create new]

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

  def create
    @product = Product.new(product_params)

    if save_with_image(@product)
      redirect_to product_path(@product), notice: "Created product #{@product.name}"
    else
      render action: "new", status: :unprocessable_content
    end
  end

  def update
    @product.assign_attributes(product_params)

    if save_with_image(@product)
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
    return head :not_found unless ProductImageStore.exist?(@product.image)

    expires_in 1.hour, public: true
    send_file ProductImageStore.path(@product.image),
              type: ProductImageStore.content_type(@product.image) || "application/octet-stream",
              disposition: "inline"
  end

  private

  def find_product
    @product = Product.unscoped.find(params[:id])
  end

  def product_params
    params.expect(product: %i[name description manufacturer model product_number gtin asin
                              price insurance_value product_link url wiki_url voc_class])
  end

  # Validates and stores an uploaded image (product[image]) or removes the current
  # one (remove_image=1), then saves the product. A rejected save leaves no files behind.
  # rubocop:disable Naming/PredicateMethod
  def save_with_image(product)
    upload = params.dig(:product, :image).presence
    remove = ActiveModel::Type::Boolean.new.cast(params[:remove_image])
    old_image = product.image_was

    error = ProductImageStore.check(upload) if upload
    unless product.valid? && error.nil?
      product.errors.add(:image, error) if error
      return false
    end

    new_image = ProductImageStore.store(upload) if upload
    product.image = new_image if new_image
    product.image = nil if remove && !new_image

    if product.save
      ProductImageStore.delete(old_image) if old_image.present? && old_image != product.image
      true
    else
      ProductImageStore.delete(new_image)
      false
    end
  end
  # rubocop:enable Naming/PredicateMethod
end
