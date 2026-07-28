require 'rails_helper'

RSpec.describe Conversations::UnreadCounts::FilteredCountSnapshotResolver do
  subject(:resolve) do
    resolver.resolve(scope: :built_in_filter, state: state, lock_key: lock_key, claim_refresh: claim_refresh, &build)
  end

  let(:account) { create(:account) }
  let(:now) { Time.zone.parse('2026-07-28 10:00:00 UTC') }
  let(:store) { class_double(Conversations::UnreadCounts::FilteredCountStore) }
  let(:lock_manager) { instance_double(Redis::LockManager) }
  let(:resolver) { described_class.new(account: account, now: now, store: store, lock_manager: lock_manager) }
  let(:lock_key) { 'filtered-count-lock' }
  let(:payload) { { count: 1, refresh_after: refresh_after.iso8601 } }
  let(:refresh_after) { now + 5.minutes }
  let(:state) do
    Conversations::UnreadCounts::FilteredCountStore::SnapshotResult.new(
      status: :stale,
      payload: payload,
      version_mismatch: version_mismatch
    )
  end
  let(:version_mismatch) { false }
  let(:claim_refresh) { -> { true } }
  let(:build) { -> { { count: 0 } } }

  before do
    allow(Conversations::UnreadCounts::FilteredCountInstrumentation).to receive(:increment)
    allow(Conversations::UnreadCounts::FilteredCountInstrumentation).to receive(:observe) do |_operation, _attributes, &block|
      block.call
    end
    allow(store).to receive(:refresh_due?).with(payload, now: now).and_return(refresh_after <= now)
    allow(lock_manager).to receive(:with_lock)
      .with(lock_key, described_class::BUILD_LOCK_TTL)
      .and_yield
      .and_return(true)
  end

  it 'returns a same-version snapshot before refresh_after' do
    expect(resolve).to eq(payload)
    expect(lock_manager).not_to have_received(:with_lock)
  end

  it 'refreshes a same-version snapshot after refresh_after' do
    allow(store).to receive(:refresh_due?).with(payload, now: now).and_return(true)

    expect(resolve).to eq(count: 0)
  end

  it 'refreshes a version-mismatched snapshot before refresh_after' do
    allow(state).to receive(:version_mismatch?).and_return(true)

    expect(resolve).to eq(count: 0)
    expect(store).not_to have_received(:refresh_due?)
  end

  it 'does not build when the refresh claim is not acquired' do
    allow(state).to receive(:version_mismatch?).and_return(true)
    allow(lock_manager).to receive(:with_lock)
    denied_claim = -> { false }

    result = resolver.resolve(scope: :built_in_filter, state: state, lock_key: lock_key, claim_refresh: denied_claim, &build)

    expect(result).to eq(payload)
    expect(lock_manager).not_to have_received(:with_lock)
  end

  it 'returns the stale snapshot when the build lock is not acquired' do
    allow(state).to receive(:version_mismatch?).and_return(true)
    allow(lock_manager).to receive(:with_lock).with(lock_key, described_class::BUILD_LOCK_TTL).and_return(false)

    expect(resolve).to eq(payload)
  end
end
