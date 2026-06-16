class InboxKnowledgeItem < ApplicationRecord
  belongs_to :account
  belongs_to :inbox, optional: true

  validates :question, presence: true
  validates :answer, presence: true

  scope :for_inbox, ->(inbox_id) { inbox_id.present? ? where(inbox_id: inbox_id) : all }
  scope :ordered, -> { order(:position, :created_at) }
  scope :search, lambda { |q|
    where('question ILIKE :q OR answer ILIKE :q OR category ILIKE :q', q: "%#{q}%")
  }
end
