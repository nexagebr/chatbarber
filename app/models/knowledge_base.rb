class KnowledgeBase < ApplicationRecord
  belongs_to :account
  has_many :faqs, class_name: 'KnowledgeBaseFaq', dependent: :destroy
  has_many :sites, class_name: 'KnowledgeBaseSite', dependent: :destroy
  has_many :files, class_name: 'KnowledgeBaseFile', dependent: :destroy
  has_many :knowledge_base_inboxes, dependent: :destroy
  has_many :inboxes, through: :knowledge_base_inboxes
  validates :name, presence: true
end
