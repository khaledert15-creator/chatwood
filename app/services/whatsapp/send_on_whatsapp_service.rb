class Whatsapp::SendOnWhatsappService < Base::SendOnChannelService
  INVALID_RECIPIENT_ERROR = 'لا يوجد رقم واتساب صالح مرتبط بهذه المحادثة.'.freeze

  private

  def channel_class
    Channel::Whatsapp
  end

  def perform_reply
    recipient = whatsapp_recipient
    return mark_invalid_recipient if recipient.blank?

    should_send_template_message = template_params.present? || !message.conversation.can_reply?
    if should_send_template_message
      send_template_message(recipient)
    else
      send_session_message(recipient)
    end
  end

  def send_template_message(recipient)
    processor = Whatsapp::TemplateProcessorService.new(
      channel: channel,
      template_params: template_params,
      message: message
    )

    name, namespace, lang_code, processed_parameters = processor.call

    if name.blank?
      message.update!(status: :failed, external_error: 'Template not found or invalid template name')
      return
    end

    message_id = channel.send_template(recipient, {
                                         name: name,
                                         namespace: namespace,
                                         lang_code: lang_code,
                                         parameters: processed_parameters
                                       }, message)
    message.update!(source_id: message_id) if message_id.present?
  end

  def send_session_message(recipient)
    message_id = channel.send_message(recipient, message)
    message.update!(source_id: message_id) if message_id.present?
  end

  def whatsapp_recipient
    return contact_inbox.source_id unless channel.provider == 'whatsapp_cloud'

    Whatsapp::RecipientResolver.new(contact_inbox: contact_inbox).resolve
  end

  def mark_invalid_recipient
    message.update!(status: :failed, external_error: INVALID_RECIPIENT_ERROR)
  end

  def template_params
    message.additional_attributes && message.additional_attributes['template_params']
  end
end
