class AgentPerformance::DailyRollup < ApplicationRecord
  self.table_name = 'agent_performance_daily_rollups'

  belongs_to :account
  belongs_to :user

  validates :date, :calculated_at, presence: true
  validates :user_id, uniqueness: { scope: [:account_id, :date] }
end
