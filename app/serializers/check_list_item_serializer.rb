# frozen_string_literal: true

# A check list entry as schema.org/ListItem.
class CheckListItemSerializer
  def self.call(check_list_item, urls:)
    item = check_list_item.item

    JsonLd.compact(
      "@type" => "ListItem",
      "item" => item && { "@type" => "Item", "@id" => urls.item_url(item), "name" => item.name,
                          "assetId" => item.inventory_number, "serialNumber" => item.serial_number },
      "description" => check_list_item.comment,
      "wink:checked" => check_list_item.checked,
      "wink:broken" => check_list_item.broken,
      "wink:missing" => check_list_item.missing
    )
  end
end
