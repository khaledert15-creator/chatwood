require 'rails_helper'

RSpec.describe AgentPerformance::CollectMessagesJob do # rubocop:disable RSpec/SpecFilePathFormat
  it 'routes every analytics job to the analytics queue' do
    jobs = [
      described_class,
      AgentPerformance::ReconcileJob,
      AgentPerformance::CaptureAssignmentEventJob,
      AgentPerformance::BuildRollupsJob
    ]

    expect(jobs.map(&:queue_name)).to all(eq('analytics'))
  end
end
