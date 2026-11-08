# frozen_string_literal: true

# A company or other organisation. The same organisation can play several roles,
# e.g. be the manufacturer of a product and the seller of another one.
class Organisation < ApplicationRecord
  ROLES = %w[seller vendor manufacturer owner].freeze

  before_validation :normalize_roles

  validates :name, presence: true
  validate :roles_are_known

  scope :existing, -> { where(deleted: false) }
  scope :deleted, -> { where(deleted: true) }
  # PostgreSQL array column
  scope :with_role, ->(role) { where("? = ANY (organisations.roles)", role) }

  def deleted?
    self[:deleted]
  end

  private

  def normalize_roles
    self.roles = Array(roles).map(&:to_s).compact_blank.uniq
  end

  def roles_are_known
    unknown = roles - ROLES
    errors.add(:roles, "contain unknown roles: #{unknown.join(', ')}") if unknown.any?
  end
end
