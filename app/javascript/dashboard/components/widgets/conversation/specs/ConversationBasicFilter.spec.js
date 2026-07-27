import { mount } from '@vue/test-utils';
import { nextTick, ref } from 'vue';

import ConversationBasicFilter from '../ConversationBasicFilter.vue';

const updateUISettings = vi.fn();
const dispatch = vi.fn();

vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({ updateUISettings }),
}));

vi.mock('dashboard/composables/store.js', () => ({
  useMapGetter: key => {
    if (key === 'conversationUnreadCounts/getUnreadResponseCount') {
      return ref(4);
    }
    return ref('last_activity_at_desc');
  },
  useStore: () => ({ dispatch }),
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key =>
      ({
        'CHAT_LIST.RESPONSE_STATE_FILTER_ITEMS.all.TEXT': 'الكل',
        'CHAT_LIST.RESPONSE_STATE_FILTER_ITEMS.unread.TEXT': 'غير مقروءة',
        'CHAT_LIST.RESPONSE_STATE_FILTER_ITEMS.needs_reply.TEXT': 'تحتاج رد',
        'CHAT_LIST.RESPONSE_STATE_FILTER_ITEMS.mine.TEXT': 'محادثاتي',
        'CHAT_LIST.RESPONSE_STATE_FILTER_ITEMS.snoozed.TEXT': 'مؤجلة',
        'CHAT_LIST.RESPONSE_STATE_FILTER_ITEMS.resolved.TEXT': 'مغلقة',
      })[key] || key,
  }),
}));

const SelectMenuStub = {
  name: 'SelectMenu',
  props: ['modelValue', 'options', 'label'],
  emits: ['update:modelValue'],
  template: '<button class="select-menu">{{ label }}</button>',
};

const mountFilter = () =>
  mount(ConversationBasicFilter, {
    props: {
      isOnExpandedLayout: false,
      activeStatus: 'all',
      activeResponseState: '',
    },
    global: {
      mocks: {
        $t: key => key,
      },
      stubs: {
        NextButton: {
          template: '<button class="toggle" @click="$emit(\'click\')" />',
        },
        SelectMenu: SelectMenuStub,
      },
    },
  });

describe('ConversationBasicFilter', () => {
  beforeEach(() => {
    updateUISettings.mockClear();
    dispatch.mockClear();
  });

  it('shows the primary filters in priority order', () => {
    const wrapper = mountFilter();

    expect(wrapper.vm.responseStateOptions.map(option => option.label)).toEqual(
      ['تحتاج رد', 'غير مقروءة', 'محادثاتي', 'الكل', 'مؤجلة', 'مغلقة']
    );
  });

  it('emits unread response state and persists it in UI settings', async () => {
    const wrapper = mountFilter();

    wrapper.vm.handleResponseStateChange('unread');
    await nextTick();

    expect(wrapper.emitted('changeFilter')).toContainEqual([
      expect.objectContaining({
        status: 'active',
        responseState: 'unread',
        assigneeType: 'all',
      }),
      'responseState',
    ]);
    expect(updateUISettings).toHaveBeenCalledWith({
      conversations_filter_by: expect.objectContaining({
        status: 'active',
        response_state: 'unread',
      }),
    });
  });

  it('emits an independent mine filter', () => {
    const wrapper = mountFilter();

    wrapper.vm.handleResponseStateChange('mine');

    expect(wrapper.emitted('changeFilter')).toContainEqual([
      expect.objectContaining({
        status: 'active',
        responseState: 'mine',
        assigneeType: 'me',
      }),
      'responseState',
    ]);
  });
});
