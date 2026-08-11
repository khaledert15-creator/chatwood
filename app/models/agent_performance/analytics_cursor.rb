class AgentPerformance::AnalyticsCursor < ApplicationRecord
  self.table_name = 'agent_analytics_cursors'

  belongs_to :account

  validates :collector, presence: true, uniqueness: { scope: :account_id }
end
