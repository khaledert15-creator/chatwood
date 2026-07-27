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
    active_relation.where(unread_message_query.exists)
  end

  def needs_reply
    active_relation
      .joins(<<~SQL.squish)
        INNER JOIN (#{latest_meaningful_messages.to_sql}) latest_meaningful_messages
        ON latest_meaningful_messages.conversation_id = conversations.id
      SQL
      .where(
        latest_meaningful_messages: {
          message_type: Message.message_types[:incoming],
          sender_type: 'Contact'
        }
      )
  end

  def unread_message_query
    unread_messages.where(last_seen_at.eq(nil).or(messages[:created_at].gt(last_seen_at)))
  end

  def unread_messages
    public_account_messages
      .project(Arel.sql('1'))
      .where(messages[:conversation_id].eq(conversations[:id]))
      .where(messages[:message_type].eq(Message.message_types[:incoming]))
  end

  def public_account_messages
    messages.where(messages[:account_id].eq(account.id)).where(messages[:private].eq(false))
  end

  def meaningful_messages
    Message
      .unscoped
      .where(account_id: account.id, private: false)
      .where(conversation_id: account.conversations.where(status: ACTIVE_STATUSES).select(:id))
      .where(message_type: [Message.message_types[:incoming], Message.message_types[:outgoing]])
      .where(json_attribute(:content_attributes, 'automation_rule_id').eq(nil))
      .where(json_attribute(:additional_attributes, 'campaign_id').eq(nil))
      .where(human_message)
  end

  def latest_meaningful_messages
    meaningful_messages
      .select('DISTINCT ON (messages.conversation_id) messages.conversation_id, messages.message_type, messages.sender_type')
      .order('messages.conversation_id, messages.created_at DESC, messages.id DESC')
  end

  def last_seen_at
    Arel::Nodes::Case.new
                     .when(conversations[:assignee_id].eq(user.id))
                     .then(conversations[:assignee_last_seen_at])
                     .else(conversations[:agent_last_seen_at])
  end

  def human_message
    incoming_contact = messages[:message_type].eq(Message.message_types[:incoming]).and(messages[:sender_type].eq('Contact'))
    outgoing_user = messages[:message_type].eq(Message.message_types[:outgoing]).and(messages[:sender_type].eq('User'))
    incoming_contact.or(outgoing_user)
  end

  def json_attribute(column, key)
    Arel::Nodes::InfixOperation.new('->>', messages[column], Arel::Nodes.build_quoted(key))
  end

  def messages
    Message.arel_table
  end

  def conversations
    Conversation.arel_table
  end

  def active_relation
    relation.where(status: ACTIVE_STATUSES)
  end
end
