class AgentPerformance::ResponseSampleProjector
  def self.call(message)
    new(message).call
  end

  def initialize(message)
    @message = message
  end

  def call
    return unless AgentPerformance::MessageClassifier.call(message).eligible

    AgentPerformance::ResponseSample.upsert( # rubocop:disable Rails/SkipsModelValidations
      attributes(customer_wait_started_at),
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

  # A reply is credited to the agent who sent it, whoever the conversation is assigned to.
  # Follow-up messages with no new customer message in between are not replies, so they are not timed.
  def attributes(wait_started_at)
    {
      account_id: message.account_id, user_id: message.sender_id, conversation_id: message.conversation_id,
      inbox_id: message.inbox_id, source_message_id: message.id,
      customer_wait_started_at: wait_started_at, responsibility_started_at: wait_started_at,
      responded_at: message.created_at,
      customer_wait_seconds: duration(wait_started_at), accountable_wait_seconds: duration(wait_started_at),
      first_response: previous_human_response.blank?, sla_eligible: wait_started_at.present?,
      unassigned_responder: false, assignment_history_missing: false,
      exclusion_reason: wait_started_at.present? ? nil : 'invalid_waiting_episode', created_at: Time.current, updated_at: Time.current
    }
  end

  def duration(started_at)
    (message.created_at - started_at).to_i if started_at
  end
end
