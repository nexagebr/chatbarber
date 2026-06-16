class KnowledgeBaseInbox < ApplicationRecord
  belongs_to :knowledge_base
  belongs_to :inbox
end
