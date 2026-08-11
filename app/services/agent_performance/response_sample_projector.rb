class AgentPerformance::ResponseSampleProjector
  def self.call(message)
    new(message).call
  end

  def initialize(message)
    @message = message
  end

  def call
    return unless AgentPerformance::MessageClassifier.call(message).eligible

    wait_started_at = customer_wait_started_at
    interval = assignment_interval
    exclusion = exclusion_attributes(wait_started_at, interval)

    AgentPerformance::ResponseSample.upsert( # rubocop:disable Rails/SkipsModelValidations
      attributes(wait_started_at, interval, exclusion),
      unique_by: :source_message_id
    )
  end

  private

  attr_reader :message

  def preceding_messages
    message.conversation.messages.unscope(:order).where('created_at < ? OR (created_at = ? AND id < ?)', message.created_at, message.created_at,
                                                        message.id)
  end

  def previous_human_response
    preceding_messages.outgoing.where(sender_type: 'User', private: false)
                      .where("COALESCE(content_attributes->>'automation_rule_id', '') = ''")
                      .where("COALESCE(additional_attributes->>'campaign_id', '') = ''")
                      .order(created_at: :desc, id: :desc).first
  end

  def customer_wait_started_at
    scope = preceding_messages.incoming.where(private: false)
    scope = scope.where('created_at > ?', previous_human_response.created_at) if previous_human_response
    scope.minimum(:created_at)
  end

  def assignment_interval
    AgentPerformance::AssignmentInterval.where(account_id: message.account_id, conversation_id: message.conversation_id)
                                        .covering(message.created_at).first
  end

  def exclusion_attributes(wait_started_at, interval)
    return { reason: 'invalid_waiting_episode', eligible: false, unassigned: false, missing: false } if wait_started_at.blank?
    return { reason: nil, eligible: true, unassigned: false, missing: false } if interval&.user_id == message.sender_id
    return { reason: 'unassigned_responder', eligible: false, unassigned: true, missing: false } if interval.present?

    { reason: 'assignment_history_missing', eligible: false, unassigned: false, missing: true }
  end

  def attributes(wait_started_at, interval, exclusion) # rubocop:disable Metrics/AbcSize
    responsibility_started_at = [wait_started_at, interval&.started_at].compact.max if exclusion[:eligible]
    {
      account_id: message.account_id, user_id: message.sender_id, conversation_id: message.conversation_id,
      inbox_id: message.inbox_id, source_message_id: message.id,
      customer_wait_started_at: wait_started_at, responsibility_started_at: responsibility_started_at,
      responded_at: message.created_at,
      customer_wait_seconds: duration(wait_started_at), accountable_wait_seconds: duration(responsibility_started_at),
      first_response: previous_human_response.blank?, sla_eligible: exclusion[:eligible],
      unassigned_responder: exclusion[:unassigned], assignment_history_missing: exclusion[:missing],
      exclusion_reason: exclusion[:reason], created_at: Time.current, updated_at: Time.current
    }
  end

  def duration(started_at)
    (message.created_at - started_at).to_i if started_at
  end
end
