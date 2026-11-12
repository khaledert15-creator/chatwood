<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import AgentPerformanceAPI from 'dashboard/api/agentPerformance';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Avatar from 'next/avatar/Avatar.vue';
import ReportHeader from '../components/ReportHeader.vue';

const { t, locale } = useI18n();
const report = ref(null);
const loading = ref(false);
const saving = ref(false);
const selectedDate = ref(
  new Intl.DateTimeFormat('en-CA', { timeZone: 'Africa/Cairo' }).format(
    new Date()
  )
);
const targetForm = reactive({ agentId: '', messages: '', conversations: '' });

const agents = computed(() =>
  [...(report.value?.agents || [])].sort((a, b) => b.messages - a.messages)
);

const unrepliedChats = computed(
  () => report.value.chats.customer - report.value.chats.replied
);

const updatedAt = computed(() => {
  const timestamp = report.value?.updated_at;
  return timestamp
    ? new Date(timestamp).toLocaleTimeString(locale.value, {
        hour: '2-digit',
        minute: '2-digit',
      })
    : '—';
});

const formatReplyTime = seconds => {
  if (seconds == null) return '—';
  if (seconds < 60) return t('AGENT_PERFORMANCE.UNDER_A_MINUTE');
  const minutes = Math.round(seconds / 60);
  if (minutes < 60) return t('AGENT_PERFORMANCE.MINUTES', { value: minutes });
  return t('AGENT_PERFORMANCE.HOURS', { value: Math.round(minutes / 60) });
};

const targetClass = (actual, target) => {
  if (!target) return 'text-n-slate-11';
  return actual >= target ? 'text-n-teal-11' : 'text-n-ruby-11';
};

const loadReport = async () => {
  loading.value = true;
  try {
    const { data } = await AgentPerformanceAPI.getDaily({
      date: selectedDate.value,
    });
    report.value = data;
  } catch {
    useAlert(t('AGENT_PERFORMANCE.LOAD_ERROR'));
  } finally {
    loading.value = false;
  }
};

const saveTarget = (metric, targetValue) => {
  if (!targetValue) return null;
  return AgentPerformanceAPI.createTarget({
    user_id: targetForm.agentId || null,
    period_type: 'daily',
    metric,
    target_value: targetValue,
    effective_from: selectedDate.value,
  });
};

const saveTargets = async () => {
  saving.value = true;
  try {
    await Promise.all([
      saveTarget('customer_facing_messages', targetForm.messages),
      saveTarget('replied_conversations', targetForm.conversations),
    ]);
    useAlert(t('AGENT_PERFORMANCE.TARGETS_SAVED'));
    await loadReport();
  } catch {
    useAlert(t('AGENT_PERFORMANCE.TARGETS_ERROR'));
  } finally {
    saving.value = false;
  }
};

watch(selectedDate, loadReport);
onMounted(loadReport);
</script>

<template>
  <div dir="rtl" class="flex flex-col w-full h-full overflow-auto text-start">
    <ReportHeader
      :header-title="$t('AGENT_PERFORMANCE.HEADER')"
      :header-description="$t('AGENT_PERFORMANCE.DESCRIPTION')"
    />

    <div class="flex flex-wrap items-end gap-3 mb-5">
      <Input
        v-model="selectedDate"
        type="date"
        dir="ltr"
        class="max-w-48"
        :label="$t('AGENT_PERFORMANCE.DATE')"
      />
      <span class="pb-2 text-body-small text-n-slate-11">
        {{ $t('AGENT_PERFORMANCE.DATA_UPDATED', { time: updatedAt }) }}
      </span>
    </div>

    <div v-if="loading" class="py-20" data-testid="loading-state">
      <Spinner class="mx-auto" />
    </div>
    <template v-else-if="report">
      <p
        class="p-4 mb-4 rounded-xl bg-n-alpha-1 text-body-main text-n-slate-12"
        data-testid="chats-summary"
      >
        {{
          $t('AGENT_PERFORMANCE.CHATS_SUMMARY', {
            customer: report.chats.customer,
            replied: report.chats.replied,
          })
        }}
        <span
          class="font-medium"
          :class="unrepliedChats > 0 ? 'text-n-ruby-11' : 'text-n-teal-11'"
        >
          {{
            $t('AGENT_PERFORMANCE.CHATS_UNREPLIED', { count: unrepliedChats })
          }}
        </span>
      </p>

      <section
        class="mb-4 overflow-x-auto rounded-xl outline outline-1 outline-n-container"
      >
        <table class="w-full text-body-main" data-testid="agents-table">
          <thead>
            <tr class="text-label-small text-n-slate-11 bg-n-alpha-1">
              <th class="p-3 font-medium text-start">
                {{ $t('AGENT_PERFORMANCE.COLUMNS.AGENT') }}
              </th>
              <th class="p-3 font-medium text-start">
                {{ $t('AGENT_PERFORMANCE.COLUMNS.MESSAGES') }}
              </th>
              <th class="p-3 font-medium text-start">
                {{ $t('AGENT_PERFORMANCE.COLUMNS.CONVERSATIONS') }}
              </th>
              <th class="p-3 font-medium text-start">
                {{ $t('AGENT_PERFORMANCE.COLUMNS.ASSIGNED_CHATS') }}
              </th>
              <th class="p-3 font-medium text-start">
                {{ $t('AGENT_PERFORMANCE.COLUMNS.TYPICAL_REPLY') }}
              </th>
              <th class="p-3 font-medium text-start">
                {{
                  $t('AGENT_PERFORMANCE.COLUMNS.LATE_REPLIES', {
                    minutes: report.late_reply_minutes,
                  })
                }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="agent in agents"
              :key="agent.id"
              class="border-t border-n-weak"
            >
              <td class="p-3">
                <span class="flex items-center gap-2">
                  <Avatar :name="agent.name" :src="agent.thumbnail" :size="24" />
                  <span class="text-n-slate-12">{{ agent.name }}</span>
                </span>
              </td>
              <td class="p-3">
                <span
                  class="font-medium"
                  :class="targetClass(agent.messages, agent.targets.messages)"
                >
                  {{ agent.messages }}
                </span>
                <span
                  v-if="agent.targets.messages"
                  class="text-body-small text-n-slate-10 ms-1"
                >
                  {{
                    $t('AGENT_PERFORMANCE.OF_TARGET', {
                      target: agent.targets.messages,
                    })
                  }}
                </span>
              </td>
              <td class="p-3">
                <span
                  class="font-medium"
                  :class="
                    targetClass(agent.conversations, agent.targets.conversations)
                  "
                >
                  {{ agent.conversations }}
                </span>
                <span
                  v-if="agent.targets.conversations"
                  class="text-body-small text-n-slate-10 ms-1"
                >
                  {{
                    $t('AGENT_PERFORMANCE.OF_TARGET', {
                      target: agent.targets.conversations,
                    })
                  }}
                </span>
              </td>
              <td
                class="p-3 font-medium"
                :class="
                  agent.assigned_chats.replied < agent.assigned_chats.customer
                    ? 'text-n-ruby-11'
                    : 'text-n-slate-12'
                "
              >
                {{
                  agent.assigned_chats.customer
                    ? $t('AGENT_PERFORMANCE.REPLIED_OF_CHATS', {
                        replied: agent.assigned_chats.replied,
                        customer: agent.assigned_chats.customer,
                      })
                    : '—'
                }}
              </td>
              <td class="p-3 text-n-slate-12">
                {{ formatReplyTime(agent.typical_reply_seconds) }}
              </td>
              <td
                class="p-3 font-medium"
                :class="
                  agent.late_replies > 0 ? 'text-n-ruby-11' : 'text-n-slate-11'
                "
              >
                {{
                  agent.replies
                    ? $t('AGENT_PERFORMANCE.LATE_OF_REPLIES', {
                        late: agent.late_replies,
                        replies: agent.replies,
                      })
                    : '—'
                }}
              </td>
            </tr>
          </tbody>
        </table>
      </section>

      <ul
        class="flex flex-col gap-1 mb-8 text-body-small text-n-slate-11 list-disc ps-5"
      >
        <li>{{ $t('AGENT_PERFORMANCE.EXPLANATIONS.MESSAGES') }}</li>
        <li>{{ $t('AGENT_PERFORMANCE.EXPLANATIONS.CONVERSATIONS') }}</li>
        <li>{{ $t('AGENT_PERFORMANCE.EXPLANATIONS.ASSIGNED_CHATS') }}</li>
        <li>{{ $t('AGENT_PERFORMANCE.EXPLANATIONS.TYPICAL_REPLY') }}</li>
        <li>
          {{
            $t('AGENT_PERFORMANCE.EXPLANATIONS.LATE_REPLIES', {
              minutes: report.late_reply_minutes,
            })
          }}
        </li>
      </ul>

      <section
        class="p-4 mb-8 rounded-xl outline outline-1 outline-n-container"
      >
        <h3 class="mb-1 text-heading-2 text-n-slate-12">
          {{ $t('AGENT_PERFORMANCE.CONFIGURE_TARGETS') }}
        </h3>
        <p class="mb-4 text-body-small text-n-slate-11">
          {{ $t('AGENT_PERFORMANCE.TARGETS_HINT') }}
        </p>
        <div class="grid grid-cols-1 gap-3 md:grid-cols-3">
          <label class="flex flex-col gap-1 text-label-small text-n-slate-11">
            {{ $t('AGENT_PERFORMANCE.AGENT') }}
            <select
              v-model="targetForm.agentId"
              class="h-10 px-3 rounded-lg bg-n-alpha-2 text-n-slate-12 outline outline-1 outline-n-weak"
              :aria-label="$t('AGENT_PERFORMANCE.AGENT')"
            >
              <option value="">{{ $t('AGENT_PERFORMANCE.ALL_AGENTS') }}</option>
              <option v-for="agent in agents" :key="agent.id" :value="agent.id">
                {{ agent.name }}
              </option>
            </select>
          </label>
          <Input
            v-model="targetForm.messages"
            type="number"
            :label="$t('AGENT_PERFORMANCE.MESSAGES_TARGET')"
          />
          <Input
            v-model="targetForm.conversations"
            type="number"
            :label="$t('AGENT_PERFORMANCE.CONVERSATIONS_TARGET')"
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
