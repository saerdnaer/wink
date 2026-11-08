# frozen_string_literal: true

# Product images: storage/product_images, file name in products.image
class ProductImageStore < ImageStore
  def self.root
    Rails.root.join("storage/product_images")
  end
end
