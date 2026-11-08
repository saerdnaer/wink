# frozen_string_literal: true

# JSON-LD representation of an Organisation (schema.org/Organization).
class OrganisationSerializer
  def self.call(organisation, urls:)
    parent = organisation.parent unless organisation.parent&.deleted?

    JsonLd.compact(
      "@type" => "Organization",
      "@id" => urls.organisation_url(organisation),
      "name" => organisation.name,
      "legalName" => organisation.legal_name,
      "description" => organisation.description,
      "url" => organisation.url,
      "email" => organisation.email,
      "telephone" => organisation.telephone,
      "address" => organisation.address,
      "logo" => (urls.image_organisation_url(organisation) if organisation.logo.present?),
      "parentOrganization" => (node(parent, urls) if parent),
      "subOrganization" => organisation.children.existing.order(:name).map { |child| node(child, urls) },
      "wink:id" => organisation.id,
      "wink:roles" => organisation.roles
    )
  end

  def self.node(organisation, urls)
    { "@id" => urls.organisation_url(organisation), "name" => organisation.name }
  end
  private_class_method :node
end
