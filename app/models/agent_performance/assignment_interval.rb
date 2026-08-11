class AgentPerformance::AssignmentInterval < ApplicationRecord
  self.table_name = 'agent_assignment_intervals'

  belongs_to :account
  belongs_to :conversation
  belongs_to :user

  validates :started_at, :source_event_id, presence: true
  validates :source_event_id, uniqueness: true
  validates :end_source_event_id, uniqueness: true, allow_nil: true
  validate :ended_at_follows_started_at

  scope :covering, ->(timestamp) { where('started_at <= ? AND (ended_at IS NULL OR ended_at >= ?)', timestamp, timestamp) }

  private

  def ended_at_follows_started_at
    return if ended_at.blank? || started_at.blank? || ended_at >= started_at

    errors.add(:ended_at, 'must be after started_at')
  end
end
