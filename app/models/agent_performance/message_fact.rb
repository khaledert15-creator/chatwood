class AgentPerformance::MessageFact < ApplicationRecord
  self.table_name = 'agent_message_facts'

  MESSAGE_KINDS = %w[manual manual_template].freeze

  belongs_to :account
  belongs_to :user
  belongs_to :conversation
  belongs_to :inbox
  belongs_to :contact, optional: true

  validates :source_message_id, presence: true, uniqueness: true
  validates :message_kind, inclusion: { in: MESSAGE_KINDS }
  validates :sent_at, presence: true
end
