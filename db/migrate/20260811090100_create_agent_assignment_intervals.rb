class CreateAgentAssignmentIntervals < ActiveRecord::Migration[7.1]
  def change
    create_table :agent_assignment_intervals do |t|
      t.integer :account_id, null: false
      t.integer :conversation_id, null: false
      t.bigint :user_id, null: false
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.string :source_event_id, null: false
      t.string :end_source_event_id
      t.timestamps
    end

    add_index :agent_assignment_intervals, [:account_id, :conversation_id, :started_at], name: 'index_agent_assignment_intervals_conversation_time'
    add_index :agent_assignment_intervals, [:account_id, :user_id, :started_at], name: 'index_agent_assignment_intervals_agent_time'
    add_index :agent_assignment_intervals, :source_event_id, unique: true
    add_index :agent_assignment_intervals, :end_source_event_id, unique: true
    add_index :agent_assignment_intervals, [:account_id, :conversation_id], unique: true,
                                                                            where: 'ended_at IS NULL',
                                                                            name: 'index_agent_assignment_intervals_open'
  end
end
