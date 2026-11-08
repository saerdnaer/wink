# frozen_string_literal: true

# Helpers for the JSON-LD output of the REST API.
#
# Resources use schema.org terms wherever a fitting one exists. Everything that is
# specific to WINK (kits, locations, broken/missing flags, ...) lives in the
# `wink:` namespace so that the documents stay valid JSON-LD.
module JsonLd
  CONTENT_TYPE = "application/ld+json"

  CONTEXT = [
    "https://schema.org/",
    {
      "wink" => "https://c3voc.de/wink/ns#",
      "wink:meta" => { "@id" => "wink:meta", "@type" => "@json" }
    }
  ].freeze

  # Adds the @context as the last key of the document.
  def self.with_context(document)
    document.merge("@context" => CONTEXT)
  end

  # Drops nil and empty values (but keeps false and 0).
  def self.compact(value)
    case value
    when Hash
      value.transform_values { |v| compact(v) }.reject { |_k, v| blank_value?(v) }
    when Array
      value.map { |v| compact(v) }.reject { |v| blank_value?(v) }
    else
      value
    end
  end

  def self.blank_value?(value)
    value.nil? || (value.respond_to?(:empty?) && value.empty?)
  end

  def self.number(decimal)
    decimal&.to_f
  end

  def self.time(value)
    value&.iso8601
  end

  def self.node(id, type = nil, **properties)
    { "@id" => id, "@type" => type }.merge(properties.transform_keys(&:to_s))
  end
end
