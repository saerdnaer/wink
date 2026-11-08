# frozen_string_literal: true

# A check list as schema.org/ItemList.
class CheckListSerializer
  def self.call(check_list, urls:, detail: false)
    kase = check_list.case
    event = check_list.event

    json = {
      "@type" => "ItemList",
      "@id" => urls.check_list_url(check_list),
      "name" => [ "Check list", kase&.acronym, event&.name ].compact.join(" "),
      "description" => check_list.comment,
      "wink:id" => check_list.id,
      "wink:advisor" => check_list.advisor,
      "wink:checked" => check_list.checked,
      "wink:kit" => kase && { "@id" => urls.case_url(kase), "name" => kase.name, "alternateName" => kase.acronym },
      "wink:event" => event && { "@type" => "Event", "name" => event.name, "startDate" => event.start_date&.iso8601,
                                 "endDate" => event.end_date&.iso8601, "location" => event.location }
    }
    if detail
      entries = check_list.check_list_items.each_with_index.map do |cli, index|
        CheckListItemSerializer.call(cli, urls: urls).merge("position" => index + 1)
      end
      json["numberOfItems"] = entries.size
      json["itemListElement"] = entries
    end

    JsonLd.compact(json)
  end
end
