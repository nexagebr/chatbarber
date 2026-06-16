class KnowledgeBaseFile < ApplicationRecord
  belongs_to :knowledge_base
  validates :original_filename, presence: true
end
