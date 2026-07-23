<script setup>
import { computed } from 'vue';
import { useMessageContext } from '../../provider.js';

import MessageFormatter from 'shared/helpers/MessageFormatter.js';
import { MESSAGE_VARIANTS } from '../../constants';

const props = defineProps({
  content: {
    type: String,
    required: true,
  },
});

const { variant } = useMessageContext();

const hasArabicContent = computed(() => /\p{Script=Arabic}/u.test(props.content));

const formattedContent = computed(() => {
  if (variant.value === MESSAGE_VARIANTS.ACTIVITY) {
    return props.content;
  }

  return new MessageFormatter(props.content).formattedMessage;
});
</script>

<template>
  <span
    v-dompurify-html="formattedContent"
    class="prose prose-bubble"
    :class="{
      'text-right leading-normal [&_li]:my-0 [&_p]:my-0 sm:leading-relaxed sm:[&_li]:my-0.5 sm:[&_p]:my-1 [&_p:first-child]:mt-0 [&_p:last-child]:mb-0':
        hasArabicContent,
    }"
    :dir="hasArabicContent ? 'rtl' : undefined"
  />
</template>
