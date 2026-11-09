class ResetSavedConversationSortOrder < ActiveRecord::Migration[7.1]
  # The conversation list now defaults to "Pending response" so unreplied customers stay on top.
  # Saving the status filter also stored the old default sort, so clear it to let every agent pick up the new default.
  def up
    execute <<~SQL.squish
      UPDATE users
      SET ui_settings = ui_settings #- '{conversations_filter_by,order_by}'
      WHERE ui_settings -> 'conversations_filter_by' ? 'order_by'
    SQL
  end

  def down; end
end
