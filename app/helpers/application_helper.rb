# frozen_string_literal: true

module ApplicationHelper

  # The manufacturer of a product: a link to its organisation if there is one with
  # that name, otherwise the plain text. `organisations` is Product.organisations_by_name.
  def manufacturer_link(product, organisations = nil)
    return if product.manufacturer.blank?

    organisation = if organisations
                     organisations[Product.normalize_manufacturer(product.manufacturer)]
                   else
                     product.manufacturer_organisation
                   end
    organisation ? link_to(product.manufacturer, organisation_path(organisation)) : product.manufacturer
  end
end
