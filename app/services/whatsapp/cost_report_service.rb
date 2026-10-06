class Whatsapp::CostReportService
  attr_reader :start_at, :end_at

  FREE_TIER_START = Date.new(2026, 10, 1).freeze
  FREE_TIER_LIMIT = 1000

  def initialize(account, month:, timezone:)
    @account = account
    @timezone = ActiveSupport::TimeZone[timezone]
    raise ArgumentError, 'invalid_timezone' unless @timezone
    raise ArgumentError, 'invalid_month' unless month.to_s.match?(/\A\d{4}-\d{2}\z/)

    @month = Date.strptime(month, '%Y-%m')
    raise ArgumentError, 'invalid_month' if @month < Date.new(2025, 7, 1) || @month > @timezone.today.beginning_of_month

    @start_at = @timezone.local(@month.year, @month.month, 1)
    @end_at = [@start_at.next_month, Time.current].min
  end

  def perform
    @exchange = Whatsapp::CostExchangeRateService.new.perform
    inboxes = @account.inboxes.where(channel_type: 'Channel::Whatsapp').includes(:channel).order(:id)
    phones = inboxes.group_by { |inbox| [inbox.channel.provider, inbox.channel.provider_config['business_account_id']] }
                    .flat_map { |_group, group_inboxes| report_group(group_inboxes) }
    {
      month: @month.strftime('%Y-%m'), timezone: @timezone.tzinfo.name,
      period_start: @start_at.iso8601, period_end: @end_at.iso8601,
      free_tier_limit: @month >= FREE_TIER_START ? FREE_TIER_LIMIT : nil,
      phones: phones, totals: totals(phones),
      exchange_rate: @exchange.except(:rates).merge(usd_to_egp: @exchange[:rates]['EGP']),
      source: 'meta_pricing_analytics'
    }
  end

  private

  def report_group(inboxes)
    channel = inboxes.first.channel
    return unavailable_phones(inboxes, 'unsupported_provider') unless channel.provider == 'whatsapp_cloud'

    data = fetch_group(inboxes)
    # Scope returned data to this account's connected phone numbers, even when a WABA is shared.
    inboxes.uniq { |inbox| inbox.channel.phone_number.delete('^0-9') }.map do |inbox|
      number = inbox.channel.phone_number.delete('^0-9')
      points = data[:points].select { |point| point.fetch('phone_number').delete('^0-9') == number }
      summarize_phone(inbox, points, data)
    end
  rescue CustomExceptions::WhatsappAnalyticsError => e
    unavailable_phones(inboxes, e.message, e.code)
  end

  def fetch_group(inboxes)
    numbers = inboxes.map { |inbox| inbox.channel.phone_number.delete('^0-9') }.uniq
    cache_key = ['whatsapp-cost-report-v1', @account.id, inboxes.map { |i| i.channel.cache_key_with_version }, @month, @timezone.name]
    Rails.cache.fetch(cache_key, expires_in: 1.minute) do
      Whatsapp::PricingAnalyticsService.new(inboxes.first.channel, phone_numbers: numbers, start_at: @start_at, end_at: @end_at).perform
    end
  end

  def unavailable_phones(inboxes, error, code = nil)
    inboxes.map { |inbox| phone_details(inbox).merge(available: false, error: error, error_code: code) }
  end

  def phone_details(inbox)
    { inbox_id: inbox.id, name: inbox.name, phone_number: inbox.channel.phone_number }
  end

  def summarize_phone(inbox, points, data)
    categories = points.group_by { |point| point.fetch('pricing_category') }.map do |category, rows|
      summarize_rows(rows).merge(category: category)
    end
    summary = summarize_rows(points)
    phone_details(inbox).merge(
      summary, free_allowance(points), available: true, currency: data[:currency],
                                       cost_usd: usd_cost(summary[:cost], data[:currency]), categories: categories,
                                       fetched_at: data[:fetched_at], latest_data_at: points.map { |p| p.fetch('end') }.max
    )
  end

  def free_allowance(points)
    service = points.select { |point| point['pricing_category'] == 'SERVICE' }
    free_service = volume_for(service, 'FREE_CUSTOMER_SERVICE')
    allowance = @month >= FREE_TIER_START
    {
      free_service_volume: free_service, free_entry_point_volume: volume_for(points, 'FREE_ENTRY_POINT'),
      free_used: allowance ? [free_service, FREE_TIER_LIMIT].min : nil,
      free_remaining: allowance ? [FREE_TIER_LIMIT - free_service, 0].max : nil
    }
  end

  def usd_cost(cost, currency)
    return if cost.nil?

    rate = currency == 'USD' ? 1 : @exchange[:rates][currency]
    return unless rate&.positive?

    (cost / rate).round(8)
  end

  def volume_for(points, type)
    points.select { |point| point.fetch('pricing_type') == type }.sum { |point| point.fetch('volume') }
  end

  def sum_cost(points)
    return if points.any? { |point| point['cost'].nil? }

    points.sum { |point| BigDecimal(point.fetch('cost').to_s) }
  end

  def summarize_rows(points)
    paid = volume_for(points, 'REGULAR')
    free = points.select { |p| p.fetch('pricing_type').start_with?('FREE_') }.sum { |p| p.fetch('volume') }
    volume = points.sum { |p| p.fetch('volume') }
    { volume: volume, paid_volume: paid, free_volume: free, unclassified_volume: volume - paid - free, cost: sum_cost(points) }
  end

  def totals(phones)
    available = phones.select { |phone| phone[:available] }
    complete = phones.all? { |phone| phone[:available] && phone[:cost_usd] }
    {
      complete: complete, available_phones: available.length, total_phones: phones.length,
      cost_usd: complete ? available.sum { |phone| phone[:cost_usd] } : nil
    }.merge(%i[volume paid_volume free_volume].index_with { |key| available.sum { |phone| phone[key] } })
  end
end
