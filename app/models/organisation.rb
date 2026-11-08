# frozen_string_literal: true

# A company or other organisation. The same organisation can play several roles,
# e.g. be the manufacturer of a product and the seller of another one.
class Organisation < ApplicationRecord
  ROLES = %w[seller vendor manufacturer owner].freeze

  belongs_to :parent, class_name: "Organisation", optional: true, inverse_of: :children
  has_many :children, class_name: "Organisation", foreign_key: :parent_id, inverse_of: :parent,
                      dependent: :nullify

  before_validation :normalize_roles

  validates :name, presence: true
  validate :roles_are_known
  validate :parent_is_not_self_or_descendant

  scope :existing, -> { where(deleted: false) }
  scope :deleted, -> { where(deleted: true) }
  # PostgreSQL array column
  scope :with_role, ->(role) { where("? = ANY (organisations.roles)", role) }

  def deleted?
    self[:deleted]
  end

  # All organisations below this one (children, their children, ...)
  def descendants
    found = []
    queue = children.existing.to_a
    while (current = queue.shift)
      next if found.include?(current)

      found << current
      queue.concat(current.children.existing.to_a)
    end
    found
  end

  # Organisations that may become the parent of this one: not itself or one of its descendants.
  def possible_parents
    excluded = [ id, *descendants.map(&:id) ].compact
    Organisation.existing.where.not(id: excluded).order(:name)
  end

  private

  def parent_is_not_self_or_descendant
    return if parent_id.blank? || new_record?

    errors.add(:parent, "cannot be the organisation itself or one of its sub-organisations") if
      parent_id == id || descendants.any? { |descendant| descendant.id == parent_id }
  end

  def normalize_roles
    self.roles = Array(roles).map(&:to_s).compact_blank.uniq
  end

  def roles_are_known
    unknown = roles - ROLES
    errors.add(:roles, "contain unknown roles: #{unknown.join(', ')}") if unknown.any?
  end
end
