# The AgentBuilder class is responsible for creating a new agent.
# It initializes with necessary attributes and provides a perform method
# to create a user and account user in a transaction.
class AgentBuilder
  # Initializes an AgentBuilder with necessary attributes.
  # @param email [String] the email of the user.
  # @param name [String] the name of the user.
  # @param role [String] the role of the user, defaults to 'agent' if not provided.
  # @param inviter [User] the user who is inviting the agent (Current.user in most cases).
  # @param availability [String] the availability status of the user, defaults to 'offline' if not provided.
  # @param auto_offline [Boolean] the auto offline status of the user.
  # @param phone_number [String] optional mobile number the user can also log in with.
  # @param password [String] required when the agent has no email, since no invitation email can be sent.
  pattr_initialize [:email, { name: '' }, { phone_number: nil }, { password: nil }, :inviter, :account,
                    { role: :agent }, { availability: :offline }, { auto_offline: false }]

  # Creates a user and account user in a transaction.
  # @return [User] the created user.
  def perform
    ActiveRecord::Base.transaction do
      @user = find_or_create_user
      create_account_user
    end
    @user
  end

  private

  # Finds a user by email or creates a new one with a temporary password.
  # Agents without an email are created with the admin-provided password and confirmed right away.
  # @return [User] the found or created user.
  def find_or_create_user
    return create_phone_only_user if email.blank?

    user = User.from_email(email)
    if user
      user.update!(phone_number: phone_number) if phone_number.present? && user.phone_number.blank?
      return user
    end

    @name = email.split('@').first if @name.blank?
    temp_password = "1!aA#{SecureRandom.alphanumeric(12)}"
    User.create!(email: email, name: @name, phone_number: phone_number, password: temp_password, password_confirmation: temp_password)
  end

  def create_phone_only_user
    # provider 'phone' keeps devise_token_auth from requiring an email and syncing uid to it
    user = User.new(name: @name, phone_number: phone_number, provider: 'phone', password: password, password_confirmation: password)
    user.skip_confirmation!
    user.save!
    user
  end

  # Checks if the user needs confirmation.
  # @return [Boolean] true if the user is persisted and not confirmed, false otherwise.
  def user_needs_confirmation?
    @user.persisted? && !@user.confirmed?
  end

  # Creates an account user linking the user to the current account.
  def create_account_user
    AccountUser.create!({
      account_id: account.id,
      user_id: @user.id,
      inviter_id: inviter.id
    }.merge({
      role: role,
      availability: availability,
      auto_offline: auto_offline
    }.compact))
  end
end

AgentBuilder.prepend_mod_with('AgentBuilder')
