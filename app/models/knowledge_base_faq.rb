class KnowledgeBaseFaq < ApplicationRecord
  belongs_to :knowledge_base
  validates :question, :answer, presence: true
  scope :ordered, -> { order(:position, :created_at) }
  scope :search, ->(q) { where('question ILIKE :q OR answer ILIKE :q OR category ILIKE :q', q: "%#{q}%") }
end
