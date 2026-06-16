# frozen_string_literal: true

class ScheduledMessage < ApplicationRecord
  belongs_to :account
  belongs_to :conversation

  enum :status, { pending: 0, sent: 1, cancelled: 2, failed: 3 }, prefix: false, default: :pending

  validates :content, presence: true, unless: :has_attachments?
  validates :scheduled_at, presence: true
  validate :scheduled_at_must_be_future, on: :create

  scope :due, -> { pending.where('scheduled_at <= ?', Time.current) }

  store_accessor :template_params, :is_private, :signed_ids

  def is_private?
    is_private == true || is_private == 'true'
  end

  def parsed_signed_ids
    return [] if signed_ids.blank?

    Array(signed_ids).map(&:to_s).reject(&:blank?)
  end

  private

  def has_attachments?
    parsed_signed_ids.any?
  end

  def scheduled_at_must_be_future
    return unless scheduled_at.present?

    errors.add(:scheduled_at, 'deve ser no futuro') if scheduled_at <= Time.current
  end
end
