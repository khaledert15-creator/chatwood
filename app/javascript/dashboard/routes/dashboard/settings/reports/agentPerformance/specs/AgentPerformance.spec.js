import { shallowMount } from '@vue/test-utils';
import AgentPerformance from '../AgentPerformance.vue';

const dispatch = vi.fn().mockResolvedValue();

vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({
    dispatch,
    getters: { 'agents/getAgents': [] },
  }),
}));

vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params = {}) => (params.time ? `${key}: ${params.time}` : key),
  }),
}));

const report = trackingStart => ({
  analytics_tracking_started_at: trackingStart,
  freshness: { delayed: true, data_fresh_as_of: '2026-08-11T10:10:00Z' },
  messages: { manual: 10, manual_template: 1 },
  response_times: {
    average_seconds: 60,
    median_seconds: 55,
    p90_seconds: 90,
    first_response_average_seconds: 50,
  },
  response_eligibility: { eligible: 3, excluded: 2, exclusion_reasons: {} },
  response_distribution: {},
  targets: {
    messages: { status: 'target_achieved' },
    replied_conversations: { status: 'target_achieved' },
    response_sla: { status: 'target_achieved' },
  },
  hourly: [],
});

const mountComponent = () =>
  shallowMount(AgentPerformance, {
    global: {
      mocks: {
        $t: (key, params = {}) =>
          params.time ? `${key}: ${params.time}` : key,
      },
    },
  });

describe('AgentPerformance', () => {
  it('shows the payroll tracking start and preserves report indicators', async () => {
    const wrapper = mountComponent();
    wrapper.vm.report = report('2026-08-11T10:00:00Z');
    await wrapper.vm.$nextTick();

    expect(
      wrapper.find('[data-testid="tracking-start-notice"]').text()
    ).toContain('AGENT_PERFORMANCE.TRACKING_START');
    expect(
      wrapper.find('[data-testid="tracking-start-warning"]').exists()
    ).toBe(false);
    expect(wrapper.findAllComponents({ name: 'TargetCard' })).toHaveLength(3);
    expect(
      wrapper
        .findAllComponents({ name: 'PerformanceMetricCard' })
        .map(card => card.props('label'))
    ).toEqual(
      expect.arrayContaining([
        'AGENT_PERFORMANCE.AVERAGE',
        'AGENT_PERFORMANCE.MEDIAN',
        'AGENT_PERFORMANCE.P90',
        'AGENT_PERFORMANCE.ELIGIBLE',
        'AGENT_PERFORMANCE.EXCLUDED',
      ])
    );
    expect(wrapper.text()).toContain('AGENT_PERFORMANCE.DATA_DELAYED');
  });

  it('shows an explicit warning when the payroll tracking start is missing', async () => {
    const wrapper = mountComponent();
    wrapper.vm.report = report(null);
    await wrapper.vm.$nextTick();

    expect(wrapper.find('[data-testid="tracking-start-warning"]').text()).toBe(
      'AGENT_PERFORMANCE.TRACKING_START_MISSING'
    );
  });

  it('renders only one loading state', async () => {
    const wrapper = mountComponent();
    wrapper.vm.loading = true;
    await wrapper.vm.$nextTick();

    expect(wrapper.findAll('[data-testid="loading-state"]')).toHaveLength(1);
  });
});
