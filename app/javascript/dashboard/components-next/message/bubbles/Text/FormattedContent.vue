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
    dir="auto"
    class="prose prose-bubble !break-words text-start leading-[1.5] [&_p]:my-0 [&_p+p]:mt-2 [&_ul]:my-1 [&_ol]:my-1"
  />
</template>
