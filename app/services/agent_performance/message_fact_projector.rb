class AgentPerformance::MessageFactProjector
  def self.call(message)
    new(message).call
  end

  def initialize(message)
    @message = message
  end

  def call
    classification = AgentPerformance::MessageClassifier.call(message)
    return unless classification.eligible

    AgentPerformance::MessageFact.upsert( # rubocop:disable Rails/SkipsModelValidations
      attributes(classification.message_kind),
      unique_by: :source_message_id
    )
  end

  private

  attr_reader :message

  def attributes(message_kind)
    {
      account_id: message.account_id,
      user_id: message.sender_id,
      conversation_id: message.conversation_id,
      inbox_id: message.inbox_id,
      contact_id: message.conversation.contact_id,
      source_message_id: message.id,
      message_kind: message_kind,
      sent_at: message.created_at,
      created_at: Time.current,
      updated_at: Time.current
    }
  end
end
