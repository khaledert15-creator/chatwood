class AgentPerformance::TrackingStart
  def self.ensure!(account, timestamp = Time.current)
    return account.agent_performance_tracking_started_at if account.agent_performance_tracking_started_at.present?

    account.update!(agent_performance_tracking_started_at: timestamp.iso8601)
    timestamp
  end
end
