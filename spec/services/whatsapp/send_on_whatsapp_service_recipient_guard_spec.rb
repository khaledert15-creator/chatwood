require 'rails_helper'

describe Whatsapp::SendOnWhatsappService do
  let(:whatsapp_channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', validate_provider_config: false, sync_templates: false) }
  let(:contact) { create(:contact, account: whatsapp_channel.account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: whatsapp_channel.inbox, source_id: source_id) }
  let(:conversation) { create(:conversation, contact_inbox: contact_inbox, inbox: whatsapp_channel.inbox) }

  before do
    create(:message, message_type: :incoming, conversation: conversation, account: whatsapp_channel.account)
  end

  context 'with a valid numeric recipient' do
    let(:source_id) { '201001234567' }

    it 'keeps the existing text send flow unchanged' do
      message = create(:message, message_type: :outgoing, content: 'test', conversation: conversation, account: whatsapp_channel.account)
      allow(conversation).to receive(:can_reply?).and_return(true)

      expect(whatsapp_channel).to receive(:send_message).with(source_id, message).and_return('wamid.healthy')

      described_class.new(message: message).perform

      expect(message.reload).to have_attributes(status: 'sent', external_error: nil)
    end

    it 'keeps the existing template send flow unchanged' do
      message = create(:message, message_type: :outgoing, content: 'template', conversation: conversation,
                                 account: whatsapp_channel.account, additional_attributes: { template_params: { name: 'approved' } })
      processor = instance_double(Whatsapp::TemplateProcessorService)
      allow(Whatsapp::TemplateProcessorService).to receive(:new).and_return(processor)
      allow(processor).to receive(:call).and_return(['approved', nil, 'en_US', []])

      expect(whatsapp_channel).to receive(:send_template).with(source_id, hash_including(name: 'approved'), message).and_return('wamid.template')

      described_class.new(message: message).perform

      expect(message.reload.source_id).to eq('wamid.template')
    end
  end

  context 'with an unresolved non-phone recipient' do
    let(:source_id) { 'EG.123456789' }

    it 'fails a text message locally without calling Meta' do
      message = create(:message, message_type: :outgoing, content: 'test', conversation: conversation, account: whatsapp_channel.account)

      expect(whatsapp_channel).not_to receive(:send_message)

      described_class.new(message: message).perform

      expect(message.reload).to have_attributes(
        status: 'failed',
        external_error: 'لا يوجد رقم واتساب صالح مرتبط بهذه المحادثة.'
      )
    end

    it 'fails a template message locally without calling Meta' do
      message = create(:message, message_type: :outgoing, content: 'template', conversation: conversation,
                                 account: whatsapp_channel.account, additional_attributes: { template_params: { name: 'approved' } })

      expect(whatsapp_channel).not_to receive(:send_template)

      described_class.new(message: message).perform

      expect(message.reload).to have_attributes(
        status: 'failed',
        external_error: 'لا يوجد رقم واتساب صالح مرتبط بهذه المحادثة.'
      )
    end
  end
end
