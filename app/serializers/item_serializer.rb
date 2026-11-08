# frozen_string_literal: true

# JSON-LD representation of an Item (schema.org/Product) for the REST API.
class ItemSerializer
  DAMAGED = "https://schema.org/DamagedCondition"

  def self.call(item, urls:, detail: false)
    json = {
      "@type" => "Item",
      "@id" => urls.item_url(item),
      "assetId" => item.inventory_number,
      "serialNumber" => item.serial_number,
      "name" => item.name,
      "description" => item.description,
      "manufacturer" => item.manufacturer.presence && { "@type" => "Organization", "name" => item.manufacturer },
      "model" => model(item, urls),
      "category" => item.item_type&.name,
      "purchaseDate" => item.date_of_purchase&.iso8601,
      "condition" => (DAMAGED if item.broken),
      "seller" => item.seller,
      "wink:kit" => item.case && case_node(item.case, urls),
      "wink:parent" => item.item && { "@id" => urls.item_url(item.item) },
      "wink:location" => item.location && { "@id" => urls.item_url(item.location), "name" => item.location.name },
      "wink:id" => item.id,
      "wink:broken" => item.broken,
      "wink:missing" => item.missing,
      "wink:reused" => item.reused,
      "wink:hidden" => item.hidden
    }
    json.merge!(detail_properties(item, urls)) if detail

    JsonLd.compact(json)
  end

  def self.model(item, urls)
    return { "@id" => urls.product_url(item.product) } if item.product

    item.model
  end

  def self.case_node(kase, urls)
    { "@id" => urls.case_url(kase), "name" => kase.name, "alternateName" => kase.acronym }
  end

  def self.detail_properties(item, urls)
    {
      "wink:subItems" => item.items.existing.map { |sub| { "@id" => urls.item_url(sub), "name" => sub.name } },
      "wink:comment" => item.item_comments.map { |comment| ItemCommentSerializer.call(comment) }
    }
  end

  private_class_method :model, :case_node, :detail_properties
end
