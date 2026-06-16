<script setup>
import { computed, ref, watch, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useRouter } from 'vue-router';
import { useAccount } from 'dashboard/composables/useAccount';
import KanbanWonModal  from 'dashboard/routes/dashboard/kanban/components/KanbanWonModal.vue';
import KanbanLostModal from 'dashboard/routes/dashboard/kanban/components/KanbanLostModal.vue';

const props = defineProps({
  contactId: { type: [Number, String], required: true },
});

const store = useStore();
const router = useRouter();
const { accountId } = useAccount();

const uiFlags     = computed(() => store.getters['kanbanPlacements/getUIFlags']);
const allPlacements = computed(() => store.getters['kanbanPlacements/getPlacements']);
const funnels     = computed(() => store.getters['kanbanPlacements/getFunnels']);
const isFetching  = computed(() => uiFlags.value.isFetching);

// ── per-conversation entry ──────────────────────────────────────────
const entries = computed(() => {
  return allPlacements.value.map(p => {
    const funnel = funnels.value.find(f => f.id === p.funnel_id);
    const stages = funnel
      ? [...funnel.stages].sort((a, b) => (a.position ?? 0) - (b.position ?? 0))
      : [];
    const regular = stages.filter(s => !s.stage_type || s.stage_type === 'regular');
    const currentIdx = regular.findIndex(s => s.id === p.stage_id);
    const dealValue = p.deal_value
      ? Number(p.deal_value).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL', maximumFractionDigits: 0 })
      : null;

    return { placement: p, funnel, regular, stages, currentIdx, dealValue };
  });
});

// ── modals ──────────────────────────────────────────────────────────
const showWonModal   = ref(false);
const showLostModal  = ref(false);
const pendingMove    = ref(null); // { funnelId, conversationId, stageId, stage }
const isMoving       = ref(false);

const wonStageFor  = entry => entry.stages.find(s => s.stage_type === 'won');
const lostStageFor = entry => entry.stages.find(s => s.stage_type === 'lost');

const onStageClick = (entry, stage) => {
  if (isMoving.value) return;
  if (stage.id === entry.placement.stage_id) return;
  const { funnel_id: funnelId, conversation_id: conversationId, stage_name: fromStageName, funnel_name: funnelName } = entry.placement;
  const meta = { _fromStageName: fromStageName, _toStageName: stage.name, _funnelName: funnelName };
  if (stage.stage_type === 'won') {
    pendingMove.value = { funnelId, conversationId, stageId: stage.id, ...meta };
    showWonModal.value = true;
    return;
  }
  if (stage.stage_type === 'lost') {
    pendingMove.value = { funnelId, conversationId, stageId: stage.id, ...meta };
    showLostModal.value = true;
    return;
  }
  doMove({ funnelId, conversationId, stageId: stage.id, ...meta });
};

const doMove = async ({ funnelId, conversationId, stageId, dealValue, lossReason, outcomeNote, _fromStageName, _toStageName, _funnelName } = {}) => {
  isMoving.value = true;
  try {
    await store.dispatch('kanbanStageItems/move', { funnelId, conversationId, stageId, dealValue, lossReason, outcomeNote });
    if (_toStageName && props.contactId) {
      const parts = [];
      if (_fromStageName && _fromStageName !== _toStageName) {
        parts.push(`📊 Funil ${_funnelName || ''}: ${_fromStageName} → ${_toStageName}`);
      } else {
        parts.push(`📊 Funil ${_funnelName || ''}: movido para ${_toStageName}`);
      }
      if (lossReason) parts.push(`Motivo: ${lossReason}`);
      if (outcomeNote) parts.push(outcomeNote);
      store.dispatch('contactNotes/create', { contactId: props.contactId, content: parts.join(' · ') });
    }
    await fetchPlacements();
  } finally { isMoving.value = false; }
};

const confirmWon = params => {
  showWonModal.value = false;
  if (pendingMove.value) doMove({ ...pendingMove.value, ...params });
  pendingMove.value = null;
};
const confirmLost = params => {
  showLostModal.value = false;
  if (pendingMove.value) doMove({ ...pendingMove.value, ...params });
  pendingMove.value = null;
};
const cancelModal = () => {
  showWonModal.value = showLostModal.value = false;
  pendingMove.value = null;
};

// ── proxy conversation for modals ───────────────────────────────────
const modalConversation = computed(() => {
  const p = pendingMove.value;
  if (!p) return {};
  const placement = allPlacements.value.find(pl => pl.conversation_id === p.conversationId && pl.funnel_id === p.funnelId);
  return { id: p.conversationId, meta: { sender: { name: placement?.conversation_label } }, additional_attributes: { deal_value: placement?.deal_value }, custom_attributes: {} };
});

const pendingEntry = computed(() => {
  if (!pendingMove.value) return null;
  return entries.value.find(e => e.placement.conversation_id === pendingMove.value?.conversationId);
});

// ── data fetching ────────────────────────────────────────────────────
const fetchPlacements = () => store.dispatch('kanbanPlacements/fetchForContact', props.contactId);

watch(() => props.contactId, v => { if (v) fetchPlacements(); });
onMounted(() => { fetchPlacements(); store.dispatch('kanbanLossReasons/get'); });

const openConversation = id => {
  router.push({ name: 'inbox_conversation', params: { accountId: accountId.value, conversation_id: id } });
};
</script>

<template>
  <div class="flex flex-col gap-0 border border-n-weak rounded-xl overflow-hidden" :class="{ 'opacity-60 pointer-events-none': isMoving }">

    <!-- section header -->
    <div class="flex items-center gap-2 px-4 py-2.5 border-b border-n-weak bg-n-alpha-black2">
      <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" style="color:rgb(var(--n-brand))"><polygon points="22 3 2 3 10 12.46 10 19 14 21 14 12.46 22 3"/></svg>
      <span class="text-xs font-semibold text-n-slate-11">Funis</span>
    </div>

    <!-- loading -->
    <div v-if="isFetching" class="flex items-center justify-center py-10 text-n-slate-9">
      <i class="i-lucide-loader-2 animate-spin text-2xl" />
    </div>

    <!-- empty -->
    <div v-else-if="entries.length === 0" class="flex flex-col items-center justify-center py-6 text-n-slate-9 gap-3 px-4">
      <i class="i-lucide-git-branch text-3xl opacity-30" />
      <p class="text-sm text-center font-medium">Nenhuma conversa em funis</p>
    </div>

    <!-- one bar per conversation -->
    <div
      v-for="entry in entries"
      :key="`${entry.placement.funnel_id}-${entry.placement.conversation_id}`"
      class="border-b border-n-weak last:border-0"
    >
      <!-- conversation label row -->
      <div class="flex items-center gap-2 px-4 pt-3 pb-1">
        <i class="i-lucide-message-square text-n-slate-8 text-xs flex-shrink-0" />
        <span class="text-xs text-n-slate-10 truncate flex-1">
          {{ entry.placement.conversation_label || `Conversa` }}
          <span class="text-n-slate-8">#{{ entry.placement.conversation_id }}</span>
        </span>
        <button
          class="flex items-center gap-0.5 text-[11px] text-n-brand hover:underline flex-shrink-0"
          @click="openConversation(entry.placement.conversation_id)"
        >
          <i class="i-lucide-external-link text-[10px]" />
          Abrir
        </button>
      </div>

      <!-- pipeline bar -->
      <div class="ckb-bar px-3 pb-3">
        <!-- pipeline steps -->
        <div class="ckb-pipeline">
          <button
            v-for="(stage, idx) in entry.regular"
            :key="stage.id"
            class="ckb-step"
            :class="{
              'ckb-step--reached': idx <= entry.currentIdx,
              'ckb-step--current': idx === entry.currentIdx,
              'ckb-step--future':  idx > entry.currentIdx,
              'ckb-step--first':   idx === 0,
              'ckb-step--last':    idx === entry.regular.length - 1,
            }"
            :style="{ zIndex: entry.regular.length - idx, position: 'relative' }"
            @click="onStageClick(entry, stage)"
          >
            <span class="ckb-step-name">{{ stage.name }}</span>
          </button>
        </div>

        <!-- right: deal value + outcome badge -->
        <div class="ckb-right">
          <span v-if="entry.dealValue" class="ckb-deal">{{ entry.dealValue }}</span>
          <span v-if="entry.placement.stage_type === 'won'" class="ckb-outcome ckb-outcome--won">
            <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 9H4.5a2.5 2.5 0 0 1 0-5H6"/><path d="M18 9h1.5a2.5 2.5 0 0 0 0-5H18"/><path d="M4 22h16"/><path d="M10 14.66V17c0 .55-.47.98-.97 1.21C7.85 18.75 7 20.24 7 22"/><path d="M14 14.66V17c0 .55.47.98.97 1.21C16.15 18.75 17 20.24 17 22"/><path d="M18 2H6v7a6 6 0 0 0 12 0V2Z"/></svg>
            Ganho
          </span>
          <span v-else-if="entry.placement.stage_type === 'lost'" class="ckb-outcome ckb-outcome--lost">
            <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="m15 9-6 6"/><path d="m9 9 6 6"/></svg>
            Perdido
          </span>
          <!-- won/lost action buttons when in regular stage -->
          <template v-else>
            <button
              v-if="wonStageFor(entry)"
              class="ckb-btn-terminal ckb-btn-won"
              @click="onStageClick(entry, wonStageFor(entry))"
            >
              <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 9H4.5a2.5 2.5 0 0 1 0-5H6"/><path d="M18 9h1.5a2.5 2.5 0 0 0 0-5H18"/><path d="M4 22h16"/><path d="M10 14.66V17c0 .55-.47.98-.97 1.21C7.85 18.75 7 20.24 7 22"/><path d="M14 14.66V17c0 .55.47.98.97 1.21C16.15 18.75 17 20.24 17 22"/><path d="M18 2H6v7a6 6 0 0 0 12 0V2Z"/></svg>
              Ganho
            </button>
            <button
              v-if="lostStageFor(entry)"
              class="ckb-btn-terminal ckb-btn-lost"
              @click="onStageClick(entry, lostStageFor(entry))"
            >
              <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="m15 9-6 6"/><path d="m9 9 6 6"/></svg>
              Perdido
            </button>
          </template>
        </div>
      </div>

      <!-- funnel label -->
      <div class="px-4 pb-2 -mt-1">
        <span class="inline-flex items-center gap-1 text-[10px] font-semibold" style="color:rgb(var(--n-brand))">
          <svg width="9" height="9" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polygon points="22 3 2 3 10 12.46 10 19 14 21 14 12.46 22 3"/></svg>
          {{ entry.placement.funnel_name }}
        </span>
      </div>
    </div>

  </div>

  <KanbanWonModal
    v-if="showWonModal"
    :conversation="modalConversation"
    :stage-name="pendingEntry ? wonStageFor(pendingEntry)?.name || 'Venda Ganha' : 'Venda Ganha'"
    @confirm="confirmWon"
    @cancel="cancelModal"
  />
  <KanbanLostModal
    v-if="showLostModal"
    :conversation="modalConversation"
    :stage-name="pendingEntry ? lostStageFor(pendingEntry)?.name || 'Perdido' : 'Perdido'"
    @confirm="confirmLost"
    @cancel="cancelModal"
  />
</template>

<style scoped>
.ckb-bar {
  display: flex; align-items: center;
  height: 40px; gap: 6px;
}

.ckb-pipeline {
  display: flex; align-items: stretch;
  flex: 1; height: 26px; min-width: 0; overflow: visible;
}

.ckb-step {
  position: relative; display: flex; flex-direction: column;
  align-items: center; justify-content: center;
  height: 26px; flex: 1; min-width: 40px;
  padding: 0 18px 0 14px; border: none; border-radius: 0;
  cursor: pointer; line-height: 1; transition: filter .12s;
}
.ckb-step::after {
  content: ''; position: absolute; right: -9px; top: 0;
  width: 0; height: 0;
  border-top: 13px solid transparent;
  border-bottom: 13px solid transparent;
  border-left: 9px solid var(--ckb-bg);
  z-index: 2; pointer-events: none;
}
.ckb-step--last::after { display: none; }
.ckb-step--first { padding-left: 10px; border-radius: 4px 0 0 4px; }
.ckb-step--last  { border-radius: 0 4px 4px 0; }
.ckb-step--first.ckb-step--last { border-radius: 4px; padding: 0 10px; }

.ckb-step--reached { --ckb-bg: rgb(var(--n-brand)); background: rgb(var(--n-brand)); color: #fff; }
.ckb-step--reached:hover { filter: brightness(1.1); }
.ckb-step--current { --ckb-bg: rgb(var(--n-brand)); background: rgb(var(--n-brand)); color: #fff; }
.ckb-step--current:hover { cursor: default; }
.ckb-step--future  { --ckb-bg: rgb(var(--slate-3)); background: rgb(var(--slate-3)); color: rgb(var(--slate-8)); }
.ckb-step--future:hover { filter: brightness(.95); }

.ckb-step-name {
  font-size: 10px; font-weight: 600;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 100%;
}

.ckb-right {
  display: flex; align-items: center; gap: 4px; flex-shrink: 0;
}

.ckb-deal {
  font-size: 10px; font-weight: 700; color: rgb(var(--n-brand));
  padding: 2px 6px; border-radius: 99px;
  background: color-mix(in srgb, rgb(var(--n-brand)) 12%, transparent);
  border: 1px solid color-mix(in srgb, rgb(var(--n-brand)) 30%, transparent);
  white-space: nowrap;
}

.ckb-btn-terminal {
  display: inline-flex; align-items: center; gap: 3px;
  height: 22px; padding: 0 8px; border-radius: 4px; border: none; cursor: pointer;
  font-size: 10px; font-weight: 700; transition: filter .12s;
}
.ckb-btn-terminal:hover { filter: brightness(.88); }
.ckb-btn-won  { background: rgb(var(--n-brand)); color: #fff; }
.ckb-btn-lost { background: #dc2626; color: #fff; }

.ckb-outcome {
  display: inline-flex; align-items: center; gap: 3px;
  height: 22px; padding: 0 8px; border-radius: 4px;
  font-size: 10px; font-weight: 700;
}
.ckb-outcome--won  { background: color-mix(in srgb,rgb(var(--n-brand)) 12%,transparent); color:rgb(var(--n-brand)); border:1px solid color-mix(in srgb,rgb(var(--n-brand)) 30%,transparent); }
.ckb-outcome--lost { background: color-mix(in srgb,#dc2626 12%,transparent); color:#dc2626; border:1px solid color-mix(in srgb,#dc2626 30%,transparent); }
</style>
