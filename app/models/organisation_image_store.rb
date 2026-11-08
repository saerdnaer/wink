# frozen_string_literal: true

# Organisation logos: storage/organisation_images, file name in organisations.logo
class OrganisationImageStore < ImageStore
  def self.root
    Rails.root.join("storage/organisation_images")
  end
end
