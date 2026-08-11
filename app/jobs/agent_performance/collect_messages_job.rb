class AgentPerformance::CollectMessagesJob < ApplicationJob
  queue_as :analytics

  def perform(account_id = nil)
    accounts(account_id).find_each do |account|
      next unless account.feature_enabled?('agent_performance_analytics')

      collect_until_caught_up(account)
    rescue StandardError => e
      ChatwootExceptionTracker.new(e, account: account).capture_exception
    end
  end

  private

  def accounts(account_id)
    scope = Account.active
    account_id.present? ? scope.where(id: account_id) : scope
  end

  def collect_until_caught_up(account)
    loop do
      processed = AgentPerformance::MessageCollector.new(account: account).perform
      break if processed < AgentPerformance::MessageCollector::DEFAULT_BATCH_SIZE
    end
  end
end
