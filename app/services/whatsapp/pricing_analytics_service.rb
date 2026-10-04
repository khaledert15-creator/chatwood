class Whatsapp::PricingAnalyticsService
  def initialize(channel, phone_numbers:, start_at:, end_at:)
    @channel = channel
    @phone_numbers = phone_numbers
    @start_at = start_at
    @end_at = end_at
  end

  def perform
    prepare_request
    metadata = fetch(@url, fields: 'currency')
    { currency: metadata.fetch('currency'), points: fetch_points, fetched_at: Time.current.iso8601 }
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNRESET, Errno::ECONNREFUSED
    raise CustomExceptions::WhatsappAnalyticsError, 'connection_error'
  rescue KeyError, JSON::ParserError
    raise CustomExceptions::WhatsappAnalyticsError, 'invalid_response'
  end

  private

  def prepare_request
    config = @channel.provider_config
    raise CustomExceptions::WhatsappAnalyticsError, 'missing_configuration' if config['business_account_id'].blank? || config['api_key'].blank?

    @headers = { 'Authorization' => "Bearer #{config.fetch('api_key')}" }
    version = GlobalConfigService.load('WHATSAPP_API_VERSION', 'v22.0')
    @url = "https://graph.facebook.com/#{version}/#{config.fetch('business_account_id')}"
  end

  def fetch_points
    points = []
    query = analytics_query
    loop do
      response = fetch("#{@url}/pricing_analytics", query)
      points.concat(response.fetch('data').flat_map { |row| row.fetch('data_points') })
      break if response.dig('paging', 'next').blank?

      query[:after] = response.fetch('paging').fetch('cursors').fetch('after')
    end
    points
  end

  def analytics_query
    {
      start: @start_at.to_i, end: @end_at.to_i, granularity: 'DAILY',
      phone_numbers: @phone_numbers.to_json,
      dimensions: %w[PHONE PRICING_CATEGORY PRICING_TYPE].to_json,
      metric_types: %w[COST VOLUME].to_json
    }
  end

  def fetch(url, query)
    response = HTTParty.get(url, headers: @headers, query: query, timeout: 15)
    body = response.parsed_response
    unless response.success? && body.is_a?(Hash) && !body.key?('error')
      code = body.is_a?(Hash) ? body.dig('error', 'code') : nil
      raise CustomExceptions::WhatsappAnalyticsError.new('meta_error', code)
    end

    body
  end
end
