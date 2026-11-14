namespace :agent_performance do
  desc 'Recalculate agent performance for every day that has data, e.g. after the calculation rules change'
  task rebuild: :environment do
    Account.find_each do |account|
      next unless account.feature_enabled?('agent_performance_analytics')

      first_sent_at = AgentPerformance::MessageFact.where(account_id: account.id).minimum(:sent_at)
      next if first_sent_at.blank?

      AgentPerformance::MessageReconciler.new(account: account, since: first_sent_at).perform
      today = Time.current.in_time_zone('Africa/Cairo').to_date
      (first_sent_at.in_time_zone('Africa/Cairo').to_date..today).each do |date|
        AgentPerformance::BuildRollupsJob.perform_now(account.id, date)
      end
      puts "Account #{account.id}: rebuilt from #{first_sent_at.to_date} to #{today}"
    end
  end
end
