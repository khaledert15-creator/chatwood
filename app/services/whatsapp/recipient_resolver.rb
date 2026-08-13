class Whatsapp::RecipientResolver
  pattr_initialize [:contact_inbox!]

  def resolve
    return contact_inbox.source_id if valid_recipient?(contact_inbox.source_id)

    sibling_recipients = numeric_sibling_recipients
    return sibling_recipients.first if sibling_recipients.one?
    return if sibling_recipients.many?

    recipient_from_contact_phone
  end

  private

  def numeric_sibling_recipients
    contact_inbox.contact.contact_inboxes
                 .where(inbox_id: contact_inbox.inbox_id)
                 .where.not(id: contact_inbox.id)
                 .pluck(:source_id)
                 .select { |source_id| valid_recipient?(source_id) }
                 .uniq
  end

  def recipient_from_contact_phone
    phone_number = contact_inbox.contact.phone_number.to_s
    return unless phone_number.match?(/\A\+[1-9]\d{1,14}\z/)

    phone_number.delete_prefix('+')
  end

  def valid_recipient?(source_id)
    source_id.to_s.match?(/\A\d{1,15}\z/)
  end
end
