class CreateAgentPerformanceTargets < ActiveRecord::Migration[7.1]
  def change
    create_table :agent_performance_targets do |t|
      t.integer :account_id, null: false
      t.bigint :user_id
      t.string :period_type, null: false
      t.string :metric, null: false
      t.decimal :target_value, precision: 12, scale: 2, null: false
      t.integer :threshold_seconds
      t.string :comparison, default: 'at_least', null: false
      t.date :effective_from, null: false
      t.date :effective_until
      t.bigint :created_by_id, null: false
      t.timestamps
    end

    add_index :agent_performance_targets, [:account_id, :user_id, :period_type, :metric, :effective_from],
              name: 'index_agent_performance_targets_scope'
    add_index :agent_performance_targets, [:account_id, :period_type, :metric, :effective_from],
              name: 'index_agent_performance_targets_default_scope'
  end
end
