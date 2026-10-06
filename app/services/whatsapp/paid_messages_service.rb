class Whatsapp::PaidMessagesService
  PAGE_SIZE = 50

  def initialize(account, report:, classification:, inbox_id:, before_id:)
    @account = account
    @start_at = report.start_at
    @end_at = report.end_at
    @classification = classification.presence || 'paid'
    raise ArgumentError, 'invalid_classification' unless %w[paid unclassified].include?(@classification)

    @inbox_id = inbox_id
    @before_id = before_id
    raise ArgumentError, 'invalid_cursor' if @before_id.present? && !@before_id.to_s.match?(/\A[1-9]\d*\z/)
  end

  def perform
    rows = message_scope.reorder(id: :desc).limit(PAGE_SIZE + 1).includes(:inbox, conversation: :contact).to_a
    visible_rows = rows.first(PAGE_SIZE)
    {
      classification: @classification,
      messages: visible_rows.map { |message| message_details(message) },
      has_more: rows.length > PAGE_SIZE,
      next_before_id: rows.length > PAGE_SIZE ? visible_rows.last.id : nil
    }
  end

  private

  def cloud_inbox_ids
    ids = @account.inboxes.where(channel_type: 'Channel::Whatsapp').includes(:channel)
                  .select { |inbox| inbox.channel.provider == 'whatsapp_cloud' }.map(&:id)
    return ids if @inbox_id.blank?

    raise ArgumentError, 'invalid_inbox' unless ids.include?(@inbox_id.to_i)

    [@inbox_id.to_i]
  end

  def message_scope
    messages = @account.messages.where(inbox_id: cloud_inbox_ids, message_type: %i[outgoing template],
                                       status: %i[delivered read], private: false)
    messages = filter_by_classification(messages)
    @before_id.present? ? messages.where('messages.id < ?', @before_id.to_i) : messages
  end

  def filter_by_classification(messages)
    if @classification == 'paid'
      messages.where("messages.additional_attributes #>> '{whatsapp_pricing,type}' = ?", 'regular')
              .where("messages.additional_attributes #>> '{whatsapp_pricing,delivered_at}' >= ?", @start_at.utc.iso8601)
              .where("messages.additional_attributes #>> '{whatsapp_pricing,delivered_at}' < ?", @end_at.utc.iso8601)
    else
      messages.where(created_at: @start_at...@end_at)
              .where("messages.additional_attributes -> 'whatsapp_pricing' IS NULL")
    end
  end

  def message_details(message)
    pricing = message.additional_attributes['whatsapp_pricing'] || {}
    {
      id: message.id,
      inbox_id: message.inbox_id,
      inbox_name: message.inbox.name,
      conversation_id: message.conversation_id,
      contact_name: message.conversation.contact&.name,
      content: (message.processed_message_content.presence || message.content).to_s.truncate(240),
      time: @classification == 'paid' ? pricing['delivered_at'] : message.created_at.iso8601,
      category: pricing['category']
    }
  end
end
