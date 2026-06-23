<script setup>
/* eslint-disable vue/no-bare-strings-in-template */
import { ref, computed } from 'vue';
import TemplatesPicker from './TemplatesPicker.vue';
import WhatsAppTemplateReply from './WhatsAppTemplateReply.vue';
import WhatsAppTemplateCreateDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/WhatsAppCampaign/WhatsAppTemplateCreateDialog.vue';
import WhatsAppTemplatesListDialog from 'dashboard/components-next/Campaigns/Pages/CampaignPage/WhatsAppCampaign/WhatsAppTemplatesListDialog.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  show: { type: Boolean, default: false },
  inboxId: { type: Number, default: undefined },
});

const emit = defineEmits(['onSend', 'cancel', 'update:show']);

const tab = ref('send'); // 'send' | 'list' | 'create'
const selectedWaTemplate = ref(null);

const localShow = computed({
  get: () => props.show,
  set: value => emit('update:show', value),
});

const tabs = [
  { key: 'send', icon: 'i-lucide-send', label: 'Enviar' },
  { key: 'list', icon: 'i-lucide-list', label: 'Ver status' },
  { key: 'create', icon: 'i-lucide-layout-template', label: 'Novo template' },
];

const pickTemplate = template => {
  selectedWaTemplate.value = template;
};

const onResetTemplate = () => {
  selectedWaTemplate.value = null;
};

const onSendMessage = message => {
  emit('onSend', message);
};

const onClose = () => {
  emit('cancel');
};

const onTemplateCreated = () => {
  tab.value = 'send';
};
</script>

<template>
  <woot-modal v-model:show="localShow" :on-close="onClose" size="modal-big">
    <woot-modal-header
      header-title="Templates WhatsApp"
      :header-content="
        selectedWaTemplate
          ? selectedWaTemplate.name
          : tab === 'list'
            ? 'Status dos templates'
            : tab === 'create'
              ? 'Criar novo template'
              : 'Selecione um template para enviar'
      "
    />

    <!-- Tabs -->
    <div
      v-if="!selectedWaTemplate"
      class="flex gap-1 px-8 pb-3 border-b border-n-weak"
    >
      <button
        v-for="t in tabs"
        :key="t.key"
        type="button"
        class="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-sm transition-colors"
        :class="
          tab === t.key
            ? 'bg-n-brand/10 text-n-brand font-medium'
            : 'text-n-slate-9 hover:bg-n-alpha-2 hover:text-n-slate-12'
        "
        @click="tab = t.key"
      >
        <Icon :icon="t.icon" class="size-4" />
        {{ t.label }}
      </button>
    </div>

    <div class="row modal-content">
      <!-- Aba: Enviar template -->
      <template v-if="tab === 'send'">
        <TemplatesPicker
          v-if="!selectedWaTemplate"
          :inbox-id="inboxId"
          @on-select="pickTemplate"
        />
        <WhatsAppTemplateReply
          v-else
          :template="selectedWaTemplate"
          @reset-template="onResetTemplate"
          @send-message="onSendMessage"
        />
      </template>

      <!-- Aba: Ver status -->
      <template v-else-if="tab === 'list'">
        <WhatsAppTemplatesListDialog
          :inbox-id="inboxId"
          embedded
          @close="tab = 'send'"
        />
      </template>

      <!-- Aba: Novo template -->
      <template v-else-if="tab === 'create'">
        <WhatsAppTemplateCreateDialog
          :inbox-id="inboxId"
          embedded
          @close="tab = 'send'"
          @created="onTemplateCreated"
        />
      </template>
    </div>
  </woot-modal>
</template>

<style scoped>
.modal-content {
  padding: 1.5625rem 2rem;
}
</style>
