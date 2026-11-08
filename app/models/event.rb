# frozen_string_literal: true

class Event < ApplicationRecord
  has_many :event_cases, dependent: :destroy
  has_many :cases, through: :event_cases
  has_many :check_lists, through: :event_cases

  # Events happening today, including build-up and tear-down time when set.
  scope :running, lambda { |day = Time.zone.today|
    where("COALESCE(events.buildup, events.start_date) <= :day AND COALESCE(events.removel, events.end_date) >= :day",
          day: day)
  }

  validates :name, uniqueness: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :location, presence: true

  def transports
    Transport.where("destination_event_id = #{id} or source_event_id = #{id}")
  end
end
