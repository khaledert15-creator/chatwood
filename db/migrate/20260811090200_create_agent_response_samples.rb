class CreateAgentResponseSamples < ActiveRecord::Migration[7.1]
  def change # rubocop:disable Metrics/MethodLength
    create_table :agent_response_samples do |t|
      t.integer :account_id, null: false
      t.bigint :user_id, null: false
      t.integer :conversation_id, null: false
      t.integer :inbox_id, null: false
      t.integer :source_message_id, null: false
      t.datetime :customer_wait_started_at
      t.datetime :responsibility_started_at
      t.datetime :responded_at, null: false
      t.integer :customer_wait_seconds
      t.integer :accountable_wait_seconds
      t.boolean :first_response, default: false, null: false
      t.boolean :sla_eligible, default: false, null: false
      t.boolean :unassigned_responder, default: false, null: false
      t.boolean :assignment_history_missing, default: false, null: false
      t.string :exclusion_reason
      t.timestamps
    end

    add_index :agent_response_samples, :source_message_id, unique: true
    add_index :agent_response_samples, [:account_id, :user_id, :responded_at], name: 'index_agent_response_samples_agent_time'
    add_index :agent_response_samples, [:account_id, :conversation_id, :responded_at], name: 'index_agent_response_samples_conversation_time'
    add_index :agent_response_samples, [:account_id, :user_id, :sla_eligible, :responded_at], name: 'index_agent_response_samples_sla'
  end
end
