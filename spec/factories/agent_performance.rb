FactoryBot.define do
  factory :agent_message_fact, class: 'AgentPerformance::MessageFact' do
    account
    user
    conversation
    inbox { conversation.inbox }
    contact { conversation.contact }
    sequence(:source_message_id)
    message_kind { 'manual' }
    sent_at { Time.current }
  end

  factory :agent_assignment_interval, class: 'AgentPerformance::AssignmentInterval' do
    account
    user
    conversation
    started_at { 5.minutes.ago }
    sequence(:source_event_id) { |n| "assignment-event-#{n}" }
  end

  factory :agent_response_sample, class: 'AgentPerformance::ResponseSample' do
    account
    user
    conversation
    inbox { conversation.inbox }
    sequence(:source_message_id)
    customer_wait_started_at { 3.minutes.ago }
    responsibility_started_at { 2.minutes.ago }
    responded_at { Time.current }
    customer_wait_seconds { 180 }
    accountable_wait_seconds { 120 }
    sla_eligible { true }
  end

  factory :agent_performance_target, class: 'AgentPerformance::Target' do
    account
    user
    created_by { user }
    period_type { 'daily' }
    metric { 'customer_facing_messages' }
    target_value { 150 }
    effective_from { Date.current }
  end
end
