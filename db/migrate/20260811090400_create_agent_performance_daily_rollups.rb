class CreateAgentPerformanceDailyRollups < ActiveRecord::Migration[7.1]
  def change # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    create_table :agent_performance_daily_rollups do |t| # rubocop:disable Metrics/BlockLength
      t.integer :account_id, null: false
      t.bigint :user_id, null: false
      t.date :date, null: false
      t.integer :manual_messages_count, default: 0, null: false
      t.integer :manual_template_messages_count, default: 0, null: false
      t.integer :total_customer_facing_messages_count, default: 0, null: false
      t.integer :replied_conversations_count, default: 0, null: false
      t.integer :response_samples_count, default: 0, null: false
      t.bigint :response_time_sum_seconds, default: 0, null: false
      t.float :response_time_average_seconds
      t.float :response_time_median_seconds
      t.float :response_time_p90_seconds
      t.integer :response_time_fastest_seconds
      t.integer :response_time_slowest_seconds
      t.integer :first_response_samples_count, default: 0, null: false
      t.float :first_response_time_average_seconds
      t.integer :sla_eligible_count, default: 0, null: false
      t.integer :sla_met_count, default: 0, null: false
      t.integer :excluded_responses_count, default: 0, null: false
      t.integer :excluded_assignment_history_missing_count, default: 0, null: false
      t.integer :excluded_unassigned_responder_count, default: 0, null: false
      t.integer :excluded_invalid_waiting_episode_count, default: 0, null: false
      t.integer :sla_threshold_seconds
      t.integer :bucket_under_1m, default: 0, null: false
      t.integer :bucket_1_to_3m, default: 0, null: false
      t.integer :bucket_3_to_5m, default: 0, null: false
      t.integer :bucket_5_to_10m, default: 0, null: false
      t.integer :bucket_10_to_30m, default: 0, null: false
      t.integer :bucket_30m_plus, default: 0, null: false
      t.datetime :calculated_at, null: false
      t.integer :source_high_watermark
      t.timestamps
    end

    add_index :agent_performance_daily_rollups, [:account_id, :user_id, :date], unique: true,
                                                                                name: 'index_agent_performance_daily_unique'
    add_index :agent_performance_daily_rollups, [:account_id, :date], name: 'index_agent_performance_daily_account_date'
  end
end
