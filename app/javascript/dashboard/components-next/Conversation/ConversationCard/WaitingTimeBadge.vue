<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useNow } from '@vueuse/core';

const props = defineProps({
  waitingSince: { type: Number, required: true },
});

const WARNING_AFTER_MINUTES = 5;
const DANGER_AFTER_MINUTES = 15;

const { t } = useI18n();
const now = useNow({ interval: 60000 });

const waitingMinutes = computed(() =>
  Math.max(
    1,
    Math.floor((now.value.getTime() / 1000 - props.waitingSince) / 60)
  )
);

const label = computed(() => {
  const minutes = waitingMinutes.value;
  if (minutes < 60) return t('CHAT_LIST.WAITING_BADGE.MINUTES', { minutes });
  if (minutes < 1440) {
    return t('CHAT_LIST.WAITING_BADGE.HOURS', {
      hours: Math.floor(minutes / 60),
    });
  }
  return t('CHAT_LIST.WAITING_BADGE.DAYS', {
    days: Math.floor(minutes / 1440),
  });
});

const colorClass = computed(() => {
  if (waitingMinutes.value >= DANGER_AFTER_MINUTES) {
    return 'bg-n-ruby-3 text-n-ruby-11';
  }
  if (waitingMinutes.value >= WARNING_AFTER_MINUTES) {
    return 'bg-n-amber-3 text-n-amber-11';
  }
  return 'bg-n-alpha-2 text-n-slate-11';
});
</script>

<template>
  <span
    v-tooltip.top="t('CHAT_LIST.WAITING_BADGE.TOOLTIP')"
    class="inline-flex items-center h-5 px-1.5 rounded text-xs font-medium whitespace-nowrap flex-shrink-0"
    :class="colorClass"
  >
    {{ label }}
  </span>
</template>
