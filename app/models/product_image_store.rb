# frozen_string_literal: true

# Stores product images on disk (storage/product_images) and keeps only the file
# name in products.image. The file type is detected from the content, never from
# the name or content type the browser sends.
class ProductImageStore
  MAX_SIZE = 5.megabytes

  TYPES = {
    "png" => "image/png",
    "jpg" => "image/jpeg",
    "gif" => "image/gif",
    "webp" => "image/webp"
  }.freeze

  def self.root
    Rails.root.join("storage/product_images")
  end

  # Absolute path of a stored file; only the base name is used, so a stored value
  # can never point outside of the image directory.
  def self.path(filename)
    root.join(File.basename(filename.to_s))
  end

  def self.exist?(filename)
    filename.present? && File.file?(path(filename))
  end

  def self.content_type(filename)
    TYPES[File.extname(filename.to_s).delete(".")]
  end

  # Returns an error message for an unusable upload, nil if it is fine.
  def self.check(upload)
    return "is not a file" unless upload.respond_to?(:read) && upload.respond_to?(:size)
    return "is too large (maximum #{MAX_SIZE / 1.megabyte} MB)" if upload.size > MAX_SIZE
    return "must be a PNG, JPEG, GIF or WebP image" unless detect_extension(upload)

    nil
  end

  # Saves the upload and returns the generated file name.
  def self.store(upload)
    extension = detect_extension(upload)
    filename = "#{SecureRandom.hex(12)}.#{extension}"

    FileUtils.mkdir_p(root)
    upload.rewind
    File.binwrite(path(filename), upload.read)
    filename
  end

  def self.delete(filename)
    return if filename.blank?

    FileUtils.rm_f(path(filename))
  end

  def self.detect_extension(upload)
    upload.rewind
    head = upload.read(12).to_s.b
    upload.rewind

    if head.start_with?("\x89PNG\r\n\x1A\n".b) then "png"
    elsif head.start_with?("\xFF\xD8\xFF".b) then "jpg"
    elsif head.start_with?("GIF87a".b, "GIF89a".b) then "gif"
    elsif head.start_with?("RIFF".b) && head[8, 4] == "WEBP".b then "webp"
    end
  end
  private_class_method :detect_extension
end
