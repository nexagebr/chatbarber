<script setup>
import { computed, onUnmounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import ChannelIcon from 'dashboard/components-next/icon/ChannelIcon.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { useStore } from 'vuex';

const props = defineProps({
  conversation: {
    type: Object,
    required: true,
  },
  stageId: {
    type: [Number, String],
    default: null,
  },
  stageType: {
    type: String,
    default: 'regular', // 'regular' | 'won' | 'lost'
  },
});

const store = useStore();
const { t } = useI18n();

const inbox = computed(() => {
  const fromStore = store.getters['inboxes/getInbox'](props.conversation.inbox_id);
  if (fromStore) return fromStore;
  return {
    channel_type: props.conversation.meta?.channel,
    phone_number: props.conversation.meta?.sender?.phone_number,
  };
});

const emit = defineEmits(['open-conversation', 'open-contact', 'context-menu']);

// --- Status ---
const statusColor = computed(() => {
  switch (props.conversation.status) {
    case 'open': return 'bg-n-brand text-white';
    case 'resolved': return 'bg-n-slate-9 text-white';
    case 'pending': return 'bg-n-yellow-9 text-white';
    case 'snoozed': return 'bg-n-yellow-9 text-white';
    default: return 'bg-n-slate-3 text-n-slate-11';
  }
});

const statusLabel = computed(() =>
  t(`CONVERSATION.STATUS.${props.conversation.status.toUpperCase()}`) || props.conversation.status
);

// --- Priority ---
const priorityIcon = computed(() => {
  const p = props.conversation.priority;
  if (p === 'urgent') return { icon: 'i-lucide-alert-circle', color: 'text-n-ruby-9' };
  if (p === 'high') return { icon: 'i-lucide-arrow-up', color: 'text-n-ruby-9' };
  if (p === 'medium') return { icon: 'i-lucide-minus', color: 'text-n-yellow-9' };
  if (p === 'low') return { icon: 'i-lucide-arrow-down', color: 'text-n-slate-9' };
  return null;
});

// --- Duration helpers ---
function formatDuration(ms) {
  if (!ms || ms < 0) return '0min';
  const totalMinutes = Math.floor(ms / 60000);
  if (totalMinutes < 60) return `${totalMinutes}min`;
  const hours = Math.floor(totalMinutes / 60);
  const mins = totalMinutes % 60;
  if (hours < 24) return mins > 0 ? `${hours}h ${mins}min` : `${hours}h`;
  const days = Math.floor(hours / 24);
  const remHours = hours % 24;
  return remHours > 0 ? `${days}d ${remHours}h` : `${days}d`;
}

// Reactive "now" that ticks every minute so durations stay fresh
const now = ref(Date.now());
const ticker = setInterval(() => { now.value = Date.now(); }, 60000);
onUnmounted(() => clearInterval(ticker));

// Tempo aberto (since created_at)
const tempoAberto = computed(() => {
  const createdMs = (props.conversation.created_at || 0) * 1000;
  return formatDuration(now.value - createdMs);
});

// Tempo no estágio — reads from persisted kanban_stage_items (entered_at),
// falls back to localStorage for backward compat, then falls back to created_at
const stageItem = computed(() =>
  store.getters['kanbanStageItems/getStageItemByConversationId']?.(props.conversation.id)
);

const tempoEstagio = computed(() => {
  // Priority 1: server-persisted entered_at
  if (stageItem.value?.entered_at) {
    const enteredMs = new Date(stageItem.value.entered_at).getTime();
    return formatDuration(now.value - enteredMs);
  }
  // Priority 2: localStorage (legacy data before migration)
  try {
    const raw = localStorage.getItem(`kanban_stage_entered_${props.conversation.id}`);
    if (raw) {
      const { stageId, enteredAt } = JSON.parse(raw);
      if (stageId === props.stageId) {
        return formatDuration(now.value - enteredAt);
      }
    }
  } catch (_) { /* ignore */ }
  // Fallback: same as tempo aberto
  const createdMs = (props.conversation.created_at || 0) * 1000;
  return formatDuration(now.value - createdMs);
});

// --- Valor monetário ---
const dealValue = computed(() => {
  const v =
    props.conversation.additional_attributes?.deal_value ??
    props.conversation.custom_attributes?.deal_value ??
    null;
  if (v == null) return null;
  return Number(v).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
});

// --- Próxima atividade (snoozed_until) ---
const nextActivity = computed(() => {
  const ts = props.conversation.snoozed_until;
  if (!ts) return null;
  return new Date(ts * 1000).toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' });
});

// --- Etiquetas ---
const tags = computed(() => props.conversation.labels || []);
const tagTitle = tag => (typeof tag === 'string' ? tag : tag.title);

// --- Attachments ---
const attachmentsCount = computed(() => props.conversation.meta?.attachments_count || 0);
</script>

<template>
  <div
    class="group flex flex-col w-full rounded-xl border hover:shadow-md transition-all duration-200 p-3 select-none"
    :class="{
      'bg-amber-500/8 border-amber-400/30 hover:border-amber-400/60': stageType === 'won',
      'bg-n-ruby-9/5 border-n-ruby-9/20 hover:border-n-ruby-9/50': stageType === 'lost',
      'bg-n-surface-1 border-n-weak hover:border-n-brand/50': stageType === 'regular' || stageType === null,
    }"
  >
    <!-- Special stage badge -->
    <div v-if="stageType === 'won'" class="flex items-center gap-1 mb-2 text-amber-500 text-[10px] font-bold uppercase tracking-wide">
      <i class="i-lucide-trophy text-xs" /> Venda Ganha
    </div>
    <div v-else-if="stageType === 'lost'" class="flex items-center gap-1 mb-2 text-n-ruby-9 text-[10px] font-bold uppercase tracking-wide">
      <i class="i-lucide-x-circle text-xs" /> Perdido
    </div>
    <!-- Header: Avatar + Name + Status -->
    <div class="flex items-start justify-between mb-2">
      <div class="flex items-center gap-2 min-w-0">
        <Avatar
          :src="conversation.meta?.sender?.thumbnail"
          :username="conversation.meta?.sender?.name"
          :size="24"
          class="flex-shrink-0"
        />
        <div class="min-w-0 flex flex-col">
          <h4 class="text-sm font-semibold text-n-slate-12 truncate leading-tight">
            {{ conversation.meta?.sender?.name || t('KANBAN.FUNNEL.UNNAMED') }}
          </h4>
          <span class="text-[10px] text-n-slate-10 truncate">
            {{ new Date(conversation.created_at * 1000).toLocaleDateString('pt-BR') }}
          </span>
        </div>
      </div>
      <div
        class="px-1.5 py-0.5 rounded text-[10px] font-bold uppercase tracking-wider flex-shrink-0"
        :class="statusColor"
      >
        {{ statusLabel }}
      </div>
    </div>

    <!-- Tempo aberto / Tempo no estágio -->
    <div class="flex items-center gap-2 mb-2">
      <div class="flex items-center gap-1 text-[11px] text-n-slate-11 bg-n-alpha-2 rounded px-1.5 py-0.5">
        <i class="i-lucide-clock text-[10px]" />
        <span>{{ tempoAberto }} aberto</span>
      </div>
      <div class="flex items-center gap-1 text-[11px] text-n-slate-11 bg-n-alpha-2 rounded px-1.5 py-0.5">
        <i class="i-lucide-timer text-[10px]" />
        <span>{{ tempoEstagio }} estágio</span>
      </div>
    </div>

    <!-- Valor monetário -->
    <div class="flex items-center gap-1.5 mb-2 text-sm font-semibold text-n-slate-12">
      <i class="i-lucide-circle-dollar-sign text-n-slate-10 text-xs" />
      <span>{{ dealValue ?? 'R$ 0,00' }}</span>
    </div>

    <!-- Próxima atividade -->
    <div class="flex items-center gap-1.5 mb-2 text-xs text-n-slate-11">
      <i class="i-lucide-calendar text-[11px]" />
      <span>{{ nextActivity ?? '-' }}</span>
    </div>

    <!-- Canal + Prioridade + Anexos -->
    <div class="flex items-center gap-3 text-xs mb-2">
      <div class="flex items-center gap-1 text-n-slate-11 min-w-0 flex-1">
        <ChannelIcon :inbox="inbox" class="size-3" />
        <span class="truncate">{{ inbox.name }}</span>
      </div>
      <div class="flex items-center gap-2 flex-shrink-0">
        <div v-if="priorityIcon" :class="priorityIcon.color" :title="conversation.priority">
          <i :class="[priorityIcon.icon, 'text-xs']" />
        </div>
        <div v-if="attachmentsCount > 0" class="flex items-center gap-0.5 text-n-slate-10" title="Anexos">
          <i class="i-lucide-paperclip text-xs" />
          <span class="text-[10px]">{{ attachmentsCount }}</span>
        </div>
      </div>
    </div>

    <!-- Etiquetas -->
    <div class="border-t border-n-weak/50 pt-2 mb-2">
      <div v-if="tags.length" class="flex flex-wrap gap-1">
        <span
          v-for="tag in tags.slice(0, 3)"
          :key="tagTitle(tag)"
          class="px-1.5 py-0.5 rounded bg-n-alpha-2 text-n-slate-11 text-[10px] font-medium border border-n-weak truncate max-w-[90px]"
        >
          {{ tagTitle(tag) }}
        </span>
        <span v-if="tags.length > 3" class="px-1.5 py-0.5 text-[10px] text-n-slate-10">
          +{{ tags.length - 3 }}
        </span>
      </div>
      <span v-else class="text-[11px] text-n-slate-9 italic">Sem etiquetas</span>
    </div>

    <!-- Footer: Agente + Botões de navegação + Menu -->
    <div class="flex items-center justify-between pt-2 border-t border-n-weak/50 mt-auto">
      <!-- Agent avatar -->
      <div v-if="conversation.meta?.assignee" class="flex items-center gap-1.5">
        <Avatar
          :username="conversation.meta.assignee.name"
          :src="conversation.meta.assignee.thumbnail"
          :size="22"
        />
        <span class="text-xs font-medium text-n-slate-11 truncate max-w-[80px]">
          {{ conversation.meta.assignee.name }}
        </span>
      </div>
      <div v-else class="flex items-center gap-1.5">
        <div class="w-[22px] h-[22px] rounded-full bg-n-alpha-2 flex items-center justify-center border border-dashed border-n-weak">
          <i class="i-lucide-user-round text-n-slate-9 text-[10px]" />
        </div>
        <span class="text-[10px] text-n-slate-9 italic">Sem agente</span>
      </div>

      <!-- Navigation buttons + context menu -->
      <div class="flex items-center gap-1">
        <Button
          v-tooltip.bottom="'Conversa'"
          icon="i-lucide-message-square"
          variant="ghost"
          color="slate"
          size="xs"
          class="hover:bg-n-alpha-2 rounded-md"
          @click.stop="$emit('open-conversation', conversation)"
        />
        <Button
          v-tooltip.bottom="'Contato'"
          icon="i-lucide-user-round"
          variant="ghost"
          color="slate"
          size="xs"
          class="hover:bg-n-alpha-2 rounded-md"
          @click.stop="$emit('open-contact', conversation)"
        />
        <Button
          icon="i-lucide-more-vertical"
          variant="ghost"
          color="slate"
          size="xs"
          class="hover:bg-n-alpha-2 rounded-full"
          @click.stop="$emit('context-menu', $event, conversation)"
        />
      </div>
    </div>
  </div>
</template>
