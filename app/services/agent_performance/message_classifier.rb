class AgentPerformance::MessageClassifier
  Result = Data.define(:eligible, :message_kind)

  def self.call(message)
    new(message).call
  end

  def initialize(message)
    @message = message
  end

  def call
    return Result.new(eligible: false, message_kind: nil) unless eligible?

    Result.new(eligible: true, message_kind: manual_template? ? 'manual_template' : 'manual')
  end

  private

  attr_reader :message

  def eligible?
    message.outgoing? && message.sender_type == 'User' && message.sender_id.present? && !message.private? && manually_authored?
  end

  def manually_authored?
    message.content_attributes.to_h['automation_rule_id'].blank? &&
      message.additional_attributes.to_h['campaign_id'].blank?
  end

  def manual_template?
    message.additional_attributes.to_h['template_params'].present?
  end
end
