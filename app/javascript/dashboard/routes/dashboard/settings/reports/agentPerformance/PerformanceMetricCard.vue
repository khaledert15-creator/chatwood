<script setup>
defineProps({
  label: { type: String, required: true },
  value: { type: [String, Number], default: '—' },
  hint: { type: String, default: '' },
});
</script>

<template>
  <div
    class="flex flex-col gap-2 p-4 rounded-xl outline outline-1 outline-n-container bg-n-alpha-1"
  >
    <span class="text-label-small text-n-slate-11">{{ label }}</span>
    <span class="text-heading-1 text-n-slate-12">{{ value ?? '—' }}</span>
    <span v-if="hint" class="text-body-small text-n-slate-10">{{ hint }}</span>
  </div>
</template>
