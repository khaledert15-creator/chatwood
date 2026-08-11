class CreateAgentMessageFacts < ActiveRecord::Migration[7.1]
  def change
    create_table :agent_message_facts do |t|
      t.integer :account_id, null: false
      t.bigint :user_id, null: false
      t.integer :conversation_id, null: false
      t.integer :inbox_id, null: false
      t.bigint :contact_id
      t.integer :source_message_id, null: false
      t.string :message_kind, null: false
      t.datetime :sent_at, null: false
      t.timestamps
    end

    add_index :agent_message_facts, :source_message_id, unique: true
    add_index :agent_message_facts, [:account_id, :user_id, :sent_at], name: 'index_agent_message_facts_agent_time'
    add_index :agent_message_facts, [:account_id, :conversation_id, :sent_at], name: 'index_agent_message_facts_conversation_time'
    add_index :agent_message_facts, [:account_id, :inbox_id, :sent_at], name: 'index_agent_message_facts_inbox_time'
  end
end
