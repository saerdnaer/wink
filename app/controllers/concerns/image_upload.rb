# frozen_string_literal: true

# Image upload for controllers whose record stores an image file name
# (see ImageStore): validation, storing, replacing and removing.
module ImageUpload
  extend ActiveSupport::Concern

  private

  # Validates and stores an uploaded image (params[model][attribute]) or removes the
  # current one (remove_image=1), then saves the record. A rejected save leaves no
  # files behind.
  # rubocop:disable Naming/PredicateMethod
  def save_with_image(record, store:, attribute:)
    upload = params.dig(record.model_name.param_key, attribute).presence
    remove = ActiveModel::Type::Boolean.new.cast(params[:remove_image])
    old_image = record.public_send("#{attribute}_was")

    error = store.check(upload) if upload
    unless record.valid? && error.nil?
      record.errors.add(attribute, error) if error
      return false
    end

    new_image = store.store(upload) if upload
    record[attribute] = new_image if new_image
    record[attribute] = nil if remove && !new_image

    if record.save
      store.delete(old_image) if old_image.present? && old_image != record[attribute]
      true
    else
      store.delete(new_image)
      false
    end
  end

  # rubocop:enable Naming/PredicateMethod

  # Sends a stored image, 404 if there is none.
  def send_stored_image(store, filename)
    return head :not_found unless store.exist?(filename)

    expires_in 1.hour, public: true
    send_file store.path(filename), type: store.content_type(filename) || "application/octet-stream",
                                    disposition: "inline"
  end
end
