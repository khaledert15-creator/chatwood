import { buildReportMenuItems } from '../reportMenuItems';

describe('reportMenuItems', () => {
  const t = key =>
    key === 'SIDEBAR.REPORTS_AGENT_PERFORMANCE' ? 'أداء الموظفين' : key;
  const accountScopedRoute = name => ({
    name,
    params: { accountId: 42 },
  });

  it('adds one agent performance link after the agent report', () => {
    const items = buildReportMenuItems({ t, accountScopedRoute });
    const performanceItems = items.filter(
      item => item.to.name === 'agent_performance_reports'
    );

    expect(performanceItems).toHaveLength(1);
    expect(performanceItems[0]).toEqual({
      name: 'Reports Agent Performance',
      label: 'أداء الموظفين',
      to: {
        name: 'agent_performance_reports',
        params: { accountId: 42 },
      },
    });
    expect(items[1]).toBe(performanceItems[0]);
  });
});
