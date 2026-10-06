class Whatsapp::StatusPricingService
  def initialize(message, status)
    @message = message
    @status = status
  end

  def perform
    return unless @status[:status] == 'delivered'

    pricing = @status[:pricing]
    return if pricing.blank? || pricing[:type].blank? || !@status[:timestamp].to_s.match?(/\A\d+\z/)

    @message.additional_attributes = @message.additional_attributes.merge(
      'whatsapp_pricing' => {
        'type' => pricing[:type].to_s.downcase,
        'category' => pricing[:category].to_s.downcase,
        'delivered_at' => @message.additional_attributes.dig('whatsapp_pricing', 'delivered_at') || Time.at(@status[:timestamp].to_i).utc.iso8601
      }
    )
  end
end
