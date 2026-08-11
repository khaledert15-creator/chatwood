class AgentPerformance::ResponseSample < ApplicationRecord
  self.table_name = 'agent_response_samples'

  EXCLUSION_REASONS = %w[assignment_history_missing unassigned_responder invalid_waiting_episode].freeze

  belongs_to :account
  belongs_to :user
  belongs_to :conversation
  belongs_to :inbox

  validates :source_message_id, presence: true, uniqueness: true
  validates :responded_at, presence: true
  validates :exclusion_reason, inclusion: { in: EXCLUSION_REASONS }, allow_nil: true
  validates :customer_wait_seconds, :accountable_wait_seconds, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :eligible, -> { where(sla_eligible: true) }
end
