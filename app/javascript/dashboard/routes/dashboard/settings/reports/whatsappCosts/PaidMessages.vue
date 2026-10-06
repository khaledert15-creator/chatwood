<script setup>
import { computed, ref, onMounted, onBeforeUnmount, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import WhatsappCostsAPI from 'dashboard/api/whatsappCosts';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { formatCount } from './formatters';

const props = defineProps({
  month: { type: String, required: true },
  timezone: { type: String, required: true },
  phones: { type: Array, required: true },
  reportedPaidCount: { type: Number, required: true },
});
const { t, locale } = useI18n();
const route = useRoute();
const inboxId = ref('');
const classification = ref('paid');
const messages = ref([]);
const nextBeforeId = ref(null);
const loading = ref(false);
const loadError = ref(false);
const autoPickedUnknown = ref(false);
let controller;

const currentPaidCount = computed(() => {
  if (!inboxId.value) return props.reportedPaidCount;

  return (
    props.phones.find(phone => phone.inbox_id === Number(inboxId.value))
      ?.paid_volume ?? 0
  );
});
const classificationLabels = computed(() => ({
  paid: t('WHATSAPP_COSTS.MESSAGE_LIST.PAID'),
  unclassified: t('WHATSAPP_COSTS.MESSAGE_LIST.UNCLASSIFIED'),
}));
const count = value => formatCount(value, locale.value.replace('_', '-'));
const dateTime = value =>
  new Date(value).toLocaleString(locale.value.replace('_', '-'), {
    timeZone: props.timezone,
    numberingSystem: 'latn',
  });
const categoryLabel = category =>
  ({
    service: t('WHATSAPP_COSTS.CATEGORIES.SERVICE'),
    utility: t('WHATSAPP_COSTS.CATEGORIES.UTILITY'),
    marketing: t('WHATSAPP_COSTS.CATEGORIES.MARKETING'),
    authentication: t('WHATSAPP_COSTS.CATEGORIES.AUTHENTICATION'),
    authentication_international: t(
      'WHATSAPP_COSTS.CATEGORIES.AUTHENTICATION_INTERNATIONAL'
    ),
    ai_bot: t('WHATSAPP_COSTS.CATEGORIES.AI_BOT'),
  })[category.replace(/-/g, '_')] || category;

const loadMessages = async (beforeId = null) => {
  controller?.abort();
  const request = new AbortController();
  controller = request;
  loading.value = true;
  loadError.value = false;
  if (!beforeId) {
    messages.value = [];
    nextBeforeId.value = null;
  }
  try {
    const { data } = await WhatsappCostsAPI.getPaidMessages({
      month: props.month,
      timezone: props.timezone,
      classification: classification.value,
      inboxId: inboxId.value,
      beforeId,
      signal: request.signal,
    });
    if (request.signal.aborted) return;
    if (
      !beforeId &&
      classification.value === 'paid' &&
      !data.messages.length &&
      currentPaidCount.value > 0 &&
      !autoPickedUnknown.value
    ) {
      autoPickedUnknown.value = true;
      classification.value = 'unclassified';
      return;
    }
    messages.value = beforeId
      ? [...messages.value, ...data.messages]
      : data.messages;
    nextBeforeId.value = data.next_before_id;
  } catch {
    if (!request.signal.aborted) loadError.value = true;
  } finally {
    if (!request.signal.aborted) loading.value = false;
  }
};

watch([() => props.month, inboxId], () => {
  autoPickedUnknown.value = false;
  classification.value = 'paid';
});
watch([() => props.month, inboxId, classification], () => loadMessages());
onMounted(() => loadMessages());
onBeforeUnmount(() => controller?.abort());
</script>

<template>
  <section class="rounded-2xl border border-n-weak bg-n-solid-1 p-5 shadow-sm">
    <header class="mb-4 flex flex-wrap items-center justify-between gap-3">
      <div>
        <h2 class="m-0 text-base font-semibold text-n-slate-12">
          {{ t('WHATSAPP_COSTS.MESSAGE_LIST.TITLE') }}
        </h2>
        <p class="m-0 mt-1 text-xs text-n-slate-11">
          {{
            t('WHATSAPP_COSTS.MESSAGE_LIST.META_TOTAL', {
              count: count(currentPaidCount),
            })
          }}
        </p>
      </div>
      <label class="flex items-center gap-2 text-sm text-n-slate-11">
        {{ t('WHATSAPP_COSTS.MESSAGE_LIST.PHONE') }}
        <select
          v-model="inboxId"
          class="!m-0 !rounded-lg !border-n-weak !bg-n-alpha-1 !text-n-slate-12"
        >
          <option value="">
            {{ t('WHATSAPP_COSTS.MESSAGE_LIST.ALL_PHONES') }}
          </option>
          <option
            v-for="phone in phones.filter(
              item => item.error !== 'unsupported_provider'
            )"
            :key="phone.inbox_id"
            :value="phone.inbox_id"
          >
            {{ phone.name }}
          </option>
        </select>
      </label>
    </header>

    <div class="mb-4 flex flex-wrap gap-2">
      <button
        v-for="kind in ['paid', 'unclassified']"
        :key="kind"
        type="button"
        class="rounded-lg px-3 py-2 text-sm"
        :class="
          classification === kind
            ? 'bg-n-blue-9 text-white'
            : 'bg-n-alpha-1 text-n-slate-11'
        "
        :aria-pressed="classification === kind"
        @click="classification = kind"
      >
        {{ classificationLabels[kind] }}
      </button>
    </div>
    <p
      class="mb-4 rounded-lg bg-n-amber-2 p-3 text-sm leading-6 text-n-amber-11"
    >
      {{
        classification === 'paid'
          ? t('WHATSAPP_COSTS.MESSAGE_LIST.PAID_NOTE')
          : t('WHATSAPP_COSTS.MESSAGE_LIST.UNKNOWN_NOTE')
      }}
    </p>
    <div
      v-if="loading && !messages.length"
      role="status"
      class="flex items-center gap-2 py-8 text-sm text-n-slate-11"
    >
      <Spinner />{{ t('WHATSAPP_COSTS.LOADING') }}
    </div>
    <p
      v-else-if="loadError && !messages.length"
      role="alert"
      class="text-sm text-n-ruby-11"
    >
      {{ t('WHATSAPP_COSTS.MESSAGE_LIST.LOAD_ERROR') }}
    </p>
    <p
      v-else-if="!messages.length"
      class="py-6 text-center text-sm text-n-slate-11"
    >
      {{ t('WHATSAPP_COSTS.MESSAGE_LIST.EMPTY') }}
    </p>
    <div v-else class="divide-y divide-n-weak">
      <article
        v-for="message in messages"
        :key="message.id"
        class="flex flex-wrap items-start justify-between gap-3 py-4"
      >
        <div class="min-w-0 flex-1">
          <div class="flex flex-wrap items-center gap-x-3 gap-y-1">
            <strong class="text-sm text-n-slate-12">{{
              message.contact_name ||
              t('WHATSAPP_COSTS.MESSAGE_LIST.UNKNOWN_CONTACT')
            }}</strong>
            <span class="text-xs text-n-slate-11">{{
              message.inbox_name
            }}</span>
            <span
              v-if="message.category"
              class="rounded-full bg-n-alpha-1 px-2 py-0.5 text-xs text-n-slate-11"
            >
              {{ categoryLabel(message.category) }}
            </span>
          </div>
          <p
            class="mb-0 mt-2 line-clamp-2 break-words text-sm leading-6 text-n-slate-12"
            dir="auto"
          >
            {{ message.content || t('WHATSAPP_COSTS.MESSAGE_LIST.ATTACHMENT') }}
          </p>
          <span class="mt-1 block text-xs text-n-slate-11">{{
            dateTime(message.time)
          }}</span>
        </div>
        <router-link
          :to="{
            name: 'inbox_conversation',
            params: {
              accountId: route.params.accountId,
              conversation_id: message.conversation_id,
            },
          }"
          class="shrink-0 text-sm text-n-blue-11 underline underline-offset-2"
        >
          {{ t('WHATSAPP_COSTS.MESSAGE_LIST.OPEN_CONVERSATION') }}
        </router-link>
      </article>
    </div>
    <div
      v-if="nextBeforeId || (loadError && messages.length)"
      class="mt-4 flex justify-center"
    >
      <button
        type="button"
        class="rounded-lg border border-n-weak px-4 py-2 text-sm text-n-slate-12"
        :disabled="loading"
        @click="loadMessages(nextBeforeId)"
      >
        {{ t('WHATSAPP_COSTS.MESSAGE_LIST.LOAD_MORE') }}
      </button>
    </div>
  </section>
</template>
