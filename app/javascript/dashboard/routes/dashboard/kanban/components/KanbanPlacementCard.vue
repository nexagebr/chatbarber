<script setup>
/**
 * KanbanPlacementCard — shows one kanban placement (funnel + stage + CRM fields)
 * and allows changing stage / marking won/lost / removing from funnel.
 *
 * Used inside ConversationKanbanPanel and ContactKanbanPanel.
 *
 * Props:
 *   placement  — enriched object from kanban_placements API
 *                { id, funnel_id, funnel_name, conversation_id (display_id),
 *                  conversation_label, stage_id, stage_name, stage_color, stage_type,
 *                  deal_value, loss_reason, outcome_note, entered_at, outcome_at }
 *   funnels    — all funnels for this account (for the stage dropdown)
 *                [ { id, name, stages: [{ id, name, stage_type, color, position }] } ]
 *   conversation — the raw conversation object (needed by WonModal/LostModal for display)
 *                  if not available, a minimal proxy is built from placement fields.
 */
import { computed, ref, onUnmounted } from 'vue';
import { useStore } from 'vuex';
import Button from 'dashboard/components-next/button/Button.vue';
import KanbanWonModal from './KanbanWonModal.vue';
import KanbanLostModal from './KanbanLostModal.vue';

const props = defineProps({
  placement: { type: Object, required: true },
  funnels: { type: Array, default: () => [] },
  conversation: { type: Object, default: null },
});

const emit = defineEmits(['moved', 'removed']);

const store = useStore();
const showWonModal = ref(false);
const showLostModal = ref(false);
const pendingStageId = ref(null);
const isMoving = ref(false);

// The funnels list that matches this placement's funnel
const thisFunnel = computed(() =>
  props.funnels.find(f => f.id === props.placement.funnel_id)
);

// Stages of this funnel sorted by position
const stages = computed(() => {
  if (!thisFunnel.value) return [];
  return [...thisFunnel.value.stages].sort((a, b) => (a.position ?? 0) - (b.position ?? 0));
});

// Special stages
const wonStage = computed(() => stages.value.find(s => s.stage_type === 'won'));
const lostStage = computed(() => stages.value.find(s => s.stage_type === 'lost'));

// Minimal conversation proxy for modals when the full object isn't available
const conversationProxy = computed(() => {
  if (props.conversation) return props.conversation;
  return {
    id: props.placement.conversation_id,
    meta: { sender: { name: props.placement.conversation_label } },
    additional_attributes: { deal_value: props.placement.deal_value },
    custom_attributes: {},
  };
});

// --- Duration helper (same as KanbanCard) ---
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

const now = ref(Date.now());
const ticker = setInterval(() => { now.value = Date.now(); }, 60000);
onUnmounted(() => clearInterval(ticker));

const tempoEstagio = computed(() => {
  if (!props.placement.entered_at) return null;
  return formatDuration(now.value - new Date(props.placement.entered_at).getTime());
});

// --- Deal value formatting ---
const dealValueFormatted = computed(() => {
  const v = props.placement.deal_value;
  if (v == null) return null;
  return Number(v).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
});

// --- Stage type badge styling ---
const stageBadgeClass = computed(() => {
  switch (props.placement.stage_type) {
    case 'won': return 'bg-emerald-500/15 text-emerald-600 border-emerald-500/30';
    case 'lost': return 'bg-n-ruby-9/15 text-n-ruby-9 border-n-ruby-9/30';
    default: return 'bg-n-alpha-2 text-n-slate-11 border-n-weak';
  }
});

const stageIcon = computed(() => {
  if (props.placement.stage_type === 'won') return 'i-lucide-trophy';
  if (props.placement.stage_type === 'lost') return 'i-lucide-x-circle';
  return null;
});

// --- Move logic ---
const doMove = async (stageId, extra = {}) => {
  isMoving.value = true;
  try {
    await store.dispatch('kanbanStageItems/move', {
      funnelId: props.placement.funnel_id,
      conversationId: props.placement.conversation_id,
      stageId,
      dealValue: extra.dealValue ?? undefined,
      lossReason: extra.lossReason ?? undefined,
      outcomeNote: extra.outcomeNote ?? undefined,
    });
    // Re-fetch placements for this context so the widget updates
    emit('moved', { ...props.placement, stage_id: stageId, ...extra });
  } catch (e) {
    console.error('KanbanPlacementCard: move failed', e);
  } finally {
    isMoving.value = false;
  }
};

const onStageSelect = stageId => {
  const stage = stages.value.find(s => s.id === stageId);
  if (!stage) return;
  if (stage.stage_type === 'won') {
    pendingStageId.value = stageId;
    showWonModal.value = true;
  } else if (stage.stage_type === 'lost') {
    pendingStageId.value = stageId;
    showLostModal.value = true;
  } else {
    doMove(stageId);
  }
};

const confirmWon = ({ dealValue, outcomeNote }) => {
  showWonModal.value = false;
  doMove(pendingStageId.value, { dealValue, outcomeNote });
  pendingStageId.value = null;
};

const confirmLost = ({ lossReason, outcomeNote }) => {
  showLostModal.value = false;
  doMove(pendingStageId.value, { lossReason, outcomeNote });
  pendingStageId.value = null;
};

const cancelModal = () => {
  showWonModal.value = false;
  showLostModal.value = false;
  pendingStageId.value = null;
};

const removeFromFunnel = async () => {
  isMoving.value = true;
  try {
    await store.dispatch('kanbanStageItems/remove', {
      funnelId: props.placement.funnel_id,
      conversationId: props.placement.conversation_id,
    });
    store.dispatch('kanbanPlacements/removePlacement', {
      funnelId: props.placement.funnel_id,
      conversationDisplayId: props.placement.conversation_id,
    });
    emit('removed', props.placement);
  } catch (e) {
    console.error('KanbanPlacementCard: remove failed', e);
  } finally {
    isMoving.value = false;
  }
};

// Quick-mark buttons
const markWon = () => {
  if (!wonStage.value) return;
  pendingStageId.value = wonStage.value.id;
  showWonModal.value = true;
};

const markLost = () => {
  if (!lostStage.value) return;
  pendingStageId.value = lostStage.value.id;
  showLostModal.value = true;
};
</script>

<template>
  <div
    class="rounded-xl border p-3 space-y-2.5"
    :class="{
      'bg-emerald-500/5 border-emerald-500/30': placement.stage_type === 'won',
      'bg-n-ruby-9/5 border-n-ruby-9/30': placement.stage_type === 'lost',
      'bg-n-surface-2 border-n-weak': placement.stage_type === 'regular' || !placement.stage_type,
    }"
  >
    <!-- Funnel name -->
    <div class="flex items-center gap-1.5">
      <i class="i-lucide-git-branch text-n-slate-9 text-xs flex-shrink-0" />
      <span class="text-xs font-semibold text-n-slate-11 truncate">{{ placement.funnel_name }}</span>
    </div>

    <!-- Stage badge + selector -->
    <div class="flex items-center gap-2 flex-wrap">
      <!-- Current stage badge -->
      <span
        class="flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-semibold border"
        :class="stageBadgeClass"
      >
        <i v-if="stageIcon" :class="[stageIcon, 'text-[10px]']" />
        {{ placement.stage_name }}
      </span>

      <!-- Stage dropdown -->
      <select
        v-if="stages.length > 0"
        class="text-xs border border-n-weak bg-n-surface-1 text-n-slate-11 rounded-lg px-2 py-1 focus:outline-none focus:ring-1 focus:ring-n-brand cursor-pointer"
        :value="placement.stage_id"
        :disabled="isMoving"
        @change="onStageSelect(Number($event.target.value))"
      >
        <option
          v-for="stage in stages"
          :key="stage.id"
          :value="stage.id"
        >
          {{ stage.name }}
        </option>
      </select>
    </div>

    <!-- CRM fields -->
    <div class="space-y-1">
      <!-- Deal value -->
      <div v-if="dealValueFormatted" class="flex items-center gap-1.5 text-xs text-n-slate-11">
        <i class="i-lucide-circle-dollar-sign text-emerald-500 text-[11px]" />
        <span class="font-semibold text-n-slate-12">{{ dealValueFormatted }}</span>
      </div>

      <!-- Loss reason -->
      <div v-if="placement.loss_reason" class="flex items-center gap-1.5 text-xs text-n-slate-11">
        <i class="i-lucide-x-circle text-n-ruby-9 text-[11px]" />
        <span>{{ placement.loss_reason }}</span>
      </div>

      <!-- Outcome note -->
      <div v-if="placement.outcome_note" class="flex items-start gap-1.5 text-xs text-n-slate-11">
        <i class="i-lucide-file-text text-n-slate-9 text-[11px] mt-0.5 flex-shrink-0" />
        <span class="line-clamp-2">{{ placement.outcome_note }}</span>
      </div>

      <!-- Time in stage -->
      <div v-if="tempoEstagio" class="flex items-center gap-1.5 text-xs text-n-slate-9">
        <i class="i-lucide-timer text-[11px]" />
        <span>{{ tempoEstagio }} neste estágio</span>
      </div>
    </div>

    <!-- Action buttons -->
    <div class="flex items-center gap-1 flex-wrap pt-1 border-t border-n-weak/50">
      <button
        v-if="wonStage && placement.stage_type !== 'won'"
        class="flex items-center gap-1 px-2 py-1 rounded-lg text-[11px] font-semibold bg-emerald-500/10 text-emerald-600 hover:bg-emerald-500/20 transition-colors border border-emerald-500/20"
        :disabled="isMoving"
        @click="markWon"
      >
        <i class="i-lucide-trophy text-xs" />
        Ganho
      </button>
      <button
        v-if="lostStage && placement.stage_type !== 'lost'"
        class="flex items-center gap-1 px-2 py-1 rounded-lg text-[11px] font-semibold bg-n-ruby-9/10 text-n-ruby-9 hover:bg-n-ruby-9/20 transition-colors border border-n-ruby-9/20"
        :disabled="isMoving"
        @click="markLost"
      >
        <i class="i-lucide-x-circle text-xs" />
        Perdido
      </button>
      <button
        class="flex items-center gap-1 px-2 py-1 rounded-lg text-[11px] text-n-slate-9 hover:text-n-ruby-9 hover:bg-n-ruby-9/10 transition-colors border border-transparent hover:border-n-ruby-9/20 ml-auto"
        :disabled="isMoving"
        @click="removeFromFunnel"
      >
        <i class="i-lucide-trash-2 text-xs" />
        Remover
      </button>
    </div>
  </div>

  <!-- Won modal -->
  <KanbanWonModal
    v-if="showWonModal"
    :conversation="conversationProxy"
    :stage-name="wonStage?.name || 'Venda Ganha'"
    @confirm="confirmWon"
    @cancel="cancelModal"
  />

  <!-- Lost modal -->
  <KanbanLostModal
    v-if="showLostModal"
    :conversation="conversationProxy"
    :stage-name="lostStage?.name || 'Perdido'"
    @confirm="confirmLost"
    @cancel="cancelModal"
  />
</template>
