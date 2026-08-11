class AgentPerformance::HourlyRollup < ApplicationRecord
  self.table_name = 'agent_performance_hourly_rollups'

  belongs_to :account
  belongs_to :user

  validates :hour, :calculated_at, presence: true
  validates :user_id, uniqueness: { scope: [:account_id, :hour] }
end
