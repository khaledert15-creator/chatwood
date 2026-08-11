class AgentPerformance::CaptureAssignmentEventJob < ApplicationJob
  queue_as :analytics

  def perform(account_id, conversation_id, previous_assignee_id, current_assignee_id, occurred_at, source_event_id) # rubocop:disable Metrics/ParameterLists
    account = Account.find(account_id)
    return unless account.feature_enabled?('agent_performance_analytics')

    AgentPerformance::AssignmentEventProcessor.new(
      account: account,
      conversation_id: conversation_id,
      previous_assignee_id: previous_assignee_id,
      current_assignee_id: current_assignee_id,
      occurred_at: occurred_at,
      source_event_id: source_event_id
    ).perform
  end
end
