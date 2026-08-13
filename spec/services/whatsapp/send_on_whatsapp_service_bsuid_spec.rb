require 'rails_helper'

describe Whatsapp::SendOnWhatsappService do
  let(:whatsapp_channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', validate_provider_config: false, sync_templates: false) }
  let(:contact_inbox) { create(:contact_inbox, inbox: whatsapp_channel.inbox, source_id: 'EG.2433044927224350') }
  let(:conversation) { create(:conversation, contact_inbox: contact_inbox, inbox: whatsapp_channel.inbox) }

  it 'passes the exact ContactInbox BSUID to the channel' do
    create(:message, message_type: :incoming, conversation: conversation, account: whatsapp_channel.account)
    message = create(:message, message_type: :outgoing, content: 'test', conversation: conversation, account: whatsapp_channel.account)
    allow(conversation).to receive(:can_reply?).and_return(true)
    allow(whatsapp_channel).to receive(:send_message).with('EG.2433044927224350', message).and_return('wamid.bsuid')

    described_class.new(message: message).perform

    expect(message.reload.source_id).to eq('wamid.bsuid')
  end
end
