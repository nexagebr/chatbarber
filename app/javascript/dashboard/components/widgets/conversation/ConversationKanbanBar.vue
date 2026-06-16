<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from 'vue';
import { useStore } from 'vuex';
import KanbanWonModal  from 'dashboard/routes/dashboard/kanban/components/KanbanWonModal.vue';
import KanbanLostModal from 'dashboard/routes/dashboard/kanban/components/KanbanLostModal.vue';

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
  conversation:   { type: Object, default: null },
});

const store = useStore();
const placements    = computed(() => store.getters['kanbanPlacements/getPlacements']);
const allFunnels    = computed(() => store.getters['kanbanPlacements/getFunnels']);
const isFetching    = computed(() => store.getters['kanbanPlacements/getUIFlags'].isFetching);
const initialLoaded = ref(false);

// 1-funnel model: always use placements[0]
const currentPlacement = computed(() => placements.value[0] ?? null);
const currentFunnel    = computed(() => allFunnels.value.find(f => f.id === currentPlacement.value?.funnel_id) ?? null);
const allStages        = computed(() =>
  currentFunnel.value
    ? [...currentFunnel.value.stages].sort((a, b) => (a.position ?? 0) - (b.position ?? 0))
    : []
);
const regularStages = computed(() => allStages.value.filter(s => !s.stage_type || s.stage_type === 'regular'));
const wonStage      = computed(() => allStages.value.find(s => s.stage_type === 'won'));
const lostStage     = computed(() => allStages.value.find(s => s.stage_type === 'lost'));
const currentIdx    = computed(() => regularStages.value.findIndex(s => s.id === currentPlacement.value?.stage_id));

// "Leads novos": inbox is linked to a funnel but conversation has no stage yet
const inboxLinkedFunnels = computed(() => {
  const inboxId = props.conversation?.inbox_id;
  if (!inboxId || placements.value.length > 0) return [];
  return allFunnels.value.filter(f => Array.isArray(f.inbox_ids) && f.inbox_ids.includes(inboxId));
});
const isInLeadsNovos   = computed(() => inboxLinkedFunnels.value.length > 0);
const leadsNovosFunnel = computed(() => inboxLinkedFunnels.value[0] ?? null);
const leadsNovosStages = computed(() =>
  leadsNovosFunnel.value
    ? [...leadsNovosFunnel.value.stages]
        .filter(s => !s.stage_type || s.stage_type === 'regular')
        .sort((a, b) => (a.position ?? 0) - (b.position ?? 0))
    : []
);

const now    = ref(Date.now());
const ticker = setInterval(() => { now.value = Date.now(); }, 30000);
onUnmounted(() => clearInterval(ticker));

const timeInStage = computed(() => {
  const t = currentPlacement.value?.entered_at;
  if (!t) return null;
  const ms = now.value - new Date(t).getTime();
  const d  = Math.floor(ms / 86400000);
  if (d >= 1) return `${d}d`;
  const h  = Math.floor(ms / 3600000);
  if (h >= 1) return `${h}h`;
  return `${Math.floor(ms / 60000)}min`;
});

const dealValue = computed(() => {
  const v = currentPlacement.value?.deal_value;
  if (!v) return null;
  return Number(v).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL', maximumFractionDigits: 0 });
});

// ── Add to funnel panel ──
const showAddPanel    = ref(false);
const newFunnelId     = ref('');
const newStageId      = ref('');
const isAdding        = ref(false);
const newFunnelStages = computed(() => {
  if (!newFunnelId.value) return [];
  const f = allFunnels.value.find(f => f.id === Number(newFunnelId.value));
  return f ? [...f.stages].sort((a, b) => (a.position ?? 0) - (b.position ?? 0)).filter(s => !s.stage_type || s.stage_type === 'regular') : [];
});
watch(newFunnelId, () => { newStageId.value = ''; });

// ── Change funnel panel ──
const showChangeFunnel    = ref(false);
const changeFunnelId      = ref(null);   // Number id
const changeFunnelStageId = ref(null);   // Number id
const isChanging          = ref(false);
const otherFunnels        = computed(() => {
  const currentId = currentPlacement.value?.funnel_id;
  return allFunnels.value.filter(f => f.id !== currentId);
});
const changeFunnelStages = computed(() => {
  if (!changeFunnelId.value) return [];
  const f = allFunnels.value.find(f => f.id === changeFunnelId.value);
  return f ? [...f.stages].sort((a, b) => (a.position ?? 0) - (b.position ?? 0)).filter(s => !s.stage_type || s.stage_type === 'regular') : [];
});

const selectChangeFunnel = id => {
  changeFunnelId.value = id;
  changeFunnelStageId.value = null;
  // auto-select first stage
  const f = allFunnels.value.find(f => f.id === id);
  if (f) {
    const stages = [...f.stages].sort((a, b) => (a.position ?? 0) - (b.position ?? 0)).filter(s => !s.stage_type || s.stage_type === 'regular');
    if (stages.length) changeFunnelStageId.value = stages[0].id;
  }
};

const openChangeFunnel = () => {
  changeFunnelId.value = null;
  changeFunnelStageId.value = null;
  showChangeFunnel.value = true;
};

const closeChangeFunnel = () => {
  showChangeFunnel.value = false;
  changeFunnelId.value = null;
  changeFunnelStageId.value = null;
};

// ── Move / Won / Lost modals ──
const showWonModal   = ref(false);
const showLostModal  = ref(false);
const pendingStageId = ref(null);
const isMoving       = ref(false);

const conversationProxy = computed(() =>
  props.conversation ?? { id: props.conversationId, meta: { sender: { name: currentPlacement.value?.conversation_label } }, additional_attributes: { deal_value: currentPlacement.value?.deal_value }, custom_attributes: {} }
);

const onStageClick = stage => {
  if (!currentPlacement.value || isMoving.value || stage.id === currentPlacement.value.stage_id) return;
  if (stage.stage_type === 'won')  { pendingStageId.value = stage.id; showWonModal.value  = true; return; }
  if (stage.stage_type === 'lost') { pendingStageId.value = stage.id; showLostModal.value = true; return; }
  doMove(stage.id);
};
const doMove = async (stageId, extra = {}) => {
  isMoving.value = true;
  try {
    await store.dispatch('kanbanStageItems/move', { funnelId: currentPlacement.value.funnel_id, conversationId: props.conversationId, stageId, ...extra });
    await loadData();
  } finally { isMoving.value = false; }
};
const confirmWon  = p => { showWonModal.value  = false; doMove(pendingStageId.value, p); pendingStageId.value = null; };
const confirmLost = p => { showLostModal.value = false; doMove(pendingStageId.value, p); pendingStageId.value = null; };
const cancelModal = () => { showWonModal.value = showLostModal.value = false; pendingStageId.value = null; };

const addToFunnel = async () => {
  if (!newFunnelId.value || !newStageId.value) return;
  isAdding.value = true;
  try {
    await store.dispatch('kanbanStageItems/move', { funnelId: Number(newFunnelId.value), conversationId: props.conversationId, stageId: Number(newStageId.value) });
    showAddPanel.value = false; newFunnelId.value = ''; newStageId.value = '';
    await loadData();
  } finally { isAdding.value = false; }
};

const moveToStage = async stage => {
  const funnelId = leadsNovosFunnel.value?.id;
  if (!funnelId || isAdding.value) return;
  isAdding.value = true;
  try {
    await store.dispatch('kanbanStageItems/move', { funnelId, conversationId: props.conversationId, stageId: stage.id });
    await loadData();
  } finally { isAdding.value = false; }
};

const doChangeFunnel = async () => {
  if (!changeFunnelId.value || !changeFunnelStageId.value) return;
  isChanging.value = true;
  const oldFunnelId = currentPlacement.value?.funnel_id;
  try {
    await store.dispatch('kanbanStageItems/move', { funnelId: changeFunnelId.value, conversationId: props.conversationId, stageId: changeFunnelStageId.value });
    if (oldFunnelId) {
      await store.dispatch('kanbanStageItems/remove', { funnelId: oldFunnelId, conversationId: props.conversationId });
    }
    closeChangeFunnel();
    await loadData();
  } finally { isChanging.value = false; }
};

const loadData = async () => {
  await store.dispatch('kanbanPlacements/fetchForConversation', props.conversationId);
  initialLoaded.value = true;
};

watch(() => props.conversationId, v => { if (v) { showAddPanel.value = false; closeChangeFunnel(); initialLoaded.value = false; loadData(); } });
onMounted(() => { store.dispatch('kanbanLossReasons/get'); loadData(); });
</script>

<template>
  <div class="ckb-root">

    <!-- skeleton only on initial load -->
    <div v-if="isFetching && !initialLoaded" class="ckb-skeleton" />

    <!-- ── CHANGE FUNNEL PANEL ── -->
    <div v-else-if="showChangeFunnel" class="ckb-change-panel">
      <div class="ckb-change-header">
        <span class="ckb-change-title">
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="17 1 21 5 17 9"/><path d="M3 11V9a4 4 0 0 1 4-4h14"/><polyline points="7 23 3 19 7 15"/><path d="M21 13v2a4 4 0 0 1-4 4H3"/></svg>
          Mover para outro funil
        </span>
        <button class="ckb-change-close" @click="closeChangeFunnel">
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
        </button>
      </div>

      <!-- Funnel options -->
      <div class="ckb-change-body">
        <p class="ckb-change-label">Escolha o funil destino</p>
        <div class="ckb-funnel-list">
          <button
            v-for="f in otherFunnels"
            :key="f.id"
            class="ckb-funnel-option"
            :class="{ 'ckb-funnel-option--active': changeFunnelId === f.id }"
            @click="selectChangeFunnel(f.id)"
          >
            <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polygon points="22 3 2 3 10 12.46 10 19 14 21 14 12.46 22 3"/></svg>
            {{ f.name }}
          </button>
        </div>

        <!-- Stage options — appears after funnel is chosen -->
        <template v-if="changeFunnelId && changeFunnelStages.length">
          <p class="ckb-change-label" style="margin-top:8px">Etapa inicial</p>
          <div class="ckb-stage-list">
            <button
              v-for="s in changeFunnelStages"
              :key="s.id"
              class="ckb-stage-option"
              :class="{ 'ckb-stage-option--active': changeFunnelStageId === s.id }"
              @click="changeFunnelStageId = s.id"
            >
              {{ s.name }}
            </button>
          </div>
        </template>
      </div>

      <!-- Actions -->
      <div class="ckb-change-footer">
        <button class="ckb-link" @click="closeChangeFunnel">Cancelar</button>
        <button
          class="ckb-btn-confirm"
          :disabled="!changeFunnelId || !changeFunnelStageId || isChanging"
          @click="doChangeFunnel"
        >
          <svg v-if="isChanging" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" style="animation:ckb-spin .8s linear infinite"><path d="M21 12a9 9 0 1 1-6.219-8.56"/></svg>
          Mover
        </button>
      </div>
    </div>

    <!-- leads novos: inbox linked to funnel but no stage assigned yet -->
    <div v-else-if="isInLeadsNovos && !showAddPanel" class="ckb-bar" :class="{ 'ckb-bar--busy': isAdding }">
      <div class="ckb-pipeline">
        <button
          v-for="(stage, idx) in leadsNovosStages"
          :key="stage.id"
          class="ckb-step ckb-step--future"
          :class="{
            'ckb-step--first': idx === 0,
            'ckb-step--last':  idx === leadsNovosStages.length - 1,
          }"
          :style="{ zIndex: leadsNovosStages.length - idx, position: 'relative' }"
          :title="`Mover para ${stage.name}`"
          @click="moveToStage(stage)"
        >
          <span class="ckb-step-name">{{ stage.name }}</span>
        </button>
      </div>
    </div>

    <!-- no funnel at all -->
    <div v-else-if="!currentPlacement && !showAddPanel" class="ckb-simple-row">
      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="opacity:.4; flex-shrink:0"><polygon points="22 3 2 3 10 12.46 10 19 14 21 14 12.46 22 3"/></svg>
      <span class="ckb-dim">Sem funil</span>
      <button v-if="allFunnels.length" class="ckb-link" @click="showAddPanel = true">+ Adicionar ao funil</button>
    </div>

    <!-- add form -->
    <div v-else-if="showAddPanel" class="ckb-simple-row ckb-add-bg">
      <select v-model="newFunnelId" class="ckb-sel">
        <option value="">Funil…</option>
        <option v-for="f in allFunnels" :key="f.id" :value="f.id">{{ f.name }}</option>
      </select>
      <select v-if="newFunnelId" v-model="newStageId" class="ckb-sel">
        <option value="">Etapa…</option>
        <option v-for="s in newFunnelStages" :key="s.id" :value="s.id">{{ s.name }}</option>
      </select>
      <button class="ckb-btn-add" :disabled="!newFunnelId || !newStageId || isAdding" @click="addToFunnel">Adicionar</button>
      <button class="ckb-link" @click="showAddPanel = false">Cancelar</button>
    </div>

    <!-- ── PIPELINE BAR ── -->
    <div v-else-if="currentPlacement" class="ckb-bar" :class="{ 'ckb-bar--busy': isMoving }">

      <!-- chevron pipeline -->
      <div class="ckb-pipeline">
        <button
          v-for="(stage, idx) in regularStages"
          :key="stage.id"
          class="ckb-step"
          :class="{
            'ckb-step--reached': idx <= currentIdx,
            'ckb-step--current': idx === currentIdx,
            'ckb-step--future':  idx > currentIdx,
            'ckb-step--first':   idx === 0,
            'ckb-step--last':    idx === regularStages.length - 1,
          }"
          :style="{ zIndex: regularStages.length - idx, position: 'relative' }"
          @click="onStageClick(stage)"
        >
          <span class="ckb-step-name">{{ stage.name }}</span>
          <span v-if="idx === currentIdx && timeInStage" class="ckb-step-time">{{ timeInStage }}</span>
        </button>
      </div>

      <!-- right side -->
      <div class="ckb-right">
        <span v-if="dealValue" class="ckb-deal">{{ dealValue }}</span>
        <span v-if="currentPlacement.stage_type === 'won'" class="ckb-outcome ckb-outcome--won">
          <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 9H4.5a2.5 2.5 0 0 1 0-5H6"/><path d="M18 9h1.5a2.5 2.5 0 0 0 0-5H18"/><path d="M4 22h16"/><path d="M10 14.66V17c0 .55-.47.98-.97 1.21C7.85 18.75 7 20.24 7 22"/><path d="M14 14.66V17c0 .55.47.98.97 1.21C16.15 18.75 17 20.24 17 22"/><path d="M18 2H6v7a6 6 0 0 0 12 0V2Z"/></svg>
          Ganho
        </span>
        <span v-else-if="currentPlacement.stage_type === 'lost'" class="ckb-outcome ckb-outcome--lost">
          <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="m15 9-6 6"/><path d="m9 9 6 6"/></svg>
          Perdido
        </span>
        <button
          v-if="otherFunnels.length > 0"
          class="ckb-btn-change"
          title="Trocar funil"
          @click="openChangeFunnel"
        >
          <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="17 1 21 5 17 9"/><path d="M3 11V9a4 4 0 0 1 4-4h14"/><polyline points="7 23 3 19 7 15"/><path d="M21 13v2a4 4 0 0 1-4 4H3"/></svg>
          Trocar funil
        </button>
      </div>

    </div>

  </div>

  <KanbanWonModal  v-if="showWonModal"  :conversation="conversationProxy" :stage-name="wonStage?.name  || 'Venda Ganha'" @confirm="confirmWon"  @cancel="cancelModal" />
  <KanbanLostModal v-if="showLostModal" :conversation="conversationProxy" :stage-name="lostStage?.name || 'Perdido'"     @confirm="confirmLost" @cancel="cancelModal" />
</template>

<style scoped>
.ckb-root {
  border-bottom: 1px solid rgb(var(--border-weak));
}

.ckb-skeleton {
  height: 40px;
  background: linear-gradient(90deg, rgba(var(--alpha-2)) 25%, rgba(var(--alpha-3)) 50%, rgba(var(--alpha-2)) 75%);
  background-size: 200% 100%;
  animation: ckb-pulse 1.3s infinite;
}
@keyframes ckb-pulse { 0%{background-position:200% 0} 100%{background-position:-200% 0} }
@keyframes ckb-spin  { to { transform: rotate(360deg); } }

/* ── simple rows (no funnel / add form) ── */
.ckb-simple-row {
  display: flex; align-items: center;
  height: 36px; padding: 0 14px; gap: 8px;
}
.ckb-add-bg { background: color-mix(in srgb, rgb(var(--n-brand)) 5%, transparent); }
.ckb-dim  { font-size: 12px; color: rgb(var(--slate-7)); }
.ckb-link { background: none; border: none; cursor: pointer; padding: 0; font-size: 12px; font-weight: 600; color: rgb(var(--n-brand)); }
.ckb-link:hover { text-decoration: underline; }
.ckb-sel {
  height: 26px; padding: 0 8px; border-radius: 5px; outline: none; font-size: 12px;
  border: 1px solid rgb(var(--border-weak));
  background: rgb(var(--surface-2)); color: rgb(var(--slate-11));
}
.ckb-btn-add {
  height: 26px; padding: 0 12px; border-radius: 5px; border: none; cursor: pointer;
  font-size: 12px; font-weight: 600; background: rgb(var(--n-brand)); color: #fff;
}
.ckb-btn-add:disabled { opacity: .4; cursor: default; }

/* ── CHANGE FUNNEL PANEL ── */
.ckb-change-panel {
  padding: 10px 14px 12px;
  background: color-mix(in srgb, rgb(var(--n-brand)) 4%, transparent);
  border-top: 1px solid color-mix(in srgb, rgb(var(--n-brand)) 15%, transparent);
}
.ckb-change-header {
  display: flex; align-items: center; justify-content: space-between;
  margin-bottom: 10px;
}
.ckb-change-title {
  display: inline-flex; align-items: center; gap: 5px;
  font-size: 12px; font-weight: 700; color: rgb(var(--n-brand));
}
.ckb-change-close {
  display: flex; align-items: center; justify-content: center;
  width: 20px; height: 20px; border-radius: 4px; border: none; background: none; cursor: pointer;
  color: rgb(var(--slate-8)); transition: background .12s;
}
.ckb-change-close:hover { background: rgb(var(--alpha-3)); }

.ckb-change-body { }

.ckb-change-label {
  font-size: 11px; font-weight: 600; color: rgb(var(--slate-8));
  margin: 0 0 6px; text-transform: uppercase; letter-spacing: .04em;
}

.ckb-funnel-list {
  display: flex; flex-wrap: wrap; gap: 6px;
}
.ckb-funnel-option {
  display: inline-flex; align-items: center; gap: 5px;
  height: 28px; padding: 0 12px; border-radius: 6px; cursor: pointer;
  font-size: 12px; font-weight: 600;
  border: 1.5px solid rgb(var(--border-weak));
  background: rgb(var(--surface-2)); color: rgb(var(--slate-10));
  transition: all .12s;
}
.ckb-funnel-option:hover {
  border-color: color-mix(in srgb, rgb(var(--n-brand)) 50%, transparent);
  color: rgb(var(--n-brand));
  background: color-mix(in srgb, rgb(var(--n-brand)) 6%, transparent);
}
.ckb-funnel-option--active {
  border-color: rgb(var(--n-brand));
  background: color-mix(in srgb, rgb(var(--n-brand)) 12%, transparent);
  color: rgb(var(--n-brand));
}

.ckb-stage-list {
  display: flex; flex-wrap: wrap; gap: 5px;
}
.ckb-stage-option {
  height: 26px; padding: 0 10px; border-radius: 5px; cursor: pointer;
  font-size: 11px; font-weight: 600;
  border: 1.5px solid rgb(var(--border-weak));
  background: rgb(var(--surface-2)); color: rgb(var(--slate-9));
  transition: all .12s;
}
.ckb-stage-option:hover {
  border-color: color-mix(in srgb, rgb(var(--n-brand)) 40%, transparent);
  color: rgb(var(--n-brand));
}
.ckb-stage-option--active {
  border-color: rgb(var(--n-brand));
  background: color-mix(in srgb, rgb(var(--n-brand)) 10%, transparent);
  color: rgb(var(--n-brand));
}

.ckb-change-footer {
  display: flex; align-items: center; justify-content: flex-end;
  gap: 10px; margin-top: 12px;
}
.ckb-btn-confirm {
  display: inline-flex; align-items: center; gap: 5px;
  height: 28px; padding: 0 16px; border-radius: 6px; border: none; cursor: pointer;
  font-size: 12px; font-weight: 700; background: rgb(var(--n-brand)); color: #fff;
  transition: filter .12s;
}
.ckb-btn-confirm:hover:not(:disabled) { filter: brightness(1.1); }
.ckb-btn-confirm:disabled { opacity: .4; cursor: default; }

.ckb-btn-change {
  display: inline-flex; align-items: center; gap: 4px;
  height: 24px; padding: 0 8px; border-radius: 5px;
  border: 1px solid rgb(var(--border-weak));
  background: transparent; color: rgb(var(--slate-9));
  font-size: 11px; font-weight: 600; cursor: pointer;
  transition: background .12s, color .12s, border-color .12s;
}
.ckb-btn-change:hover {
  background: color-mix(in srgb, rgb(var(--n-brand)) 8%, transparent);
  color: rgb(var(--n-brand));
  border-color: color-mix(in srgb, rgb(var(--n-brand)) 40%, transparent);
}

/* ── main pipeline bar ── */
.ckb-bar {
  display: flex;
  align-items: center;
  height: 40px;
  gap: 8px;
  padding: 0 10px 0 10px;
}
.ckb-bar--busy { opacity: .7; pointer-events: none; transition: opacity .15s; }


/*
 * PIPEDRIVE-STYLE CHEVRON PIPELINE
 */
.ckb-pipeline {
  display: flex;
  align-items: stretch;
  flex: 1;
  height: 28px;
  min-width: 0;
  overflow: visible;
}

.ckb-step {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 28px;
  flex: 1;
  min-width: 52px;
  padding: 0 20px 0 16px;
  border: none;
  border-radius: 0;
  cursor: pointer;
  line-height: 1;
  transition: filter .12s;
}

.ckb-step::after {
  content: '';
  position: absolute;
  right: -10px;
  top: 0;
  width: 0;
  height: 0;
  border-top:    14px solid transparent;
  border-bottom: 14px solid transparent;
  border-left:   10px solid var(--ckb-bg);
  z-index: 2;
  pointer-events: none;
}
.ckb-step--last::after { display: none; }

.ckb-step--first {
  padding-left: 12px;
  border-radius: 4px 0 0 4px;
}
.ckb-step--last { border-radius: 0 4px 4px 0; }
.ckb-step--first.ckb-step--last { border-radius: 4px; padding: 0 12px; }

.ckb-step--reached {
  --ckb-bg: rgb(var(--n-brand));
  background: rgb(var(--n-brand));
  color: #fff;
}
.ckb-step--reached:hover { filter: brightness(1.1); }

.ckb-step--current {
  --ckb-bg: rgb(var(--n-brand));
  background: rgb(var(--n-brand)); filter: brightness(1.08);
  color: #fff;
  filter: none;
}
.ckb-step--current:hover { cursor: default; }

.ckb-step--future {
  --ckb-bg: rgb(var(--slate-3));
  background: rgb(var(--slate-3));
  color: rgb(var(--slate-8));
}
.ckb-step--future:hover { filter: brightness(.95); }

.ckb-step-name {
  font-size: 11px; font-weight: 600;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
  max-width: 100%; line-height: 1.1;
}
.ckb-step-time {
  font-size: 9px; font-weight: 400; opacity: .8;
  margin-top: 1px; line-height: 1;
}

/* ── right side ── */
.ckb-right {
  display: flex; align-items: center; gap: 5px;
  flex-shrink: 0; margin-left: 4px;
}

.ckb-deal {
  font-size: 11px; font-weight: 700;
  color: rgb(var(--n-brand));
  padding: 2px 8px; border-radius: 99px;
  background: color-mix(in srgb, rgb(var(--n-brand)) 12%, transparent);
  border: 1px solid color-mix(in srgb, rgb(var(--n-brand)) 30%, transparent);
  white-space: nowrap;
}

.ckb-outcome {
  display: inline-flex; align-items: center; gap: 4px;
  height: 24px; padding: 0 10px; border-radius: 5px;
  font-size: 11px; font-weight: 700;
}
.ckb-outcome--won  { background: color-mix(in srgb, rgb(var(--n-brand)) 12%, transparent); color: rgb(var(--n-brand)); border: 1px solid color-mix(in srgb, rgb(var(--n-brand)) 30%, transparent); }
.ckb-outcome--lost { background: color-mix(in srgb,#dc2626 12%,transparent); color:#dc2626; border:1px solid color-mix(in srgb,#dc2626 30%,transparent); }
</style>
