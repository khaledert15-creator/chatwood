class Whatsapp::CostExchangeRateService
  def perform
    Rails.cache.fetch('whatsapp-cost-usd-exchange-rates', expires_in: 24.hours) do
      response = HTTParty.get('https://open.er-api.com/v6/latest/USD', timeout: 10)
      data = response.parsed_response
      unless response.success? && data.is_a?(Hash) && data['result'] == 'success' && data['base_code'] == 'USD'
        raise CustomExceptions::WhatsappAnalyticsError, 'exchange_rate_unavailable'
      end

      {
        rates: data.fetch('rates'),
        updated_at: Time.at(data.fetch('time_last_update_unix')).utc.iso8601,
        source: 'ExchangeRate-API', source_url: 'https://www.exchangerate-api.com'
      }
    end
  rescue CustomExceptions::WhatsappAnalyticsError, Net::OpenTimeout, Net::ReadTimeout, SocketError,
         Errno::ECONNRESET, Errno::ECONNREFUSED, KeyError, JSON::ParserError
    { rates: {}, error: 'exchange_rate_unavailable' }
  end
end
