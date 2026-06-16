<script setup>
import { computed, ref, onUnmounted } from 'vue';
import { useToggle } from '@vueuse/core';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { emitter } from 'shared/helpers/mitt';
import EmailTranscriptModal from './EmailTranscriptModal.vue';
import ResolveAction from '../../buttons/ResolveAction.vue';
import ButtonV4 from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import KanbanWonModal  from 'dashboard/routes/dashboard/kanban/components/KanbanWonModal.vue';
import KanbanLostModal from 'dashboard/routes/dashboard/kanban/components/KanbanLostModal.vue';

import {
  CMD_MUTE_CONVERSATION,
  CMD_SEND_TRANSCRIPT,
  CMD_UNMUTE_CONVERSATION,
} from 'dashboard/helper/commandbar/events';

// No props needed as we're getting currentChat from the store directly
const store = useStore();
const { t } = useI18n();

const [showEmailActionsModal, toggleEmailModal] = useToggle(false);
const [showActionsDropdown, toggleDropdown] = useToggle(false);

const currentChat = computed(() => store.getters.getSelectedChat);

// ── Kanban won/lost ──
const kanbanPlacements = computed(() => store.getters['kanbanPlacements/getPlacements']);
const kanbanFunnels    = computed(() => store.getters['kanbanPlacements/getFunnels']);

const firstPlacement = computed(() => kanbanPlacements.value[0] ?? null);
const firstFunnel    = computed(() =>
  firstPlacement.value
    ? kanbanFunnels.value.find(f => f.id === firstPlacement.value.funnel_id)
    : null
);
const wonStage  = computed(() => firstFunnel.value?.stages?.find(s => s.stage_type === 'won')  ?? null);
const lostStage = computed(() => firstFunnel.value?.stages?.find(s => s.stage_type === 'lost') ?? null);

const showWonModal   = ref(false);
const showLostModal  = ref(false);
const pendingStageId = ref(null);
const isMovingKanban = ref(false);

const conversationProxy = computed(() => ({
  id: currentChat.value?.id,
  meta: { sender: { name: firstPlacement.value?.conversation_label ?? '' } },
  additional_attributes: { deal_value: firstPlacement.value?.deal_value },
  custom_attributes: {},
}));

const doKanbanMove = async (stageId, extra = {}) => {
  if (!firstPlacement.value) return;
  isMovingKanban.value = true;
  try {
    await store.dispatch('kanbanStageItems/move', {
      funnelId: firstPlacement.value.funnel_id,
      conversationId: currentChat.value.id,
      stageId,
      ...extra,
    });
    await store.dispatch('kanbanPlacements/fetchForConversation', currentChat.value.id);
  } finally {
    isMovingKanban.value = false;
  }
};

const onWonClick = () => {
  if (!wonStage.value) return;
  pendingStageId.value = wonStage.value.id;
  showWonModal.value = true;
};
const onLostClick = () => {
  if (!lostStage.value) return;
  pendingStageId.value = lostStage.value.id;
  showLostModal.value = true;
};
const confirmWon  = p => { showWonModal.value  = false; doKanbanMove(pendingStageId.value, p); pendingStageId.value = null; };
const confirmLost = p => { showLostModal.value = false; doKanbanMove(pendingStageId.value, p); pendingStageId.value = null; };
const cancelModal = () => { showWonModal.value = showLostModal.value = false; pendingStageId.value = null; };

const actionMenuItems = computed(() => {
  const items = [];

  if (!currentChat.value.muted) {
    items.push({
      icon: 'i-lucide-volume-off',
      label: t('CONTACT_PANEL.MUTE_CONTACT'),
      action: 'mute',
      value: 'mute',
    });
  } else {
    items.push({
      icon: 'i-lucide-volume-1',
      label: t('CONTACT_PANEL.UNMUTE_CONTACT'),
      action: 'unmute',
      value: 'unmute',
    });
  }

  items.push({
    icon: 'i-lucide-share',
    label: t('CONTACT_PANEL.SEND_TRANSCRIPT'),
    action: 'send_transcript',
    value: 'send_transcript',
  });

  return items;
});

const handleActionClick = ({ action }) => {
  toggleDropdown(false);

  if (action === 'mute') {
    store.dispatch('muteConversation', currentChat.value.id);
    useAlert(t('CONTACT_PANEL.MUTED_SUCCESS'));
  } else if (action === 'unmute') {
    store.dispatch('unmuteConversation', currentChat.value.id);
    useAlert(t('CONTACT_PANEL.UNMUTED_SUCCESS'));
  } else if (action === 'send_transcript') {
    toggleEmailModal();
  }
};

// These functions are needed for the event listeners
const mute = () => {
  store.dispatch('muteConversation', currentChat.value.id);
  useAlert(t('CONTACT_PANEL.MUTED_SUCCESS'));
};

const unmute = () => {
  store.dispatch('unmuteConversation', currentChat.value.id);
  useAlert(t('CONTACT_PANEL.UNMUTED_SUCCESS'));
};

emitter.on(CMD_MUTE_CONVERSATION, mute);
emitter.on(CMD_UNMUTE_CONVERSATION, unmute);
emitter.on(CMD_SEND_TRANSCRIPT, toggleEmailModal);

onUnmounted(() => {
  emitter.off(CMD_MUTE_CONVERSATION, mute);
  emitter.off(CMD_UNMUTE_CONVERSATION, unmute);
  emitter.off(CMD_SEND_TRANSCRIPT, toggleEmailModal);
});
</script>

<template>
  <div class="relative flex items-center gap-2 actions--container">
    <!-- Kanban won/lost buttons — only shown when conversation is in a funnel -->
    <template v-if="firstPlacement && (wonStage || lostStage) && firstPlacement.stage_type !== 'won' && firstPlacement.stage_type !== 'lost'">
      <ButtonV4
        v-if="wonStage"
        label="Ganho"
        size="sm"
        color="slate"
        no-animation
        icon="i-lucide-trophy"
        :is-loading="isMovingKanban"
        class="shadow outline outline-1 outline-n-container rounded-lg"
        @click="onWonClick"
      />
      <ButtonV4
        v-if="lostStage"
        label="Perdido"
        size="sm"
        color="slate"
        no-animation
        icon="i-lucide-x-circle"
        :is-loading="isMovingKanban"
        class="shadow outline outline-1 outline-n-container rounded-lg"
        @click="onLostClick"
      />
    </template>

    <ResolveAction
      :conversation-id="currentChat.id"
      :status="currentChat.status"
    />
    <div
      v-on-clickaway="() => toggleDropdown(false)"
      class="relative flex items-center group"
    >
      <ButtonV4
        v-tooltip="$t('CONVERSATION.HEADER.MORE_ACTIONS')"
        size="sm"
        variant="ghost"
        color="slate"
        icon="i-lucide-more-vertical"
        class="rounded-md group-hover:bg-n-alpha-2"
        @click="toggleDropdown()"
      />
      <DropdownMenu
        v-if="showActionsDropdown"
        :menu-items="actionMenuItems"
        class="mt-1 ltr:right-0 rtl:left-0 top-full"
        @action="handleActionClick"
      />
    </div>
    <EmailTranscriptModal
      v-if="showEmailActionsModal"
      :show="showEmailActionsModal"
      :current-chat="currentChat"
      @cancel="toggleEmailModal"
    />

    <KanbanWonModal
      v-if="showWonModal"
      :conversation="conversationProxy"
      :stage-name="wonStage?.name || 'Venda Ganha'"
      @confirm="confirmWon"
      @cancel="cancelModal"
    />
    <KanbanLostModal
      v-if="showLostModal"
      :conversation="conversationProxy"
      :stage-name="lostStage?.name || 'Perdido'"
      @confirm="confirmLost"
      @cancel="cancelModal"
    />
  </div>
</template>

