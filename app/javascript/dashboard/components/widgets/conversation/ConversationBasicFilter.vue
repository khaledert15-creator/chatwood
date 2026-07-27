<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useToggle } from '@vueuse/core';
import { vOnClickOutside } from '@vueuse/components';
import { useUISettings } from 'dashboard/composables/useUISettings';
import { useMapGetter, useStore } from 'dashboard/composables/store.js';
import wootConstants from 'dashboard/constants/globals';
import SelectMenu from 'dashboard/components-next/selectmenu/SelectMenu.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  isOnExpandedLayout: {
    type: Boolean,
    required: true,
  },
  activeStatus: {
    type: String,
    required: true,
  },
  activeResponseState: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['changeFilter']);

const store = useStore();
const { t } = useI18n();

const { updateUISettings } = useUISettings();

const chatSortFilter = useMapGetter('getChatSortFilter');
const unreadCount = useMapGetter(
  'conversationUnreadCounts/getUnreadResponseCount'
);

const [showActionsDropdown, toggleDropdown] = useToggle();

const currentSortBy = computed(() => {
  return (
    chatSortFilter.value || wootConstants.SORT_BY_TYPE.LAST_ACTIVITY_AT_DESC
  );
});

const responseStateOptions = computed(() => [
  {
    label: t('CHAT_LIST.RESPONSE_STATE_FILTER_ITEMS.needs_reply.TEXT'),
    value: 'needs_reply',
    status: 'active',
    responseState: 'needs_reply',
    assigneeType: 'all',
  },
  {
    label: t('CHAT_LIST.RESPONSE_STATE_FILTER_ITEMS.unread.TEXT'),
    value: 'unread',
    status: 'active',
    responseState: 'unread',
    assigneeType: 'all',
    count: unreadCount.value,
  },
  {
    label: t('CHAT_LIST.RESPONSE_STATE_FILTER_ITEMS.mine.TEXT'),
    value: 'mine',
    status: 'active',
    responseState: 'mine',
    assigneeType: 'me',
  },
  {
    label: t('CHAT_LIST.RESPONSE_STATE_FILTER_ITEMS.all.TEXT'),
    value: 'all',
    status: 'active',
    responseState: 'all',
    assigneeType: 'all',
  },
  {
    label: t('CHAT_LIST.RESPONSE_STATE_FILTER_ITEMS.snoozed.TEXT'),
    value: 'snoozed',
    status: 'snoozed',
    responseState: 'snoozed',
    assigneeType: 'all',
  },
  {
    label: t('CHAT_LIST.RESPONSE_STATE_FILTER_ITEMS.resolved.TEXT'),
    value: 'resolved',
    status: 'resolved',
    responseState: 'resolved',
    assigneeType: 'all',
  },
]);

const chatSortOptions = computed(() => [
  {
    label: t('CHAT_LIST.SORT_ORDER_ITEMS.last_activity_at_asc.TEXT'),
    value: 'last_activity_at_asc',
  },
  {
    label: t('CHAT_LIST.SORT_ORDER_ITEMS.last_activity_at_desc.TEXT'),
    value: 'last_activity_at_desc',
  },
  {
    label: t('CHAT_LIST.SORT_ORDER_ITEMS.created_at_desc.TEXT'),
    value: 'created_at_desc',
  },
  {
    label: t('CHAT_LIST.SORT_ORDER_ITEMS.created_at_asc.TEXT'),
    value: 'created_at_asc',
  },
  {
    label: t('CHAT_LIST.SORT_ORDER_ITEMS.unread.TEXT'),
    value: 'unread',
  },
  {
    label: t('CHAT_LIST.SORT_ORDER_ITEMS.priority_desc.TEXT'),
    value: 'priority_desc',
  },
  {
    label: t('CHAT_LIST.SORT_ORDER_ITEMS.priority_asc.TEXT'),
    value: 'priority_asc',
  },
  {
    label: t('CHAT_LIST.SORT_ORDER_ITEMS.priority_desc_created_at_asc.TEXT'),
    value: 'priority_desc_created_at_asc',
  },
  {
    label: t('CHAT_LIST.SORT_ORDER_ITEMS.waiting_since_asc.TEXT'),
    value: 'waiting_since_asc',
  },
  {
    label: t('CHAT_LIST.SORT_ORDER_ITEMS.waiting_since_desc.TEXT'),
    value: 'waiting_since_desc',
  },
]);

const activeResponseState = computed(() => {
  if (props.activeResponseState) return props.activeResponseState;
  if (props.activeStatus === 'resolved') return 'resolved';
  if (props.activeStatus === 'snoozed') return 'snoozed';
  return 'all';
});

const activeChatSortLabel = computed(
  () =>
    chatSortOptions.value.find(m => m.value === chatSortFilter.value)?.label ||
    ''
);

const saveSelectedFilter = (type, value) => {
  const selectedResponseState =
    type === 'responseState'
      ? responseStateOptions.value.find(option => option.value === value)
      : null;
  updateUISettings({
    conversations_filter_by: {
      status: selectedResponseState?.status || props.activeStatus,
      response_state:
        selectedResponseState !== null
          ? selectedResponseState.responseState
          : props.activeResponseState,
      order_by: type === 'sort' ? value : currentSortBy.value,
    },
  });
};

const handleResponseStateChange = value => {
  const selectedOption = responseStateOptions.value.find(
    option => option.value === value
  );
  if (!selectedOption) return;

  emit('changeFilter', selectedOption, 'responseState');
  store.dispatch('setChatStatusFilter', selectedOption.status);
  saveSelectedFilter('responseState', value);
};

const handleSortChange = value => {
  emit('changeFilter', value, 'sort');
  store.dispatch('setChatSortFilter', value);
  saveSelectedFilter('sort', value);
};
</script>

<template>
  <div class="flex items-center min-w-0 gap-1">
    <div
      class="flex min-w-0 gap-1 overflow-x-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
      dir="rtl"
    >
      <button
        v-for="option in responseStateOptions"
        :key="option.value"
        type="button"
        class="flex items-center gap-1 px-2.5 py-1.5 text-xs font-medium whitespace-nowrap rounded-lg border transition-colors"
        :class="
          activeResponseState === option.value
            ? 'bg-n-brand text-white border-n-brand'
            : 'bg-n-alpha-2 text-n-slate-11 border-n-weak hover:bg-n-alpha-3'
        "
        @click="handleResponseStateChange(option.value)"
      >
        <span>{{ option.label }}</span>
        <span
          v-if="option.count"
          class="min-w-4 px-1 rounded-full bg-n-alpha-3 text-[10px]"
        >
          {{ option.count }}
        </span>
      </button>
    </div>
    <div class="relative shrink-0">
      <NextButton
        v-tooltip.right="$t('CHAT_LIST.SORT_TOOLTIP_LABEL')"
        icon="i-lucide-arrow-up-down"
        slate
        faded
        xs
        @click="toggleDropdown()"
      />
      <div
        v-if="showActionsDropdown"
        v-on-click-outside="() => toggleDropdown()"
        class="mt-1 bg-n-alpha-3 backdrop-blur-[100px] border border-n-weak w-64 rounded-xl p-4 absolute z-40 top-full"
        :class="{
          'ltr:left-0 rtl:right-0': !isOnExpandedLayout,
          'ltr:right-0 rtl:left-0': isOnExpandedLayout,
        }"
      >
        <div class="flex items-center justify-between gap-2">
          <span class="text-sm truncate text-n-slate-12">
            {{ $t('CHAT_LIST.CHAT_SORT.ORDER_BY') }}
          </span>
          <SelectMenu
            :model-value="chatSortFilter"
            :options="chatSortOptions"
            :label="activeChatSortLabel"
            :sub-menu-position="isOnExpandedLayout ? 'left' : 'right'"
            @update:model-value="handleSortChange"
          />
        </div>
      </div>
    </div>
  </div>
</template>
