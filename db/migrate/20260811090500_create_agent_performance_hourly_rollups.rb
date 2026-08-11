class CreateAgentPerformanceHourlyRollups < ActiveRecord::Migration[7.1]
  def change
    create_table :agent_performance_hourly_rollups do |t|
      t.integer :account_id, null: false
      t.bigint :user_id, null: false
      t.datetime :hour, null: false
      t.integer :manual_messages_count, default: 0, null: false
      t.integer :manual_template_messages_count, default: 0, null: false
      t.integer :total_customer_facing_messages_count, default: 0, null: false
      t.integer :replied_conversations_count, default: 0, null: false
      t.integer :response_samples_count, default: 0, null: false
      t.bigint :response_time_sum_seconds, default: 0, null: false
      t.float :response_time_average_seconds
      t.integer :sla_eligible_count, default: 0, null: false
      t.integer :sla_met_count, default: 0, null: false
      t.datetime :calculated_at, null: false
      t.timestamps
    end

    add_index :agent_performance_hourly_rollups, [:account_id, :user_id, :hour], unique: true,
                                                                                 name: 'index_agent_performance_hourly_unique'
    add_index :agent_performance_hourly_rollups, [:account_id, :hour], name: 'index_agent_performance_hourly_account_hour'
  end
end
