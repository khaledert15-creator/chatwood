import { shallowMount } from '@vue/test-utils';
import { ref } from 'vue';
import AgentPerformance from '../AgentPerformance.vue';

vi.mock('dashboard/api/agentPerformance', () => ({
  default: { getDaily: vi.fn(() => new Promise(() => {})) },
}));

vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const translate = (key, params = {}) =>
  Object.keys(params).length ? `${key} ${JSON.stringify(params)}` : key;

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: translate, locale: ref('ar') }),
}));

const report = {
  late_reply_minutes: 10,
  updated_at: '2026-08-11T10:10:00Z',
  agents: [
    {
      id: 1,
      name: 'Mona',
      messages: 12,
      conversations: 4,
      replies: 3,
      typical_reply_seconds: 30,
      late_replies: 0,
      targets: { messages: null, conversations: null },
    },
    {
      id: 2,
      name: 'Ali',
      messages: 40,
      conversations: 9,
      replies: 8,
      typical_reply_seconds: 190,
      late_replies: 2,
      targets: { messages: 50, conversations: null },
    },
  ],
};

const mountComponent = async () => {
  const wrapper = shallowMount(AgentPerformance, {
    global: { mocks: { $t: translate } },
  });
  wrapper.vm.loading = false;
  wrapper.vm.report = report;
  await wrapper.vm.$nextTick();
  return wrapper;
};

describe('AgentPerformance', () => {
  it('lists agents with the most messages first in plain words', async () => {
    const wrapper = await mountComponent();
    const rows = wrapper.findAll('[data-testid="agents-table"] tbody tr');

    expect(rows).toHaveLength(2);
    expect(rows[0].text()).toContain('Ali');
    expect(rows[0].text()).toContain('AGENT_PERFORMANCE.MINUTES {"value":3}');
    expect(rows[0].text()).toContain(
      'AGENT_PERFORMANCE.LATE_OF_REPLIES {"late":2,"replies":8}'
    );
    expect(rows[1].text()).toContain('AGENT_PERFORMANCE.UNDER_A_MINUTE');
  });

  it('marks a number below its target in red', async () => {
    const wrapper = await mountComponent();
    const messagesCell = wrapper
      .findAll('[data-testid="agents-table"] tbody tr')[0]
      .findAll('td')[1];

    expect(messagesCell.find('span').classes()).toContain('text-n-ruby-11');
    expect(messagesCell.text()).toContain(
      'AGENT_PERFORMANCE.OF_TARGET {"target":50}'
    );
  });

  it('renders only one loading state', async () => {
    const wrapper = await mountComponent();
    wrapper.vm.loading = true;
    await wrapper.vm.$nextTick();

    expect(wrapper.findAll('[data-testid="loading-state"]')).toHaveLength(1);
  });
});
