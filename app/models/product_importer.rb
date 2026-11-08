# frozen_string_literal: true

# Reads the schema.org metadata (JSON-LD, microdata, Open Graph as fallback) of a
# product page and maps it to attributes of Product.
class ProductImporter
  class Error < StandardError; end

  Result = Struct.new(:attributes, :image_url, :source_url, :schema_org, keyword_init: true)

  PRODUCT_TYPES = %w[Product ProductModel ProductGroup IndividualProduct].freeze
  GTIN_KEYS = %w[gtin gtin14 gtin13 gtin12 gtin8].freeze
  DETAIL_KEYS = %w[offers gtin gtin13 gtin14 mpn sku brand manufacturer image].freeze
  MAX_PAGE_SIZE = 3.megabytes

  def self.call(url)
    page = SafeFetch.get(url, max_bytes: MAX_PAGE_SIZE, accept: "text/html,application/xhtml+xml")
    raise Error, "this is not an HTML page" unless page.content_type.blank? || page.content_type.include?("html")

    from_html(page.body, page.url, SchemaOrg.charset(page.content_type))
  end

  def self.from_html(html, source_url, charset = nil)
    doc = SchemaOrg.parse(html, charset)
    node = product_node(doc)
    used_fallback = node.nil?
    node ||= SchemaOrg.open_graph(doc)
    raise Error, "no schema.org product data found on this page" if node["name"].blank?

    Result.new(attributes: attributes(node, source_url), image_url: SchemaOrg.image_url(node["image"], source_url),
               source_url: source_url, schema_org: (node unless used_fallback))
  end

  def self.product_node(doc)
    candidates = SchemaOrg.json_ld_nodes(doc).select do |node|
      SchemaOrg.types(node).intersect?(PRODUCT_TYPES) && SchemaOrg.text(node["name"]).present?
    end
    candidates = microdata_nodes(doc) if candidates.empty?
    # the most detailed product on the page wins
    candidates.max_by { |node| DETAIL_KEYS.count { |key| node[key].present? } }
  end

  def self.microdata_nodes(doc)
    SchemaOrg.microdata_nodes(doc, "Product").each do |node|
      node["offers"] = { "price" => node["price"] } if node["price"]
    end
  end

  def self.attributes(node, source_url)
    text = SchemaOrg.method(:text)
    {
      name: text.call(node["name"]),
      details: SchemaOrg.plain_text(node["description"]),
      manufacturer: text.call(node["manufacturer"]).presence || text.call(node["brand"]),
      model: text.call(node["model"]),
      product_number: text.call(node["mpn"]).presence || text.call(node["sku"]),
      gtin: gtin(node),
      price: price(node),
      product_link: SchemaOrg.absolute(text.call(node["url"]), source_url).presence || source_url
    }.compact_blank
  end

  def self.gtin(node)
    digits = GTIN_KEYS.filter_map { |key| SchemaOrg.text(node[key]).gsub(/\D/, "").presence }.first
    digits.to_i if digits && (8..14).cover?(digits.length)
  end

  def self.price(node)
    offer = SchemaOrg.list(node["offers"]).first
    offer = offer.is_a?(Hash) ? offer : { "price" => offer }
    raw = offer["price"] || offer["lowPrice"] || offer.dig("priceSpecification", "price")
    normalized = SchemaOrg.text(raw).tr(",", ".").gsub(/[^\d.]/, "")
    BigDecimal(normalized) if normalized.match?(/\A\d+(\.\d+)?\z/)
  end

  private_class_method :product_node, :microdata_nodes, :attributes, :gtin, :price
end
