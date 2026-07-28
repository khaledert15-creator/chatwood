import { initializeConversationStatus } from '../chatListFilterHelper';

describe('chatListFilterHelper', () => {
  it.each(['open', 'resolved'])(
    'keeps the supported %s conversation status',
    status => {
      const updateUISettings = vi.fn();

      expect(initializeConversationStatus({ status }, updateUISettings)).toBe(
        status
      );
      expect(updateUISettings).not.toHaveBeenCalled();
    }
  );

  it.each(['active', '', null])(
    'falls back to open and corrects a stored %s conversation status',
    status => {
      const updateUISettings = vi.fn();
      const filterBy = { status, order_by: 'last_activity_at_desc' };

      expect(initializeConversationStatus(filterBy, updateUISettings)).toBe(
        'open'
      );
      expect(updateUISettings).toHaveBeenCalledOnce();
      expect(updateUISettings).toHaveBeenCalledWith({
        conversations_filter_by: {
          status: 'open',
          order_by: 'last_activity_at_desc',
        },
      });
    }
  );

  it('does not persist a fallback when no status preference exists', () => {
    const updateUISettings = vi.fn();

    expect(initializeConversationStatus({}, updateUISettings)).toBe('open');
    expect(updateUISettings).not.toHaveBeenCalled();
  });
});
