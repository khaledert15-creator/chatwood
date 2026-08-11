class CreateAgentAnalyticsCursors < ActiveRecord::Migration[7.1]
  def change
    create_table :agent_analytics_cursors do |t|
      t.integer :account_id, null: false
      t.string :collector, null: false
      t.integer :last_source_id
      t.datetime :last_source_timestamp
      t.datetime :last_successful_run_at
      t.datetime :last_reconciled_at
      t.datetime :last_error_at
      t.string :last_error
      t.timestamps
    end

    add_index :agent_analytics_cursors, [:account_id, :collector], unique: true
  end
end
