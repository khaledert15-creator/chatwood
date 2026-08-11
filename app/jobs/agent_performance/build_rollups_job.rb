class AgentPerformance::BuildRollupsJob < ApplicationJob
  queue_as :analytics

  def perform(account_id = nil, date = nil)
    accounts(account_id).find_each do |account|
      next unless account.feature_enabled?('agent_performance_analytics')

      build_account(account, (date || Time.current.in_time_zone('Africa/Cairo').to_date).to_date)
    rescue StandardError => e
      ChatwootExceptionTracker.new(e, account: account).capture_exception
    end
  end

  private

  def accounts(account_id)
    scope = Account.active
    account_id.present? ? scope.where(id: account_id) : scope
  end

  def build_account(account, date)
    user_ids = account.users.pluck(:id)
    cairo_start = ActiveSupport::TimeZone['Africa/Cairo'].local(date.year, date.month, date.day)
    user_ids.each do |user_id|
      AgentPerformance::DailyRollupBuilder.new(account: account, user_id: user_id, date: date).perform
      24.times do |offset|
        AgentPerformance::HourlyRollupBuilder.new(account: account, user_id: user_id, hour: cairo_start + offset.hours).perform
      end
    end
  end
end
