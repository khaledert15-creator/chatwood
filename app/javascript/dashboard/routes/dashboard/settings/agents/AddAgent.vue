<script setup>
import { ref, computed } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useVuelidate } from '@vuelidate/core';
import {
  required,
  requiredIf,
  email,
  minLength,
  helpers,
} from '@vuelidate/validators';
import Button from 'dashboard/components-next/button/Button.vue';

const emit = defineEmits(['close']);

const store = useStore();
const { t } = useI18n();

const agentName = ref('');
const agentEmail = ref('');
const agentPhoneNumber = ref('');
const agentPassword = ref('');

// agents can be added with a mobile number only; they then log in with a password set here
const isPhoneOnly = computed(() => !agentEmail.value);
const selectedRoleId = ref('agent');

const rules = {
  agentName: { required },
  agentEmail: { required: requiredIf(() => !agentPhoneNumber.value), email },
  agentPhoneNumber: {
    required: requiredIf(() => !agentEmail.value),
    phoneNumber: helpers.regex(/^\+?[\d\s-]{6,20}$/),
  },
  agentPassword: {
    required: requiredIf(isPhoneOnly),
    minLength: minLength(6),
  },
  selectedRoleId: { required },
};

const v$ = useVuelidate(rules, {
  agentName,
  agentEmail,
  agentPhoneNumber,
  agentPassword,
  selectedRoleId,
});

const uiFlags = useMapGetter('agents/getUIFlags');
const getCustomRoles = useMapGetter('customRole/getCustomRoles');

const roles = computed(() => {
  const defaultRoles = [
    {
      id: 'administrator',
      name: 'administrator',
      label: t('AGENT_MGMT.AGENT_TYPES.ADMINISTRATOR'),
    },
    {
      id: 'agent',
      name: 'agent',
      label: t('AGENT_MGMT.AGENT_TYPES.AGENT'),
    },
  ];

  const customRoles = getCustomRoles.value.map(role => ({
    id: role.id,
    name: `custom_${role.id}`,
    label: role.name,
  }));

  return [...defaultRoles, ...customRoles];
});

const selectedRole = computed(() =>
  roles.value.find(
    role =>
      role.id === selectedRoleId.value || role.name === selectedRoleId.value
  )
);

const addAgent = async () => {
  v$.value.$touch();
  if (v$.value.$invalid) return;

  try {
    const payload = {
      name: agentName.value,
      email: agentEmail.value,
      phone_number: agentPhoneNumber.value,
    };
    if (isPhoneOnly.value) payload.password = agentPassword.value;

    if (selectedRole.value.name.startsWith('custom_')) {
      payload.custom_role_id = selectedRole.value.id;
    } else {
      payload.role = selectedRole.value.name;
    }

    await store.dispatch('agents/create', payload);
    useAlert(t('AGENT_MGMT.ADD.API.SUCCESS_MESSAGE'));
    emit('close');
  } catch (error) {
    const {
      response: {
        data: {
          error: errorResponse = '',
          attributes: attributes = [],
          message: attrError = '',
        } = {},
      } = {},
    } = error;

    let errorMessage = '';
    if (error?.response?.status === 422 && !attributes.includes('base')) {
      errorMessage = t('AGENT_MGMT.ADD.API.EXIST_MESSAGE');
    } else {
      errorMessage = t('AGENT_MGMT.ADD.API.ERROR_MESSAGE');
    }
    useAlert(errorResponse || attrError || errorMessage);
  }
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header
      :header-title="$t('AGENT_MGMT.ADD.TITLE')"
      :header-content="$t('AGENT_MGMT.ADD.DESC')"
    />
    <form class="flex flex-col items-start w-full" @submit.prevent="addAgent">
      <div class="w-full">
        <label :class="{ error: v$.agentName.$error }">
          {{ $t('AGENT_MGMT.ADD.FORM.NAME.LABEL') }}
          <input
            v-model="agentName"
            type="text"
            :placeholder="$t('AGENT_MGMT.ADD.FORM.NAME.PLACEHOLDER')"
            @input="v$.agentName.$touch"
          />
        </label>
      </div>

      <div class="w-full">
        <label :class="{ error: v$.selectedRoleId.$error }">
          {{ $t('AGENT_MGMT.ADD.FORM.AGENT_TYPE.LABEL') }}
          <select v-model="selectedRoleId" @change="v$.selectedRoleId.$touch">
            <option v-for="role in roles" :key="role.id" :value="role.id">
              {{ role.label }}
            </option>
          </select>
          <span v-if="v$.selectedRoleId.$error" class="message">
            {{ $t('AGENT_MGMT.ADD.FORM.AGENT_TYPE.ERROR') }}
          </span>
        </label>
      </div>

      <div class="w-full">
        <label :class="{ error: v$.agentEmail.$error }">
          {{ $t('AGENT_MGMT.ADD.FORM.EMAIL.LABEL') }}
          <input
            v-model="agentEmail"
            type="email"
            :placeholder="$t('AGENT_MGMT.ADD.FORM.EMAIL.PLACEHOLDER')"
            @input="v$.agentEmail.$touch"
          />
        </label>
      </div>

      <div class="w-full">
        <label :class="{ error: v$.agentPhoneNumber.$error }">
          {{ $t('AGENT_MGMT.ADD.FORM.PHONE_NUMBER.LABEL') }}
          <input
            v-model="agentPhoneNumber"
            type="tel"
            dir="ltr"
            :placeholder="$t('AGENT_MGMT.ADD.FORM.PHONE_NUMBER.PLACEHOLDER')"
            @input="v$.agentPhoneNumber.$touch"
          />
          <span v-if="v$.agentPhoneNumber.$error" class="message">
            {{ $t('AGENT_MGMT.ADD.FORM.PHONE_NUMBER.ERROR') }}
          </span>
        </label>
      </div>

      <div v-if="isPhoneOnly" class="w-full">
        <label :class="{ error: v$.agentPassword.$error }">
          {{ $t('AGENT_MGMT.ADD.FORM.PASSWORD.LABEL') }}
          <input
            v-model="agentPassword"
            type="password"
            autocomplete="new-password"
            :placeholder="$t('AGENT_MGMT.ADD.FORM.PASSWORD.PLACEHOLDER')"
            @input="v$.agentPassword.$touch"
          />
          <span class="message !text-n-slate-11">
            {{ $t('AGENT_MGMT.ADD.FORM.PASSWORD.HELP') }}
          </span>
        </label>
      </div>

      <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
        <Button
          faded
          slate
          type="reset"
          :label="$t('AGENT_MGMT.ADD.CANCEL_BUTTON_TEXT')"
          @click.prevent="emit('close')"
        />
        <Button
          type="submit"
          :label="$t('AGENT_MGMT.ADD.FORM.SUBMIT')"
          :disabled="v$.$invalid || uiFlags.isCreating"
          :is-loading="uiFlags.isCreating"
        />
      </div>
    </form>
  </div>
</template>
