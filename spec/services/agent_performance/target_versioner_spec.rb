require 'rails_helper'

RSpec.describe AgentPerformance::TargetVersioner do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account) }

  it 'closes the current target before creating a new effective version' do
    old_target = create(:agent_performance_target, account: account, user: agent, created_by: admin,
                                                   effective_from: Date.new(2026, 8, 1))

    new_target = described_class.new(
      account: account, actor: admin,
      attributes: {
        user_id: agent.id, period_type: 'daily', metric: 'customer_facing_messages',
        target_value: 175, effective_from: Date.new(2026, 8, 11)
      }
    ).create!

    expect(old_target.reload.effective_until).to eq(Date.new(2026, 8, 10))
    expect(new_target.target_value).to eq(175)
  end
end
