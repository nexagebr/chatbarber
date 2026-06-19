class Appointment < ApplicationRecord
  belongs_to :account
  belongs_to :professional, optional: true
  belongs_to :contact, optional: true
  belongs_to :conversation, optional: true
  belongs_to :branch, optional: true
  has_many :appointment_services, dependent: :destroy
  has_many :services, through: :appointment_services, source: :service
  has_many :products, through: :appointment_services
  has_one :cash_transaction, dependent: :destroy

  enum status: { scheduled: 0, in_progress: 1, completed: 2, cancelled: 3 }, _prefix: false

  scope :in_range, ->(from, to) { where(scheduled_at: from..to) }
  scope :pending_reminder, -> { scheduled.where(reminder_sent_at: nil) }

  before_update :reset_reminder_if_rescheduled

  private

  def reset_reminder_if_rescheduled
    self.reminder_sent_at = nil if scheduled_at_changed?
  end
end
