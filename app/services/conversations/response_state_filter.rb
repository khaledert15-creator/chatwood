class Conversations::ResponseStateFilter
  ACTIVE_STATUSES = %w[open pending snoozed].freeze

  attr_reader :relation, :user, :account

  def initialize(relation:, user:, account:)
    @relation = relation
    @user = user
    @account = account
  end

  def perform(response_state)
    case response_state
    when 'unread'
      unread
    when 'needs_reply'
      needs_reply
    else
      relation
    end
  end

  private

  def unread
    messages = Message.arel_table
    conversations = Conversation.arel_table
    last_seen_at = Arel::Nodes::Case.new
                                         .when(conversations[:assignee_id].eq(user.id))
                                         .then(conversations[:assignee_last_seen_at])
                                         .else(conversations[:agent_last_seen_at])
    unread_message = messages
                     .project(Arel.sql('1'))
                     .where(messages[:conversation_id].eq(conversations[:id]))
                     .where(messages[:account_id].eq(account.id))
                     .where(messages[:message_type].eq(Message.message_types[:incoming]))
                     .where(messages[:private].eq(false))
                     .where(last_seen_at.eq(nil).or(messages[:created_at].gt(last_seen_at)))

    active_relation.where(unread_message.exists)
  end

  def needs_reply
    messages = Message.arel_table
    latest_messages = meaningful_messages(messages)
                      .select(
                        'DISTINCT ON (messages.conversation_id) messages.conversation_id, messages.message_type, messages.sender_type'
                      )
                      .order('messages.conversation_id, messages.created_at DESC, messages.id DESC')
    latest_messages_join = <<~SQL.squish
      INNER JOIN (#{latest_messages.to_sql}) latest_meaningful_messages
        ON latest_meaningful_messages.conversation_id = conversations.id
    SQL

    active_relation
      .joins(latest_messages_join)
      .where(
        latest_meaningful_messages: {
          message_type: Message.message_types[:incoming],
          sender_type: 'Contact'
        }
      )
  end

  def meaningful_messages(messages)
    automation_rule_id = Arel::Nodes::InfixOperation.new(
      '->>',
      messages[:content_attributes],
      Arel::Nodes.build_quoted('automation_rule_id')
    )
    campaign_id = Arel::Nodes::InfixOperation.new(
      '->>',
      messages[:additional_attributes],
      Arel::Nodes.build_quoted('campaign_id')
    )

    Message.unscoped
      .where(account_id: account.id, private: false)
      .where(conversation_id: account.conversations.where(status: ACTIVE_STATUSES).select(:id))
      .where(message_type: [Message.message_types[:incoming], Message.message_types[:outgoing]])
      .where(automation_rule_id.eq(nil))
      .where(campaign_id.eq(nil))
      .where(
        messages[:message_type].eq(Message.message_types[:incoming]).and(messages[:sender_type].eq('Contact'))
          .or(messages[:message_type].eq(Message.message_types[:outgoing]).and(messages[:sender_type].eq('User')))
      )
  end

  def active_relation
    relation.where(status: ACTIVE_STATUSES)
  end
end
