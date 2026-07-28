import { shallowMount } from '@vue/test-utils';
import { vi } from 'vitest';
import ChatListHeader from '../ChatListHeader.vue';
import { getSupportedConversationStatus } from 'dashboard/helper/chatListFilterHelper';

vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({
    uiSettings: { value: {} },
    updateUISettings: vi.fn(),
  }),
}));

const translations = {
  'CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.open.TEXT': 'Open',
};

describe('ChatListHeader', () => {
  it('renders the fallback label instead of a raw translation key', () => {
    const wrapper = shallowMount(ChatListHeader, {
      props: {
        pageTitle: 'Conversations',
        hasAppliedFilters: false,
        hasActiveFolders: false,
        activeStatus: getSupportedConversationStatus('active'),
        isOnExpandedLayout: false,
        conversationStats: {},
        isListLoading: false,
      },
      global: {
        mocks: {
          $t: key => translations[key] || key,
        },
      },
    });

    expect(wrapper.text()).toContain('Open');
    expect(wrapper.text()).not.toContain('CHAT_LIST.CHAT_STATUS_FILTER_ITEMS');
  });
});
