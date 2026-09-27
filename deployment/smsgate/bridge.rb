# Runs beside Chatwoot using the same image and Rails environment.
require '/app/config/environment'
require 'puma'

class SmsGateBridge
  API = 'https://api.sms-gate.app/3rdparty/v1'.freeze

  def initialize
    @inbox = Inbox.find(ENV.fetch('SMSGATE_INBOX_ID'))
    raise 'Expected dedicated API inbox' unless @inbox.channel_type == 'Channel::Api'
    @device = ENV.fetch('SMSGATE_DEVICE_ID')
    @secret = ENV.fetch('SMSGATE_WEBHOOK_TOKEN')
    @auth = { username: ENV.fetch('SMSGATE_USERNAME'), password: ENV.fetch('SMSGATE_PASSWORD') }
    @last_poll = Time.now
  end

  def request(method, path, body = nil)
    options = { basic_auth: @auth, timeout: 15, headers: { 'User-Agent' => 'Chatwoot-SMS-Integration/1.0',
                'Content-Type' => 'application/json', 'Accept' => 'application/json' } }
    options[:body] = body.to_json if body
    HTTParty.public_send(method, "#{API}#{path}", options)
  end

  def call(env)
    if env['PATH_INFO'] == '/smsgate/health' && env['REQUEST_METHOD'] == 'GET'
      return [Time.now - @last_poll < 120 ? 200 : 503, { 'content-type' => 'application/json' }, ['{"service":"smsgate"}']]
    end
    token = env['PATH_INFO'].delete_prefix('/smsgate/events/')
    return [404, {}, []] unless env['REQUEST_METHOD'] == 'POST' && ActiveSupport::SecurityUtils.secure_compare(token, @secret)

    raw = env['rack.input'].read(262_145)
    return [413, {}, []] if raw.bytesize > 262_144

    event = JSON.parse(raw)
    return [403, {}, []] unless event.fetch('deviceId') == @device

    Rails.application.executor.wrap do
      # Inbox lock serializes duplicate device callbacks and contact creation.
      @inbox.with_lock { receive(event) } if event.fetch('event') == 'sms:received'
    end
    puts "smsgate callback accepted event=#{event.fetch('event')}"
    [200, { 'content-type' => 'application/json' }, ['{"ok":true}']]
  rescue JSON::ParserError, KeyError
    [400, {}, []]
  rescue StandardError => e
    warn "smsgate callback error: #{e.class}"
    [500, {}, []]
  end

  def receive(event)
    payload = event.fetch('payload')
    source = "smsgate:#{payload.fetch('messageId')}"
    return if @inbox.messages.exists?(source_id: source)

    sender = payload.fetch('sender').strip
    phone = TelephoneNumber.parse(sender, 'EG').international_number.gsub(/[^+0-9]/, '') if sender.match?(/\A[+\d\s()-]+\z/)
    phone = nil unless phone&.match?(/\A\+[1-9]\d{1,14}\z/)
    identity = "smsgate:#{phone || sender}:sim#{payload['simNumber']}"
    contact_inbox = @inbox.contact_inboxes.find_by(source_id: identity)
    unless contact_inbox
      contact = @inbox.account.contacts.find_by(phone_number: phone) if phone
      contact ||= @inbox.account.contacts.create!(name: sender, phone_number: phone)
      contact_inbox = ContactInbox.create!(contact: contact, inbox: @inbox, source_id: identity)
    end
    conversation = contact_inbox.conversations.where.not(status: :resolved).order(:id).last
    conversation ||= Conversation.create!(account: @inbox.account, inbox: @inbox,
                                          contact: contact_inbox.contact, contact_inbox: contact_inbox, status: :open)
    conversation.update!(additional_attributes: conversation.additional_attributes.merge('smsgate_sim' => payload['simNumber'],
                                                                                        'smsgate_sender' => phone || sender))
    conversation.messages.create!(account: @inbox.account, inbox: @inbox, sender: contact_inbox.contact,
                                  message_type: :incoming, content: payload.fetch('message'), source_id: source,
                                  content_attributes: { external_created_at: payload.fetch('receivedAt') })
  end

  def fail_message(message, text)
    message.update!(status: :failed, external_error: text,
                    additional_attributes: message.additional_attributes.merge('smsgate_state' => 'failed'))
  end

  def send_message(message)
    message.with_lock do
      return unless [nil, 'pending', 'failed'].include?(message.additional_attributes['smsgate_state'])
      return if message.deleted
      phone = message.conversation.additional_attributes['smsgate_sender'] || message.conversation.contact.phone_number
      if !phone&.match?(/\A\+[1-9]\d{1,14}\z/) || message.content.blank? || message.attachments.exists?
        fail_message(message, 'SMS requires a valid phone number and text only; attachments are not supported.')
        return
      end
      # Stable request ID prevents duplicate SMS after timeouts or process restarts.
      attempt = message.additional_attributes.fetch('smsgate_attempt', 0)
      attempt += 1 if message.additional_attributes['smsgate_state'] == 'failed'
      id = "cw-#{@inbox.id}-#{message.id}-#{attempt}"
      message.update!(source_id: id, additional_attributes: message.additional_attributes.merge('smsgate_state' => 'pending', 'smsgate_attempt' => attempt))
      body = { id: id, deviceId: @device, textMessage: { text: message.content }, phoneNumbers: [phone],
               withDeliveryReport: true, ttl: 3600 }
      sim = message.conversation.additional_attributes['smsgate_sim']
      body[:simNumber] = sim if sim
      response = request(:post, '/messages', body)
      if [202, 409].include?(response.code)
        message.update!(additional_attributes: message.additional_attributes.merge('smsgate_state' => 'submitted'))
      elsif response.code.between?(400, 499) && response.code != 429
        fail_message(message, "SMS gateway rejected the request (HTTP #{response.code}).")
      else
        raise "SMS gateway HTTP #{response.code}"
      end
    end
  end

  def sync_status(message)
    response = request(:get, "/messages/#{message.source_id}")
    raise "SMS status HTTP #{response.code}" unless response.code == 200

    state = response.parsed_response.fetch('state')
    message.with_lock do
      case state
      when 'Delivered'
        message.update!(status: :delivered, additional_attributes: message.additional_attributes.merge('smsgate_state' => 'delivered'))
      when 'Failed', 'Cancelled'
        fail_message(message, "SMS gateway reported #{state.downcase}.")
      when 'Sent'
        # Keep polling for delivery, but stop after seven days if the carrier provides no report.
        value = message.created_at < 7.days.ago ? 'sent_unconfirmed' : 'sent'
        message.update!(status: :sent, additional_attributes: message.additional_attributes.merge('smsgate_state' => value)) unless message.additional_attributes['smsgate_state'] == value
      end
    end
  end

  def poll
    @inbox.messages.where(message_type: :outgoing, private: false, status: :sent)
          .where("(source_id IS NULL AND additional_attributes->>'smsgate_state' IS NULL) OR additional_attributes->>'smsgate_state' IN ('pending', 'failed')")
          .limit(20).each do |message|
      begin
        send_message(message)
      rescue StandardError => e
        warn "smsgate send error message=#{message.id}: #{e.class}"
      end
    end
    @inbox.messages.where("additional_attributes->>'smsgate_state' IN ('submitted', 'sent')")
          .limit(100).each do |message|
      begin
        sync_status(message)
      rescue StandardError => e
        warn "smsgate status error message=#{message.id}: #{e.class}"
      end
    end
    @last_poll = Time.now
  end
end

if $PROGRAM_NAME == __FILE__
  Rails.logger.level = Logger::WARN
  bridge = SmsGateBridge.new
  Thread.new do
    loop do
      begin
        Rails.application.executor.wrap { bridge.poll }
      rescue StandardError => e
        warn "smsgate worker error: #{e.class}"
      end
      sleep 5
    end
  end
  server = Puma::Server.new(bridge, nil, { min_threads: 0, max_threads: 3 })
  server.add_tcp_listener('0.0.0.0', 3010)
  trap('TERM') { server.stop }
  trap('INT') { server.stop }
  server.run.join
end
