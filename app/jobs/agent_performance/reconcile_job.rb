class AgentPerformance::ReconcileJob < ApplicationJob
  queue_as :analytics

  def perform(account_id = nil)
    accounts(account_id).find_each do |account|
      next unless account.feature_enabled?('agent_performance_analytics')

      AgentPerformance::MessageReconciler.new(account: account).perform
    rescue StandardError => e
      ChatwootExceptionTracker.new(e, account: account).capture_exception
    end
  end

  private

  def accounts(account_id)
    scope = Account.active
    account_id.present? ? scope.where(id: account_id) : scope
  end
end
