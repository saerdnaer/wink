# frozen_string_literal: true

# Helpers to read schema.org metadata (JSON-LD, microdata, Open Graph) from an
# HTML page. Used by ProductImporter and OrganisationImporter.
module SchemaOrg
  module_function

  def parse(html, charset = nil)
    Nokogiri::HTML(html, nil, charset)
  end

  def charset(content_type)
    content_type.to_s[/charset=([\w-]+)/i, 1]
  end

  # All JSON-LD nodes of the page as a flat list of hashes (arrays, @graph and
  # variants are flattened).
  def json_ld_nodes(doc)
    doc.css('script[type="application/ld+json"]').flat_map do |script|
      flatten_nodes(JSON.parse(script.text.strip))
    rescue JSON::ParserError
      []
    end
  end

  def flatten_nodes(data)
    case data
    when Array then data.flat_map { |entry| flatten_nodes(entry) }
    when Hash then [ data ] + flatten_nodes(data["@graph"] || []) + flatten_nodes(data["hasVariant"] || [])
    else []
    end
  end

  # Microdata items whose itemtype matches (e.g. "Product"), as hashes of itemprop => value.
  def microdata_nodes(doc, type)
    doc.css("[itemscope][itemtype*='schema.org/#{type}']").map do |scope|
      props = scope.css("[itemprop]").each_with_object({}) do |element, hash|
        next unless element.ancestors("[itemscope]").first == scope || element["itemprop"] == "price"

        hash[element["itemprop"]] ||= element["content"].presence || element["href"] || element["src"] || element.text.strip
      end
      props.merge("@type" => type)
    end
  end

  def open_graph(doc)
    meta = ->(property) { doc.at_css(%(meta[property="#{property}"]))&.[]("content") }
    {
      "name" => meta.call("og:site_name").presence || meta.call("og:title").presence || doc.at_css("title")&.text.to_s.strip,
      "description" => meta.call("og:description"),
      "image" => meta.call("og:image"),
      "url" => meta.call("og:url")
    }
  end

  def types(node)
    list(node["@type"]).map { |type| type.to_s.split("/").last }
  end

  # Array() would turn a Hash into pairs
  def list(value)
    value.is_a?(Array) ? value : [ value ].compact
  end

  # A schema.org value may be a string, a number, a hash (Thing/Organization/...) or a list.
  def text(value)
    value = value.first if value.is_a?(Array)
    value = value["name"] || value["@value"] || value["value"] if value.is_a?(Hash)
    value.to_s.strip
  end

  # Text without HTML tags and with collapsed white space.
  def plain_text(value)
    html = text(value)
    return nil if html.blank?

    Nokogiri::HTML.fragment(html.gsub(%r{<br\s*/?>|\r?\n}i, " ")).text.gsub(/[[:space:]]+/, " ").strip
  end

  # Makes a (possibly relative) URL absolute; "" when it is not a usable http(s) URL.
  def absolute(url, base)
    return "" if url.blank?

    SafeFetch.parse(URI.join(base, url).to_s).to_s
  rescue SafeFetch::Error, URI::Error
    ""
  end

  # url of a node value that is a string or an ImageObject
  def image_url(value, base)
    image = list(value).first
    image = image["url"] || image["contentUrl"] if image.is_a?(Hash)
    absolute(image.to_s.strip, base).presence
  end
end
