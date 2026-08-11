class AgentPerformance::Target < ApplicationRecord
  self.table_name = 'agent_performance_targets'

  PERIOD_TYPES = %w[daily monthly].freeze
  METRICS = %w[customer_facing_messages replied_conversations response_sla_compliance].freeze

  belongs_to :account
  belongs_to :user, optional: true
  belongs_to :created_by, class_name: 'User'

  validates :period_type, inclusion: { in: PERIOD_TYPES }
  validates :metric, inclusion: { in: METRICS }
  validates :comparison, inclusion: { in: %w[at_least] }
  validates :target_value, numericality: { greater_than: 0 }
  validates :effective_from, presence: true
  validates :threshold_seconds, numericality: { only_integer: true, greater_than: 0 }, if: :response_sla_compliance?
  validate :threshold_only_for_sla
  validate :effective_until_follows_effective_from
  validate :effective_period_does_not_overlap

  scope :effective_on, lambda { |date|
    where('effective_from <= ? AND (effective_until IS NULL OR effective_until >= ?)', date, date)
  }

  def response_sla_compliance?
    metric == 'response_sla_compliance'
  end

  private

  def threshold_only_for_sla
    return if response_sla_compliance? || threshold_seconds.nil?

    errors.add(:threshold_seconds, 'is only valid for response SLA targets')
  end

  def effective_until_follows_effective_from
    return if effective_until.blank? || effective_from.blank? || effective_until >= effective_from

    errors.add(:effective_until, 'must be on or after effective_from')
  end

  def effective_period_does_not_overlap
    return if account_id.blank? || period_type.blank? || metric.blank? || effective_from.blank?

    overlap = self.class.where(account_id: account_id, user_id: user_id, period_type: period_type, metric: metric).where.not(id: id)
    overlap = overlap.where('effective_from <= ? AND (effective_until IS NULL OR effective_until >= ?)', effective_until || Date.new(9999, 12, 31),
                            effective_from)
    errors.add(:effective_from, 'overlaps an existing target') if overlap.exists?
  end
end
