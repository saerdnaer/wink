# frozen_string_literal: true

# JSON-LD representation of an Organisation (schema.org/Organization).
class OrganisationSerializer
  def self.call(organisation, urls:)
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
      "wink:id" => organisation.id,
      "wink:roles" => organisation.roles
    )
  end
end
