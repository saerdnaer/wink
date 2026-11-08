# frozen_string_literal: true

# JSON-LD representation of a catalog Product (schema.org/ProductModel).
class ProductSerializer
  def self.call(product, urls:)
    JsonLd.compact(
      "@type" => "ProductModel",
      "@id" => urls.product_url(product),
      "name" => product.name,
      "description" => product.description,
      "manufacturer" => product.manufacturer.presence && { "@type" => "Organization", "name" => product.manufacturer },
      "model" => product.model,
      "mpn" => product.product_number,
      "gtin" => product.gtin&.to_s,
      "identifier" => identifiers(product),
      "image" => (urls.image_product_url(product) if product.image.present?),
      "url" => product.product_link.presence || product.url.presence,
      "sameAs" => ([ product.wiki_url ] + Array(product.alternate_urls)).compact_blank,
      "wink:id" => product.id,
      "wink:vocClass" => product.voc_class,
      "wink:purchasePrice" => JsonLd.number(product.price),
      "wink:insuranceValue" => JsonLd.number(product.insurance_value),
      "wink:meta" => product.meta
    )
  end

  def self.identifiers(product)
    ids = Array(product.alternate_ids).map { |id| { "@type" => "PropertyValue", "value" => id } }
    ids << { "@type" => "PropertyValue", "propertyID" => "ASIN", "value" => product.asin } if product.asin.present?
    ids
  end

  private_class_method :identifiers
end
