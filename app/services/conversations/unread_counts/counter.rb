class Conversations::UnreadCounts::Counter
  MANAGE_ALL_PERMISSION = 'conversation_manage'.freeze
  UNASSIGNED_PERMISSION = 'conversation_unassigned_manage'.freeze
  PARTICIPATING_PERMISSION = 'conversation_participating_manage'.freeze

  attr_reader :account, :user

  def initialize(account:, user:)
    @account = account
    @user = user
  end

  def perform
    return with_filtered_counts(empty_counts, build: false) if permission_mode == :none

    rows = unread_conversations.pluck(:inbox_id, :team_id, :cached_label_list)
    inbox_counts = rows.map(&:first).tally.transform_keys(&:to_s)
    team_ids = visible_team_ids
    team_counts = rows.map(&:second).select { |team_id| team_ids.include?(team_id) }.tally.transform_keys(&:to_s)

    {
      all_count: inbox_counts.values.sum,
      inboxes: inbox_counts,
      labels: unread_label_counts(rows),
      teams: team_counts
    }.then { |counts| with_filtered_counts(counts) }
  end

  private

  def unread_label_counts(rows)
    label_ids_by_title = account.labels.where(show_on_sidebar: true).pluck(:title, :id).to_h
    label_ids = rows.flat_map do |_, _, label_list|
      label_list.to_s.split(',').map(&:strip).uniq.filter_map { |title| label_ids_by_title[title] }
    end
    label_ids.tally.transform_keys(&:to_s)
  end

  def unread_conversations
    conversations = account.conversations.open.with_unread_incoming_messages.where(inbox_id: visible_inbox_ids)

    case permission_mode
    when :unassigned_and_mine
      conversations.where(assignee_id: [nil, user.id])
    when :mine
      conversations.where(assignee_id: user.id)
    else
      conversations
    end
  end

  def with_filtered_counts(counts, build: true)
    return counts unless account.feature_enabled?(::Conversations::UnreadCounts::FilteredCounter::FEATURE_FLAG)

    counts.merge(build ? filtered_counter.perform : ::Conversations::UnreadCounts::FilteredCounter.empty_counts)
  end

  def permission_mode
    @permission_mode ||=
      if !custom_role_agent? || permissions.include?(MANAGE_ALL_PERMISSION)
        :base
      elsif permissions.include?(UNASSIGNED_PERMISSION)
        :unassigned_and_mine
      elsif permissions.include?(PARTICIPATING_PERMISSION)
        :mine
      else
        :none
      end
  end

  def custom_role_agent?
    account_user&.agent? && account_user.custom_role_id.present?
  end

  def permissions
    account_user&.permissions || []
  end

  def account_user
    @account_user ||= account.account_users.find_by(user_id: user.id)
  end

  def visible_inbox_ids
    @visible_inbox_ids ||= if account_user&.administrator?
                             account.inboxes.pluck(:id)
                           else
                             user.inboxes.where(account_id: account.id).pluck(:id)
                           end
  end

  def visible_team_ids
    @visible_team_ids ||= if account_user&.administrator?
                            account.teams.pluck(:id)
                          else
                            user.teams.where(account_id: account.id).pluck(:id)
                          end
  end

  def empty_counts
    { all_count: 0, inboxes: {}, labels: {}, teams: {} }
  end

  def filtered_counter
    @filtered_counter ||= ::Conversations::UnreadCounts::FilteredCounter.new(account: account, user: user)
  end
end
