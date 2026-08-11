<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import AgentPerformanceAPI from 'dashboard/api/agentPerformance';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import ReportHeader from '../components/ReportHeader.vue';
import PerformanceMetricCard from './PerformanceMetricCard.vue';
import TargetCard from './TargetCard.vue';

const store = useStore();
const { t, locale } = useI18n();
const report = ref(null);
const loading = ref(false);
const saving = ref(false);
const selectedAgentId = ref('');
const selectedDate = ref(
  new Intl.DateTimeFormat('en-CA', { timeZone: 'Africa/Cairo' }).format(
    new Date()
  )
);
const targetForm = reactive({
  messages: '',
  replied: '',
  sla: '',
  threshold: 180,
});

const agents = computed(() => store.getters['agents/getAgents'] || []);
const distributionRows = computed(() => [
  {
    label: t('AGENT_PERFORMANCE.BUCKETS.bucket_under_1m'),
    value: report.value?.response_distribution?.bucket_under_1m,
  },
  {
    label: t('AGENT_PERFORMANCE.BUCKETS.bucket_1_to_3m'),
    value: report.value?.response_distribution?.bucket_1_to_3m,
  },
  {
    label: t('AGENT_PERFORMANCE.BUCKETS.bucket_3_to_5m'),
    value: report.value?.response_distribution?.bucket_3_to_5m,
  },
  {
    label: t('AGENT_PERFORMANCE.BUCKETS.bucket_5_to_10m'),
    value: report.value?.response_distribution?.bucket_5_to_10m,
  },
  {
    label: t('AGENT_PERFORMANCE.BUCKETS.bucket_10_to_30m'),
    value: report.value?.response_distribution?.bucket_10_to_30m,
  },
  {
    label: t('AGENT_PERFORMANCE.BUCKETS.bucket_30m_plus'),
    value: report.value?.response_distribution?.bucket_30m_plus,
  },
]);
const exclusionRows = computed(() => [
  {
    label: t('AGENT_PERFORMANCE.EXCLUSION_REASONS.assignment_history_missing'),
    value:
      report.value?.response_eligibility?.exclusion_reasons
        ?.assignment_history_missing,
  },
  {
    label: t('AGENT_PERFORMANCE.EXCLUSION_REASONS.unassigned_responder'),
    value:
      report.value?.response_eligibility?.exclusion_reasons
        ?.unassigned_responder,
  },
  {
    label: t('AGENT_PERFORMANCE.EXCLUSION_REASONS.invalid_waiting_episode'),
    value:
      report.value?.response_eligibility?.exclusion_reasons
        ?.invalid_waiting_episode,
  },
  {
    label: t('AGENT_PERFORMANCE.EXCLUSION_REASONS.non_human_response'),
    value:
      report.value?.response_eligibility?.exclusion_reasons?.non_human_response,
  },
]);
const freshnessTime = computed(() => {
  const timestamp = report.value?.freshness?.data_fresh_as_of;
  return timestamp
    ? new Date(timestamp).toLocaleTimeString(locale.value, {
        hour: '2-digit',
        minute: '2-digit',
      })
    : '—';
});
const trackingStartTime = computed(() => {
  const timestamp = report.value?.analytics_tracking_started_at;
  return timestamp ? new Date(timestamp).toLocaleString(locale.value) : null;
});

const formatSeconds = value => {
  if (value == null) return '—';
  if (value < 60) {
    return t('AGENT_PERFORMANCE.SECONDS', { value: Math.round(value) });
  }
  return t('AGENT_PERFORMANCE.MINUTES', {
    value: (value / 60).toFixed(1),
  });
};

const loadReport = async () => {
  if (!selectedAgentId.value) return;
  loading.value = true;
  try {
    const { data } = await AgentPerformanceAPI.getDaily({
      agentId: selectedAgentId.value,
      date: selectedDate.value,
    });
    report.value = data;
  } catch {
    useAlert(t('AGENT_PERFORMANCE.LOAD_ERROR'));
  } finally {
    loading.value = false;
  }
};

const saveTarget = async (metric, targetValue, thresholdSeconds = null) => {
  if (!targetValue) return;
  await AgentPerformanceAPI.createTarget({
    user_id: selectedAgentId.value,
    period_type: 'daily',
    metric,
    target_value: targetValue,
    threshold_seconds: thresholdSeconds,
    effective_from: selectedDate.value,
  });
};

const saveTargets = async () => {
  saving.value = true;
  try {
    await Promise.all([
      saveTarget('customer_facing_messages', targetForm.messages),
      saveTarget('replied_conversations', targetForm.replied),
      saveTarget(
        'response_sla_compliance',
        targetForm.sla,
        targetForm.threshold
      ),
    ]);
    useAlert(t('AGENT_PERFORMANCE.TARGETS_SAVED'));
    await loadReport();
  } catch {
    useAlert(t('AGENT_PERFORMANCE.TARGETS_ERROR'));
  } finally {
    saving.value = false;
  }
};

watch([selectedAgentId, selectedDate], loadReport);
onMounted(async () => {
  await store.dispatch('agents/get');
  selectedAgentId.value = agents.value[0]?.id || '';
});
</script>

<template>
  <div dir="rtl" class="flex flex-col w-full h-full overflow-auto text-start">
    <ReportHeader
      :header-title="$t('AGENT_PERFORMANCE.HEADER')"
      :header-description="$t('AGENT_PERFORMANCE.DESCRIPTION')"
    />

    <div class="flex flex-wrap gap-3 mb-5">
      <label class="flex flex-col gap-1 text-label-small text-n-slate-11">
        {{ $t('AGENT_PERFORMANCE.AGENT') }}
        <select
          v-model="selectedAgentId"
          class="h-10 px-3 rounded-lg bg-n-alpha-2 text-n-slate-12 outline outline-1 outline-n-weak"
          :aria-label="$t('AGENT_PERFORMANCE.SELECT_AGENT')"
        >
          <option v-for="agent in agents" :key="agent.id" :value="agent.id">
            {{ agent.name }}
          </option>
        </select>
      </label>
      <Input
        v-model="selectedDate"
        type="date"
        dir="ltr"
        class="max-w-48"
        :label="$t('AGENT_PERFORMANCE.DATE')"
      />
      <span class="self-center text-body-small text-n-slate-11">
        {{ $t('AGENT_PERFORMANCE.DATA_UPDATED', { time: freshnessTime }) }}
      </span>
    </div>

    <div
      v-if="report?.freshness?.delayed"
      class="p-3 mb-5 rounded-lg bg-n-amber-3 text-n-amber-12"
    >
      {{ $t('AGENT_PERFORMANCE.DATA_DELAYED') }}
    </div>

    <div v-if="loading" class="py-20" data-testid="loading-state">
      <Spinner class="mx-auto" />
    </div>
    <template v-else-if="report">
      <div
        v-if="trackingStartTime"
        class="p-4 mb-5 rounded-lg bg-n-blue-3 text-n-blue-12"
        data-testid="tracking-start-notice"
      >
        <p class="font-medium">
          {{
            $t('AGENT_PERFORMANCE.TRACKING_START', {
              time: trackingStartTime,
            })
          }}
        </p>
        <p class="mt-1 text-body-small">
          {{ $t('AGENT_PERFORMANCE.TRACKING_START_EXPLANATION') }}
        </p>
      </div>
      <div
        v-else
        class="p-4 mb-5 rounded-lg bg-n-amber-3 text-n-amber-12"
        data-testid="tracking-start-warning"
      >
        {{ $t('AGENT_PERFORMANCE.TRACKING_START_MISSING') }}
      </div>

      <section class="grid grid-cols-1 gap-3 mb-6 md:grid-cols-3">
        <TargetCard
          :label="$t('AGENT_PERFORMANCE.MESSAGES')"
          :target="report.targets.messages"
        />
        <TargetCard
          :label="$t('AGENT_PERFORMANCE.REPLIED')"
          :target="report.targets.replied_conversations"
        />
        <TargetCard
          v-tooltip="$t('AGENT_PERFORMANCE.TOOLTIPS.SLA')"
          :label="$t('AGENT_PERFORMANCE.SLA')"
          :target="report.targets.response_sla"
          suffix="%"
        />
      </section>

      <section class="grid grid-cols-2 gap-3 mb-6 lg:grid-cols-4">
        <PerformanceMetricCard
          :label="$t('AGENT_PERFORMANCE.MANUAL')"
          :value="report.messages.manual"
        />
        <PerformanceMetricCard
          :label="$t('AGENT_PERFORMANCE.TEMPLATES')"
          :value="report.messages.manual_template"
        />
        <PerformanceMetricCard
          :label="$t('AGENT_PERFORMANCE.TOTAL_MESSAGES')"
          :value="report.messages.total_customer_facing"
        />
        <PerformanceMetricCard
          :label="$t('AGENT_PERFORMANCE.AVERAGE')"
          :value="formatSeconds(report.response_times.average_seconds)"
        />
        <PerformanceMetricCard
          v-tooltip="$t('AGENT_PERFORMANCE.TOOLTIPS.MEDIAN')"
          :label="$t('AGENT_PERFORMANCE.MEDIAN')"
          :value="formatSeconds(report.response_times.median_seconds)"
        />
        <PerformanceMetricCard
          v-tooltip="$t('AGENT_PERFORMANCE.TOOLTIPS.P90')"
          :label="$t('AGENT_PERFORMANCE.P90')"
          :value="formatSeconds(report.response_times.p90_seconds)"
        />
        <PerformanceMetricCard
          :label="$t('AGENT_PERFORMANCE.FIRST_RESPONSE')"
          :value="
            formatSeconds(report.response_times.first_response_average_seconds)
          "
        />
        <PerformanceMetricCard
          :label="$t('AGENT_PERFORMANCE.FASTEST_RESPONSE')"
          :value="formatSeconds(report.response_times.fastest_seconds)"
        />
        <PerformanceMetricCard
          :label="$t('AGENT_PERFORMANCE.SLOWEST_RESPONSE')"
          :value="formatSeconds(report.response_times.slowest_seconds)"
        />
        <PerformanceMetricCard
          :label="$t('AGENT_PERFORMANCE.ELIGIBLE')"
          :value="report.response_eligibility.eligible"
        />
        <PerformanceMetricCard
          :label="$t('AGENT_PERFORMANCE.EXCLUDED')"
          :value="report.response_eligibility.excluded"
        />
      </section>

      <section
        class="p-4 mb-6 rounded-xl outline outline-1 outline-n-container"
      >
        <h3 class="mb-4 text-heading-2 text-n-slate-12">
          {{ $t('AGENT_PERFORMANCE.HOURLY') }}
        </h3>
        <div class="overflow-x-auto">
          <table class="w-full text-body-small">
            <thead>
              <tr class="text-n-slate-11">
                <th class="p-2 text-start">
                  {{ $t('AGENT_PERFORMANCE.HOUR') }}
                </th>
                <th class="p-2 text-end">
                  {{ $t('AGENT_PERFORMANCE.MESSAGES') }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="row in report.hourly"
                :key="row.hour"
                class="border-t border-n-weak"
              >
                <td dir="ltr" class="p-2 text-start">
                  {{
                    new Date(row.hour).toLocaleTimeString(locale, {
                      hour: '2-digit',
                      minute: '2-digit',
                    })
                  }}
                </td>
                <td class="p-2 text-end">{{ row.messages }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <section class="grid grid-cols-1 gap-4 mb-6 lg:grid-cols-2">
        <div class="p-4 rounded-xl outline outline-1 outline-n-container">
          <h3 class="mb-4 text-heading-2 text-n-slate-12">
            {{ $t('AGENT_PERFORMANCE.DISTRIBUTION') }}
          </h3>
          <dl class="grid grid-cols-2 gap-2 text-body-small">
            <template v-for="row in distributionRows" :key="row.label">
              <dt class="text-n-slate-11">{{ row.label }}</dt>
              <dd class="text-end text-n-slate-12">{{ row.value }}</dd>
            </template>
          </dl>
        </div>
        <div class="p-4 rounded-xl outline outline-1 outline-n-container">
          <h3 class="mb-4 text-heading-2 text-n-slate-12">
            {{ $t('AGENT_PERFORMANCE.EXCLUSIONS') }}
          </h3>
          <dl class="grid grid-cols-2 gap-2 text-body-small">
            <template v-for="row in exclusionRows" :key="row.label">
              <dt class="text-n-slate-11">{{ row.label }}</dt>
              <dd class="text-end text-n-slate-12">{{ row.value }}</dd>
            </template>
          </dl>
        </div>
      </section>

      <section
        class="p-4 mb-8 rounded-xl outline outline-1 outline-n-container"
      >
        <h3 class="mb-4 text-heading-2 text-n-slate-12">
          {{ $t('AGENT_PERFORMANCE.CONFIGURE_TARGETS') }}
        </h3>
        <div class="grid grid-cols-1 gap-3 md:grid-cols-4">
          <Input
            v-model="targetForm.messages"
            type="number"
            :label="$t('AGENT_PERFORMANCE.MESSAGES')"
          />
          <Input
            v-model="targetForm.replied"
            type="number"
            :label="$t('AGENT_PERFORMANCE.REPLIED')"
          />
          <Input
            v-model="targetForm.sla"
            type="number"
            :label="$t('AGENT_PERFORMANCE.SLA_PERCENT')"
          />
          <Input
            v-model="targetForm.threshold"
            type="number"
            :label="$t('AGENT_PERFORMANCE.SLA_THRESHOLD')"
          />
        </div>
        <Button
          class="mt-4"
          :label="$t('AGENT_PERFORMANCE.SAVE_TARGETS')"
          :is-loading="saving"
          @click="saveTargets"
        />
      </section>
    </template>
  </div>
</template>
