import { mount } from '@vue/test-utils';
import { useRouter } from 'vue-router';
import SearchResultMessageItem from './SearchResultMessageItem.vue';

vi.mock('vue-router', () => ({
  useRouter: vi.fn(),
}));

vi.mock('dashboard/composables/useInbox', () => ({
  useInbox: () => ({ inbox: { value: null } }),
}));

vi.mock('shared/helpers/timeHelper', () => ({
  dynamicTime: value => value,
}));

describe('SearchResultMessageItem', () => {
  const push = vi.fn();

  const mountComponent = (props = {}) =>
    mount(SearchResultMessageItem, {
      props: {
        id: 42,
        accountId: 1,
        messageId: 99,
        ...props,
      },
      slots: {
        default:
          '<div><span class="author">Jane</span><span class="message">Hello</span></div>',
      },
      global: {
        stubs: {
          Icon: true,
          AudioChip: true,
          FileChip: true,
          TranscribedText: true,
        },
        mocks: {
          $t: key => key,
        },
      },
    });

  beforeEach(() => {
    push.mockReset();
    useRouter.mockReturnValue({ push });
  });

  it.each(['.author', '.message'])(
    'opens the matching conversation when clicking %s',
    async selector => {
      const wrapper = mountComponent();

      await wrapper.get(selector).trigger('click');

      expect(push).toHaveBeenCalledWith({
        name: 'inbox_conversation',
        params: {
          accountId: 1,
          conversation_id: 42,
        },
        query: { messageId: 99 },
      });
    }
  );

  it('opens the conversation without crashing when message id is unavailable', async () => {
    const wrapper = mountComponent({ messageId: 0 });

    await wrapper.get('[role="link"]').trigger('click');

    expect(push).toHaveBeenCalledWith({
      name: 'inbox_conversation',
      params: {
        accountId: 1,
        conversation_id: 42,
      },
      query: {},
    });
  });
});
