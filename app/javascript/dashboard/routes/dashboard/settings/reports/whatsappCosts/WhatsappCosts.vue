<script setup>
import { computed, onMounted, onBeforeUnmount, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import WhatsappCostsAPI from 'dashboard/api/whatsappCosts';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { useAdmin } from 'dashboard/composables/useAdmin';
import PhoneCostCard from './PhoneCostCard.vue';
import PaidMessages from './PaidMessages.vue';
import { asNumber, convertCost, formatMoney, formatCount } from './formatters';

const { t, locale } = useI18n();
const { isAdmin } = useAdmin();
const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
const currentMonth = new Intl.DateTimeFormat('en-CA', {
  year: 'numeric',
  month: '2-digit',
  timeZone: timezone,
}).format(new Date());
const month = ref(currentMonth);
const report = ref(null);
const loading = ref(false);
const loadError = ref(false);
const manualRate = ref('');
const taxPercent = ref(14);
const showPaidMessages = ref(false);
let controller;
const numberLocale = computed(() => locale.value.replace('_', '-'));
const rate = computed(() => {
  const value = asNumber(
    manualRate.value === ''
      ? report.value?.exchange_rate?.usd_to_egp
      : manualRate.value
  );
  return value !== null && value > 0 ? value : null;
});
const tax = computed(() => {
  const value = asNumber(taxPercent.value);
  return value !== null && value >= 0 && value <= 100 ? value : null;
});
const usd = computed(() => asNumber(report.value?.totals?.cost_usd));
const egp = computed(() => convertCost(usd.value, rate.value));
const withTax = computed(() =>
  egp.value !== null && tax.value !== null
    ? egp.value * (1 + tax.value / 100)
    : null
);
const money = (value, currency = 'USD') =>
  formatMoney(value, currency, numberLocale.value, currency === 'EGP' ? 2 : 4);
const count = value => formatCount(value, numberLocale.value);
const dateTime = value =>
  value
    ? new Date(value).toLocaleString(numberLocale.value, {
        timeZone: timezone,
        numberingSystem: 'latn',
      })
    : '—';
const fetchedAt = computed(
  () =>
    report.value?.phones
      ?.filter(phone => phone.fetched_at)
      .map(phone => phone.fetched_at)
      .sort()[0]
);
const summaryCards = computed(() => [
  {
    label: t('WHATSAPP_COSTS.USD_COST'),
    value: money(usd.value),
    icon: 'i-lucide-dollar-sign',
  },
  {
    label: t('WHATSAPP_COSTS.EGP_COST'),
    value: money(egp.value, 'EGP'),
    icon: 'i-lucide-banknote',
  },
  {
    label: t('WHATSAPP_COSTS.WITH_TAX', { percent: tax.value ?? '—' }),
    value: money(withTax.value, 'EGP'),
    icon: 'i-lucide-receipt-text',
  },
  {
    label: t('WHATSAPP_COSTS.PAID_MESSAGES'),
    value: report.value?.totals?.available_phones
      ? count(report.value.totals.paid_volume)
      : '—',
    icon: 'i-lucide-message-circle',
  },
]);

const loadReport = async () => {
  controller?.abort();
  const request = new AbortController();
  controller = request;
  loading.value = true;
  loadError.value = false;
  report.value = null;
  try {
    const { data } = await WhatsappCostsAPI.getReport({
      month: month.value,
      timezone,
      signal: request.signal,
    });
    if (!request.signal.aborted) report.value = data;
  } catch {
    if (!request.signal.aborted) loadError.value = true;
  } finally {
    if (!request.signal.aborted) loading.value = false;
  }
};
watch(month, loadReport);
onMounted(loadReport);
onBeforeUnmount(() => controller?.abort());
</script>

<template>
  <section class="flex flex-col gap-5 py-7">
    <header class="flex flex-wrap items-start justify-between gap-4">
      <div>
        <h1 class="m-0 text-xl font-semibold text-n-slate-12">
          {{ t('WHATSAPP_COSTS.TITLE') }}
        </h1>
        <p class="m-0 mt-2 max-w-2xl text-sm leading-6 text-n-slate-11">
          {{ t('WHATSAPP_COSTS.DESCRIPTION') }}
        </p>
      </div>
      <span
        class="inline-flex items-center gap-1.5 rounded-lg bg-n-amber-2 px-3 py-2 text-xs text-n-amber-11"
      >
        <span class="i-lucide-clock-3 size-4" aria-hidden="true" />
        {{ t('WHATSAPP_COSTS.DELAY_NOTICE') }}
      </span>
    </header>

    <div class="rounded-2xl border border-n-weak bg-n-solid-1 p-5 shadow-sm">
      <div class="grid items-end gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <label class="flex flex-col gap-2 text-sm text-n-slate-11">
          {{ t('WHATSAPP_COSTS.MONTH') }}
          <input
            v-model="month"
            type="month"
            min="2025-07"
            :max="currentMonth"
            class="!m-0 !h-11 !rounded-xl !border-n-weak !bg-n-alpha-1 !text-n-slate-12"
          />
        </label>
        <label class="flex flex-col gap-2 text-sm text-n-slate-11">
          {{ t('WHATSAPP_COSTS.EXCHANGE_RATE') }}
          <input
            v-model="manualRate"
            type="number"
            step="0.0001"
            min="0.0001"
            :placeholder="String(report?.exchange_rate?.usd_to_egp ?? '')"
            class="!m-0 !h-11 !rounded-xl !border-n-weak !bg-n-alpha-1 !text-n-slate-12"
          />
        </label>
        <label class="flex flex-col gap-2 text-sm text-n-slate-11">
          {{ t('WHATSAPP_COSTS.TAX_RATE') }}
          <input
            v-model="taxPercent"
            type="number"
            step="0.1"
            min="0"
            max="100"
            class="!m-0 !h-11 !rounded-xl !border-n-weak !bg-n-alpha-1 !text-n-slate-12"
          />
        </label>
        <Button
          :label="t('WHATSAPP_COSTS.REFRESH')"
          icon="i-lucide-refresh-cw"
          :is-loading="loading"
          :disabled="loading"
          class="!h-11"
          @click="loadReport"
        />
      </div>
      <div
        class="mt-4 flex flex-wrap items-center gap-x-4 gap-y-2 text-xs leading-5 text-n-slate-11"
      >
        <span>{{ t('WHATSAPP_COSTS.TIMEZONE', { timezone }) }}</span>
        <template v-if="report?.exchange_rate?.updated_at">
          <a
            href="https://www.exchangerate-api.com"
            target="_blank"
            rel="noopener noreferrer"
            class="underline underline-offset-2"
          >
            {{ t('WHATSAPP_COSTS.FX_SOURCE') }}
          </a>
          <span>{{ dateTime(report.exchange_rate.updated_at) }}</span>
        </template>
        <span v-if="manualRate !== ''" class="text-n-amber-11">{{
          t('WHATSAPP_COSTS.MANUAL_RATE')
        }}</span>
        <button
          v-if="manualRate !== ''"
          type="button"
          class="text-n-blue-11 underline underline-offset-2"
          @click="manualRate = ''"
        >
          {{ t('WHATSAPP_COSTS.RESET_RATE') }}
        </button>
      </div>
      <p
        v-if="report && rate === null"
        role="alert"
        class="m-0 mt-3 text-sm text-n-amber-11"
      >
        {{ t('WHATSAPP_COSTS.FX_ERROR') }}
      </p>
      <p
        v-if="tax === null"
        role="alert"
        class="m-0 mt-3 text-sm text-n-amber-11"
      >
        {{ t('WHATSAPP_COSTS.INVALID_TAX') }}
      </p>
    </div>

    <div
      v-if="loading"
      role="status"
      class="flex items-center justify-center gap-3 rounded-2xl border border-n-weak bg-n-solid-1 p-14 text-sm text-n-slate-11"
    >
      <Spinner />{{ t('WHATSAPP_COSTS.LOADING') }}
    </div>
    <div
      v-else-if="loadError"
      role="alert"
      class="rounded-2xl border border-n-weak bg-n-solid-1 p-8 text-center text-n-ruby-11"
    >
      {{ t('WHATSAPP_COSTS.LOAD_ERROR') }}
    </div>
    <div
      v-else-if="report?.phones.length === 0"
      class="rounded-2xl border border-n-weak bg-n-solid-1 p-12 text-center text-n-slate-11"
    >
      {{ t('WHATSAPP_COSTS.NO_INBOXES') }}
    </div>
    <template v-else-if="report">
      <div
        v-if="!report.totals.complete"
        role="alert"
        class="rounded-xl bg-n-amber-2 p-4 text-sm text-n-amber-11"
      >
        {{ t('WHATSAPP_COSTS.PARTIAL_DATA') }}
      </div>
      <section
        class="rounded-2xl border border-n-weak bg-n-solid-1 p-5 shadow-sm"
      >
        <h2 class="m-0 mb-4 text-base font-semibold text-n-slate-12">
          {{ t('WHATSAPP_COSTS.MONTH_TOTAL') }}
        </h2>
        <div class="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
          <div
            v-for="card in summaryCards"
            :key="card.label"
            class="min-w-0 rounded-xl bg-n-alpha-1 p-4"
          >
            <div
              class="mb-3 flex items-center justify-between gap-2 text-xs text-n-slate-11"
            >
              <span>{{ card.label }}</span>
              <span
                :class="card.icon"
                class="size-4 shrink-0"
                aria-hidden="true"
              />
            </div>
            <strong
              class="block break-words text-2xl font-semibold tabular-nums text-n-slate-12"
            >
              {{ card.value }}
            </strong>
          </div>
        </div>
        <p class="m-0 mt-4 text-xs leading-5 text-n-slate-11">
          {{ t('WHATSAPP_COSTS.ESTIMATE_NOTICE') }}
        </p>
        <button
          v-if="isAdmin"
          type="button"
          class="mt-4 inline-flex items-center gap-2 rounded-lg border border-n-weak px-3 py-2 text-sm text-n-blue-11 hover:bg-n-alpha-1"
          :aria-expanded="showPaidMessages"
          @click="showPaidMessages = !showPaidMessages"
        >
          <span class="i-lucide-list-filter size-4" aria-hidden="true" />
          {{
            showPaidMessages
              ? t('WHATSAPP_COSTS.HIDE_PAID_MESSAGES')
              : t('WHATSAPP_COSTS.SHOW_PAID_MESSAGES')
          }}
        </button>
      </section>
      <PaidMessages
        v-if="showPaidMessages"
        :month="month"
        :timezone="timezone"
        :phones="report.phones"
        :reported-paid-count="report.totals.paid_volume"
      />
      <div class="grid gap-4 lg:grid-cols-2">
        <PhoneCostCard
          v-for="phone in report.phones"
          :key="phone.inbox_id"
          :phone="phone"
          :free-tier-limit="report.free_tier_limit"
          :exchange-rate="rate"
        />
      </div>
      <footer
        class="flex flex-col gap-2 rounded-xl border border-n-weak p-4 text-xs leading-6 text-n-slate-11"
      >
        <span>{{
          t('WHATSAPP_COSTS.FETCHED_AT', { time: dateTime(fetchedAt) })
        }}</span>
        <span>{{ t('WHATSAPP_COSTS.RULES_NOTICE') }}</span>
        <a
          href="https://whatsappbusiness.com/resources/faq/"
          target="_blank"
          rel="noopener noreferrer"
          class="w-fit text-n-blue-11 underline underline-offset-2"
        >
          {{ t('WHATSAPP_COSTS.META_RULES') }}
        </a>
      </footer>
    </template>
  </section>
</template>
