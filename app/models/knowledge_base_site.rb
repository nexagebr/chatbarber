class KnowledgeBaseSite < ApplicationRecord
  belongs_to :knowledge_base
  validates :url, presence: true
end
