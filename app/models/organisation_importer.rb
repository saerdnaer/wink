# frozen_string_literal: true

# Reads the schema.org metadata (JSON-LD, microdata, Open Graph as fallback) of a
# web page of an organisation and maps it to attributes of Organisation.
class OrganisationImporter
  class Error < StandardError; end

  Result = Struct.new(:attributes, :logo_url, :source_url, :parent_name, keyword_init: true)

  TYPE_PATTERN = /(Organization|Corporation|Business|Store|NGO|Company)\z/
  DETAIL_KEYS = %w[legalName description email telephone address logo url sameAs].freeze
  MAX_PAGE_SIZE = 3.megabytes

  def self.call(url)
    page = SafeFetch.get(url, max_bytes: MAX_PAGE_SIZE, accept: "text/html,application/xhtml+xml")
    raise Error, "this is not an HTML page" unless page.content_type.blank? || page.content_type.include?("html")

    from_html(page.body, page.url, SchemaOrg.charset(page.content_type))
  end

  def self.from_html(html, source_url, charset = nil)
    doc = SchemaOrg.parse(html, charset)
    node = organisation_node(doc) || SchemaOrg.open_graph(doc)
    name = SchemaOrg.text(node["name"]).presence || SchemaOrg.text(node["legalName"])
    raise Error, "no schema.org organisation data found on this page" if name.blank?

    Result.new(attributes: attributes(node, name, source_url),
               logo_url: SchemaOrg.image_url(node["logo"] || node["image"], source_url), source_url: source_url,
               parent_name: SchemaOrg.text(node["parentOrganization"]).presence)
  end

  def self.organisation_node(doc)
    candidates = SchemaOrg.json_ld_nodes(doc).select do |node|
      SchemaOrg.types(node).any? { |type| type.match?(TYPE_PATTERN) } &&
        (SchemaOrg.text(node["name"]).present? || SchemaOrg.text(node["legalName"]).present?)
    end
    candidates = SchemaOrg.microdata_nodes(doc, "Organization") if candidates.empty?
    candidates.max_by { |node| DETAIL_KEYS.count { |key| node[key].present? } }
  end

  def self.attributes(node, name, source_url)
    {
      name: name,
      legal_name: SchemaOrg.text(node["legalName"]).presence,
      description: SchemaOrg.plain_text(node["description"]),
      url: SchemaOrg.absolute(SchemaOrg.text(node["url"]), source_url).presence || source_url,
      email: SchemaOrg.text(node["email"]).delete_prefix("mailto:").presence,
      telephone: SchemaOrg.text(node["telephone"]).delete_prefix("tel:").presence,
      address: address(node["address"])
    }.compact_blank
  end

  # PostalAddress (or plain text) as one text
  def self.address(value)
    value = SchemaOrg.list(value).first
    return SchemaOrg.text(value).presence unless value.is_a?(Hash)

    street = value["streetAddress"]
    city = [ value["postalCode"], value["addressLocality"] ].compact_blank.join(" ")
    country = SchemaOrg.text(value["addressCountry"])
    [ street, city, country ].map { |part| part.to_s.strip }.compact_blank.join(", ").presence
  end

  private_class_method :organisation_node, :attributes, :address
end
