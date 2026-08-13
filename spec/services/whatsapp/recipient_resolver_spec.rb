require 'rails_helper'

describe Whatsapp::RecipientResolver do
  subject(:recipient) { described_class.new(contact_inbox: contact_inbox).resolve }

  let(:whatsapp_channel) { create(:channel_whatsapp, provider: 'whatsapp_cloud', validate_provider_config: false, sync_templates: false) }
  let(:contact) { create(:contact, account: whatsapp_channel.account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: whatsapp_channel.inbox, source_id: source_id) }

  context 'with a valid numeric source ID' do
    let(:source_id) { '201001234567' }

    it { is_expected.to eq('201001234567') }
  end

  context 'with a non-phone source ID and no trusted recipient' do
    let(:source_id) { 'EG.123456789' }

    it { is_expected.to be_nil }
  end

  context 'with one valid numeric sibling contact inbox' do
    let(:source_id) { 'EG.123456789' }

    before do
      create(:contact_inbox, contact: contact, inbox: whatsapp_channel.inbox, source_id: '201009876543')
    end

    it { is_expected.to eq('201009876543') }
  end

  context 'with a valid contact phone number' do
    let(:source_id) { 'EG.123456789' }
    let(:contact) { create(:contact, account: whatsapp_channel.account, phone_number: '+201001112222') }

    it { is_expected.to eq('201001112222') }
  end

  context 'with multiple numeric sibling candidates' do
    let(:source_id) { 'EG.123456789' }

    before do
      create(:contact_inbox, contact: contact, inbox: whatsapp_channel.inbox, source_id: '201001111111')
      create(:contact_inbox, contact: contact, inbox: whatsapp_channel.inbox, source_id: '201002222222')
    end

    it { is_expected.to be_nil }
  end
end
