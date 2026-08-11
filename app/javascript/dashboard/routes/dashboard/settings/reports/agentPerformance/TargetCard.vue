<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  label: { type: String, required: true },
  target: { type: Object, default: null },
  suffix: { type: String, default: '' },
});
const { t } = useI18n();

const statusClass = computed(() => {
  if (props.target?.status === 'target_achieved') return 'text-n-teal-11';
  if (props.target?.status === 'below_target') return 'text-n-ruby-11';
  return 'text-n-slate-11';
});

const statusLabel = computed(() => {
  if (props.target?.status === 'target_achieved') {
    return t('AGENT_PERFORMANCE.STATUS.target_achieved');
  }
  if (props.target?.status === 'below_target') {
    return t('AGENT_PERFORMANCE.STATUS.below_target');
  }
  if (props.target?.status === 'no_eligible_responses') {
    return t('AGENT_PERFORMANCE.STATUS.no_eligible_responses');
  }
  return t('AGENT_PERFORMANCE.STATUS.not_configured');
});

const achievement = computed(() =>
  props.target?.achievement_percentage == null
    ? '—'
    : `${props.target.achievement_percentage}%`
);
</script>

<template>
  <div
    class="p-4 rounded-xl outline outline-1 outline-n-container bg-n-alpha-1"
  >
    <p class="mb-3 text-heading-3 text-n-slate-12">{{ label }}</p>
    <dl class="grid grid-cols-2 gap-2 text-body-small">
      <dt class="text-n-slate-11">{{ $t('AGENT_PERFORMANCE.TARGET') }}</dt>
      <dd class="text-end text-n-slate-12">
        {{ target?.target ?? '—' }}{{ target?.target != null ? suffix : '' }}
      </dd>
      <dt class="text-n-slate-11">{{ $t('AGENT_PERFORMANCE.ACTUAL') }}</dt>
      <dd class="text-end text-n-slate-12">
        {{ target?.actual ?? '—' }}{{ target?.actual != null ? suffix : '' }}
      </dd>
      <dt class="text-n-slate-11">{{ $t('AGENT_PERFORMANCE.DIFFERENCE') }}</dt>
      <dd class="text-end text-n-slate-12">{{ target?.difference ?? '—' }}</dd>
      <dt class="text-n-slate-11">{{ $t('AGENT_PERFORMANCE.ACHIEVEMENT') }}</dt>
      <dd class="text-end text-n-slate-12">{{ achievement }}</dd>
    </dl>
    <p class="mt-3 mb-0 text-label-small" :class="statusClass">
      {{ statusLabel }}
    </p>
  </div>
</template>
