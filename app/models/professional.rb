class Professional < ApplicationRecord
  belongs_to :account
  has_many :professional_schedules, dependent: :destroy
  has_many :professional_blocked_dates, dependent: :destroy
  has_many :professional_breaks, dependent: :destroy
  has_many :branch_professionals, dependent: :destroy
  has_many :branches, through: :branch_professionals
  has_many :appointments, dependent: :nullify

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:name) }

  def agent_record
    return nil unless agent_id
    User.find_by(id: agent_id)
  end

  def thumbnail
    agent_record&.avatar_url || photo
  end

  def as_json(options = {})
    agent = agent_record
    super(options).merge(
      schedules: professional_schedules.order(:day_of_week),
      thumbnail: thumbnail,
      agent_id: agent_id,
      branch_ids: branch_professionals.pluck(:branch_id),
    )
  end
end
