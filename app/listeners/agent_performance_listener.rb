class AgentPerformanceListener < BaseListener
  def assignee_changed(event)
    conversation = event.data[:conversation]
    return unless conversation.account.feature_enabled?('agent_performance_analytics')

    previous_assignee_id, current_assignee_id = event.data[:changed_attributes].to_h['assignee_id'] ||
                                                event.data[:changed_attributes].to_h[:assignee_id]
    source_event_id = event_id(conversation, event.timestamp, previous_assignee_id, current_assignee_id)

    AgentPerformance::CaptureAssignmentEventJob.perform_later(
      conversation.account_id,
      conversation.id,
      previous_assignee_id,
      current_assignee_id,
      event.timestamp,
      source_event_id
    )
  rescue StandardError => e
    Rails.logger.warn("Agent performance assignment enqueue failed: #{e.class}: #{e.message}")
  end

  private

  def event_id(conversation, timestamp, previous_assignee_id, current_assignee_id)
    Digest::SHA256.hexdigest(
      [conversation.account_id, conversation.id, timestamp.to_f, previous_assignee_id, current_assignee_id].join(':')
    )
  end
end
