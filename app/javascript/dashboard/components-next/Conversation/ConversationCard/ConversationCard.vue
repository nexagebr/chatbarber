<script setup>
import { computed, ref, onUnmounted } from 'vue';
import { getInboxIconByType } from 'dashboard/helper/inbox';
import { useRouter, useRoute } from 'vue-router';
import { useStore } from 'vuex';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper.js';
import { dynamicTime, shortTimestamp } from 'shared/helpers/timeHelper';

import Icon from 'dashboard/components-next/icon/Icon.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import CardMessagePreview from './CardMessagePreview.vue';
import CardMessagePreviewWithMeta from './CardMessagePreviewWithMeta.vue';
import CardPriorityIcon from './CardPriorityIcon.vue';

const props = defineProps({
  conversation: {
    type: Object,
    required: true,
  },
  contact: {
    type: Object,
    required: true,
  },
  stateInbox: {
    type: Object,
    required: true,
  },
  accountLabels: {
    type: Array,
    required: true,
  },
});

const router = useRouter();
const route = useRoute();
const store = useStore();

const cardMessagePreviewWithMetaRef = ref(null);

const currentContact = computed(() => props.contact);

const currentContactName = computed(() => currentContact.value?.name);
const currentContactThumbnail = computed(() => currentContact.value?.thumbnail);
const currentContactStatus = computed(
  () => currentContact.value?.availabilityStatus
);

const inbox = computed(() => props.stateInbox);

const inboxName = computed(() => inbox.value?.name);

const kanbanFunnelName = computed(() =>
  store.getters['kanbanPlacements/getFunnelNameForConversation'](props.conversation.id)
);

const inboxIcon = computed(() => {
  const { channelType, medium } = inbox.value;
  return getInboxIconByType(channelType, medium);
});

const lastActivityAt = computed(() => {
  const timestamp = props.conversation?.timestamp;
  return timestamp ? shortTimestamp(dynamicTime(timestamp)) : '';
});

// ── WhatsApp 24h window indicator ────────────────────────────────────────────
const now = ref(Date.now());
const ticker = setInterval(() => { now.value = Date.now(); }, 60000);
onUnmounted(() => clearInterval(ticker));

const isWhatsappInbox = computed(() =>
  props.stateInbox?.channelType === 'Channel::Whatsapp'
);

const windowInfo = computed(() => {
  if (!isWhatsappInbox.value) return null;

  const canReply = props.conversation?.can_reply;
  const lastTs = (props.conversation?.timestamp || 0) * 1000;
  const expiry = lastTs + 24 * 60 * 60 * 1000;
  const remaining = expiry - now.value;

  if (!canReply || remaining <= 0) {
    return { status: 'closed', label: 'Janela fechada', color: 'closed' };
  }

  const hours = Math.floor(remaining / 3600000);
  const mins = Math.floor((remaining % 3600000) / 60000);
  const timeLabel = hours > 0 ? `${hours}h restantes` : `${mins}min restantes`;

  if (remaining < 2 * 3600000) {
    return { status: 'urgent', label: timeLabel, color: 'urgent' };
  }
  if (remaining < 6 * 3600000) {
    return { status: 'warning', label: timeLabel, color: 'warning' };
  }
  return { status: 'open', label: timeLabel, color: 'open' };
});

const showMessagePreviewWithoutMeta = computed(() => {
  const { labels = [] } = props.conversation;
  return (
    !cardMessagePreviewWithMetaRef.value?.hasSlaThreshold && labels.length === 0
  );
});

const onCardClick = e => {
  const path = frontendURL(
    conversationUrl({
      accountId: route.params.accountId,
      id: props.conversation.id,
    })
  );

  if (e.metaKey || e.ctrlKey) {
    window.open(
      window.chatwootConfig.hostURL + path,
      '_blank',
      'noopener noreferrer nofollow'
    );
    return;
  }
  router.push({ path });
};
</script>

<template>
  <div
    role="button"
    class="flex w-full gap-3 px-3 py-4 transition-all duration-300 ease-in-out cursor-pointer"
    @click="onCardClick"
  >
    <Avatar
      :name="currentContactName"
      :src="currentContactThumbnail"
      :size="24"
      :status="currentContactStatus"
      rounded-full
    />
    <div class="flex flex-col w-full gap-1 min-w-0">
      <div class="flex items-center justify-between h-6 gap-2">
        <div class="flex items-center gap-1.5 min-w-0">
          <h4 class="text-base font-medium truncate text-n-slate-12">
            {{ currentContactName }}
          </h4>
          <span
            v-if="kanbanFunnelName"
            class="inline-flex items-center gap-1 flex-shrink-0 px-1.5 py-0.5 rounded-full text-[10px] font-semibold"
            style="background: color-mix(in srgb, rgb(var(--n-brand)) 10%, transparent); color: rgb(var(--n-brand));"
          >
            <i class="i-lucide-git-branch-plus" style="font-size:9px" />
            {{ kanbanFunnelName }}
          </span>
        </div>
        <div class="flex items-center gap-2 flex-shrink-0">
          <CardPriorityIcon :priority="conversation.priority || null" />
          <div
            v-tooltip.left="inboxName"
            class="flex items-center justify-center flex-shrink-0 rounded-full bg-n-alpha-2 size-5"
          >
            <Icon
              :icon="inboxIcon"
              class="flex-shrink-0 text-n-slate-11 size-3"
            />
          </div>
          <span class="text-sm text-n-slate-10">
            {{ lastActivityAt }}
          </span>
        </div>
      </div>
      <CardMessagePreview
        v-show="showMessagePreviewWithoutMeta"
        :conversation="conversation"
      />
      <CardMessagePreviewWithMeta
        v-show="!showMessagePreviewWithoutMeta"
        ref="cardMessagePreviewWithMetaRef"
        :conversation="conversation"
        :account-labels="accountLabels"
      />
      <div
        v-if="windowInfo"
        class="wa-window-badge"
        :class="`wa-window-badge--${windowInfo.color}`"
      >
        <span
          class="wa-window-dot"
          :class="`wa-window-dot--${windowInfo.color}`"
        />
        {{ windowInfo.label }}
      </div>
    </div>
  </div>
</template>

<style scoped>
.wa-window-badge {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 2px 7px;
  border-radius: 20px;
  font-size: 10px;
  font-weight: 600;
  width: fit-content;
  letter-spacing: .01em;
}
.wa-window-badge--open    { background: rgba(34,197,94,.12);  color: #16a34a; }
.wa-window-badge--warning { background: rgba(234,179,8,.14);  color: #a16207; }
.wa-window-badge--urgent  { background: rgba(239,68,68,.13);  color: #dc2626; }
.wa-window-badge--closed  { background: rgba(148,163,184,.1); color: #64748b; }

.wa-window-dot {
  width: 5px; height: 5px;
  border-radius: 50%;
  flex-shrink: 0;
}
.wa-window-dot--open    { background: #16a34a; }
.wa-window-dot--warning { background: #ca8a04; animation: wa-pulse 1.5s infinite; }
.wa-window-dot--urgent  { background: #dc2626; animation: wa-pulse 1s infinite; }
.wa-window-dot--closed  { background: #94a3b8; }

@keyframes wa-pulse {
  0%, 100% { opacity: 1; }
  50%       { opacity: .35; }
}
</style>
