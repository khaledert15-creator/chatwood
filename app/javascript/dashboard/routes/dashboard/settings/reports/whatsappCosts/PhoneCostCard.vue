<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { convertCost, formatMoney, formatCount } from './formatters';

const props = defineProps({
  phone: { type: Object, required: true },
  freeTierLimit: { type: Number, default: null },
  exchangeRate: { type: Number, default: null },
});
const { t, te, locale } = useI18n();
const money = (value, currency = props.phone.currency) =>
  formatMoney(
    value,
    currency,
    locale.value.replace('_', '-'),
    currency === 'EGP' ? 2 : 4
  );
const count = value => formatCount(value, locale.value.replace('_', '-'));
const unavailable = '—';
const categoryRows = computed(() => {
  const standard = ['SERVICE', 'UTILITY', 'MARKETING', 'AUTHENTICATION'];
  const names = [
    ...new Set([
      ...standard,
      ...(props.phone.categories || []).map(row => row.category),
    ]),
  ];
  return names.map(category => {
    const row = props.phone.categories?.find(
      item => item.category === category
    );
    return row || { category, paid_volume: 0, free_volume: 0, cost: 0 };
  });
});
const categoryLabel = category => {
  const key = `WHATSAPP_COSTS.CATEGORIES.${category}`;
  return te(key) ? t(key) : category;
};
const errorLabel = computed(() => {
  const key = `WHATSAPP_COSTS.ERRORS.${props.phone.error}`;
  return te(key) ? t(key) : t('WHATSAPP_COSTS.ERRORS.meta_error');
});
</script>

<template>
  <article class="rounded-2xl border border-n-weak bg-n-solid-1 p-5 shadow-sm">
    <header class="mb-5 flex flex-wrap items-start justify-between gap-2">
      <div class="min-w-0">
        <h3 class="m-0 break-words text-base font-semibold text-n-slate-12">
          {{ phone.name }}
        </h3>
        <p class="m-0 mt-1 text-sm text-n-slate-11">
          <bdi dir="ltr">{{ phone.phone_number }}</bdi>
        </p>
      </div>
      <span
        class="rounded-full bg-n-alpha-1 px-2.5 py-1 text-xs text-n-slate-11"
      >
        {{ t('WHATSAPP_COSTS.META_SOURCE') }}
      </span>
    </header>

    <div
      v-if="!phone.available"
      role="alert"
      class="rounded-xl bg-n-amber-2 p-4 text-sm leading-6 text-n-amber-11"
    >
      {{ errorLabel }}
      <span v-if="phone.error_code">{{
        t('WHATSAPP_COSTS.ERROR_CODE', { code: phone.error_code })
      }}</span>
    </div>
    <template v-else>
      <div v-if="freeTierLimit !== null" class="mb-5">
        <div class="mb-2 flex items-center justify-between gap-2 text-sm">
          <span class="text-n-slate-11">{{
            t('WHATSAPP_COSTS.FREE_USED')
          }}</span>
          <bdi
            dir="ltr"
            class="shrink-0 whitespace-nowrap font-semibold tabular-nums"
            :class="
              phone.free_remaining === 0 ? 'text-n-ruby-10' : 'text-n-teal-11'
            "
          >
            {{
              t('WHATSAPP_COSTS.QUOTA_USAGE', {
                used: count(phone.free_used),
                limit: count(freeTierLimit),
              })
            }}
          </bdi>
        </div>
        <div
          class="flex h-2 gap-0.5 overflow-hidden rounded-full bg-n-alpha-1"
          role="progressbar"
          :aria-label="t('WHATSAPP_COSTS.FREE_USED')"
          :aria-valuenow="phone.free_used"
          :aria-valuemin="0"
          :aria-valuemax="freeTierLimit"
        >
          <span
            v-for="segment in 20"
            :key="segment"
            class="h-full flex-1"
            :class="
              segment <= Math.ceil((phone.free_used / freeTierLimit) * 20)
                ? phone.free_remaining === 0
                  ? 'bg-n-ruby-9'
                  : 'bg-n-teal-9'
                : 'bg-transparent'
            "
          />
        </div>
      </div>
      <p
        v-else
        class="mb-5 rounded-lg bg-n-teal-2 p-3 text-xs leading-5 text-n-teal-11"
      >
        {{ t('WHATSAPP_COSTS.HISTORICAL_FREE') }}
      </p>

      <div class="mb-5 grid grid-cols-2 gap-2 sm:grid-cols-3">
        <div class="rounded-xl bg-n-alpha-1 p-3">
          <p class="m-0 mb-2 text-xs text-n-slate-11">
            {{ t('WHATSAPP_COSTS.FREE_REMAINING') }}
          </p>
          <strong class="text-lg tabular-nums text-n-slate-12">{{
            freeTierLimit === null ? unavailable : count(phone.free_remaining)
          }}</strong>
        </div>
        <div class="rounded-xl bg-n-alpha-1 p-3">
          <p class="m-0 mb-2 text-xs text-n-slate-11">
            {{ t('WHATSAPP_COSTS.FREE_ENTRY') }}
          </p>
          <strong class="text-lg tabular-nums text-n-slate-12">{{
            count(phone.free_entry_point_volume)
          }}</strong>
        </div>
        <div class="col-span-2 rounded-xl bg-n-alpha-1 p-3 sm:col-span-1">
          <p class="m-0 mb-2 text-xs text-n-slate-11">
            {{ t('WHATSAPP_COSTS.COST') }}
          </p>
          <strong
            class="block break-words text-base tabular-nums text-n-slate-12"
          >
            {{ money(phone.cost) }}
          </strong>
          <span class="mt-1 block text-xs tabular-nums text-n-slate-11">{{
            money(convertCost(phone.cost_usd, exchangeRate), 'EGP')
          }}</span>
        </div>
      </div>

      <div
        v-if="phone.volume === 0"
        class="mb-3 text-xs leading-5 text-n-slate-11"
      >
        {{ t('WHATSAPP_COSTS.NO_REPORTED_MESSAGES') }}
      </div>
      <div
        v-if="phone.unclassified_volume"
        class="mb-3 text-xs text-n-amber-11"
      >
        {{
          t('WHATSAPP_COSTS.UNCLASSIFIED', {
            count: count(phone.unclassified_volume),
          })
        }}
      </div>
      <div class="overflow-x-auto">
        <table class="w-full text-start text-sm">
          <thead class="text-xs font-normal text-n-slate-11">
            <tr>
              <th class="pb-3 text-start font-normal">
                {{ t('WHATSAPP_COSTS.MESSAGE_TYPE') }}
              </th>
              <th class="pb-3 text-end font-normal">
                {{ t('WHATSAPP_COSTS.PAID') }}
              </th>
              <th class="pb-3 text-end font-normal">
                {{ t('WHATSAPP_COSTS.FREE') }}
              </th>
              <th class="pb-3 text-end font-normal">
                {{ t('WHATSAPP_COSTS.COST') }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="row in categoryRows"
              :key="row.category"
              class="border-t border-n-weak"
            >
              <td class="py-3 pe-2 text-n-slate-12">
                {{ categoryLabel(row.category) }}
              </td>
              <td class="py-3 ps-2 text-end tabular-nums text-n-slate-11">
                {{ count(row.paid_volume) }}
              </td>
              <td class="py-3 ps-2 text-end tabular-nums text-n-slate-11">
                {{ count(row.free_volume) }}
              </td>
              <td
                class="whitespace-nowrap py-3 ps-2 text-end tabular-nums text-n-slate-12"
              >
                {{ money(row.cost) }}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <p class="m-0 mt-3 border-t border-n-weak pt-3 text-xs text-n-slate-11">
        {{
          t('WHATSAPP_COSTS.REPORTED_VOLUME', { count: count(phone.volume) })
        }}
      </p>
    </template>
  </article>
</template>
