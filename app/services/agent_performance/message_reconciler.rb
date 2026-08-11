class AgentPerformance::MessageReconciler
  WINDOW = 72.hours

  def initialize(account:, since: WINDOW.ago)
    @account = account
    @since = since
  end

  def perform
    return unless account.feature_enabled?('agent_performance_analytics')

    account.messages.unscope(:order).where(created_at: since..).find_each do |message|
      AgentPerformance::MessageFactProjector.call(message)
      AgentPerformance::ResponseSampleProjector.call(message)
    end

    AgentPerformance::AnalyticsCursor.find_or_create_by!(account: account, collector: AgentPerformance::MessageCollector::COLLECTOR_NAME)
                                     .update!(last_reconciled_at: Time.current)
  end

  private

  attr_reader :account, :since
end
