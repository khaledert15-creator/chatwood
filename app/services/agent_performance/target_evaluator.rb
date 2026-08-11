class AgentPerformance::TargetEvaluator
  def initialize(target:, actual:, unit: :count)
    @target = target
    @actual = actual
    @unit = unit
  end

  def as_json # rubocop:disable Metrics/AbcSize
    return unconfigured if target.blank?
    return no_eligible_responses if actual.nil?

    {
      configured: true,
      target: target.target_value.to_f,
      actual: actual.to_f,
      difference: (actual.to_f - target.target_value.to_f).round(2),
      difference_unit: unit == :percentage ? 'percentage_points' : 'count',
      achievement_percentage: ((actual.to_f / target.target_value) * 100).round(2),
      status: actual.to_f >= target.target_value.to_f ? 'target_achieved' : 'below_target',
      threshold_seconds: target.threshold_seconds
    }
  end

  private

  attr_reader :target, :actual, :unit

  def unconfigured
    { configured: false, target: nil, actual: actual, difference: nil, achievement_percentage: nil, status: 'not_configured' }
  end

  def no_eligible_responses
    {
      configured: true, target: target.target_value.to_f, actual: nil, difference: nil,
      difference_unit: 'percentage_points', achievement_percentage: nil, status: 'no_eligible_responses',
      threshold_seconds: target.threshold_seconds
    }
  end
end
