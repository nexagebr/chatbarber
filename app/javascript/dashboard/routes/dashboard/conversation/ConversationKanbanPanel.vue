<script setup>
/**
 * ConversationKanbanPanel — shows all kanban placements for a conversation
 * and allows moving stages, marking won/lost, adding to a funnel, and removing.
 *
 * Injected inside ContactPanel.vue as an AccordionItem panel.
 */
import { ref, computed, watch, onMounted } from 'vue';
import { useStore } from 'vuex';
import KanbanPlacementCard from 'dashboard/routes/dashboard/kanban/components/KanbanPlacementCard.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const store = useStore();

const uiFlags = computed(() => store.getters['kanbanPlacements/getUIFlags']);
const placements = computed(() => store.getters['kanbanPlacements/getPlacements']);
const funnels = computed(() => store.getters['kanbanPlacements/getFunnels']);
const isFetching = computed(() => uiFlags.value.isFetching);

// Track which funnel IDs are already in use (to hide them from "Add to funnel" select)
const usedFunnelIds = computed(() => new Set(placements.value.map(p => p.funnel_id)));

const availableFunnels = computed(() =>
  funnels.value.filter(f => !usedFunnelIds.value.has(f.id))
);

const showAddFunnel = ref(false);
const selectedNewFunnelId = ref(null);
const selectedNewStageId = ref(null);
const isAdding = ref(false);

const newFunnelStages = computed(() => {
  if (!selectedNewFunnelId.value) return [];
  const f = funnels.value.find(f => f.id === Number(selectedNewFunnelId.value));
  if (!f) return [];
  return [...f.stages].sort((a, b) => (a.position ?? 0) - (b.position ?? 0))
    .filter(s => s.stage_type === 'regular' || s.stage_type === null);
});

watch(selectedNewFunnelId, () => { selectedNewStageId.value = null; });

const fetchPlacements = () => {
  store.dispatch('kanbanPlacements/fetchForConversation', props.conversationId);
};

watch(() => props.conversationId, (newVal) => {
  if (newVal) fetchPlacements();
});

onMounted(() => {
  fetchPlacements();
  store.dispatch('kanbanLossReasons/get');
});

const onMoved = () => { fetchPlacements(); };
const onRemoved = () => { fetchPlacements(); };

const addToFunnel = async () => {
  if (!selectedNewFunnelId.value || !selectedNewStageId.value) return;
  isAdding.value = true;
  try {
    await store.dispatch('kanbanStageItems/move', {
      funnelId: Number(selectedNewFunnelId.value),
      conversationId: props.conversationId,
      stageId: Number(selectedNewStageId.value),
    });
    showAddFunnel.value = false;
    selectedNewFunnelId.value = null;
    selectedNewStageId.value = null;
    fetchPlacements();
  } catch (e) {
    console.error('ConversationKanbanPanel: addToFunnel failed', e);
  } finally {
    isAdding.value = false;
  }
};
</script>

<template>
  <div class="p-2 space-y-2">
    <!-- Loading -->
    <div v-if="isFetching" class="flex items-center justify-center py-6 text-n-slate-9">
      <i class="i-lucide-loader-2 animate-spin text-xl" />
    </div>

    <!-- Placements -->
    <template v-else>
      <KanbanPlacementCard
        v-for="placement in placements"
        :key="`${placement.funnel_id}-${placement.conversation_id}`"
        :placement="placement"
        :funnels="funnels"
        @moved="onMoved"
        @removed="onRemoved"
      />

      <!-- No placements + no add open -->
      <div
        v-if="placements.length === 0 && !showAddFunnel"
        class="flex flex-col items-center justify-center py-6 text-n-slate-9 gap-2"
      >
        <i class="i-lucide-git-branch text-2xl opacity-40" />
        <p class="text-xs text-center">Esta conversa não está em nenhum funil</p>
      </div>

      <!-- Add to funnel section -->
      <div v-if="showAddFunnel" class="rounded-xl border border-n-brand/30 bg-n-brand/5 p-3 space-y-2">
        <p class="text-xs font-semibold text-n-slate-11">Adicionar a um funil</p>
        <select
          v-model="selectedNewFunnelId"
          class="w-full text-xs border border-n-weak bg-n-surface-1 text-n-slate-11 rounded-lg px-2 py-1.5 focus:outline-none focus:ring-1 focus:ring-n-brand"
        >
          <option value="">Selecionar funil…</option>
          <option
            v-for="funnel in availableFunnels"
            :key="funnel.id"
            :value="funnel.id"
          >{{ funnel.name }}</option>
        </select>
        <select
          v-if="selectedNewFunnelId"
          v-model="selectedNewStageId"
          class="w-full text-xs border border-n-weak bg-n-surface-1 text-n-slate-11 rounded-lg px-2 py-1.5 focus:outline-none focus:ring-1 focus:ring-n-brand"
        >
          <option value="">Selecionar estágio…</option>
          <option
            v-for="stage in newFunnelStages"
            :key="stage.id"
            :value="stage.id"
          >{{ stage.name }}</option>
        </select>
        <div class="flex gap-2">
          <button
            class="flex-1 text-xs py-1.5 rounded-lg bg-n-brand text-white font-semibold hover:opacity-90 disabled:opacity-50 transition-opacity"
            :disabled="!selectedNewFunnelId || !selectedNewStageId || isAdding"
            @click="addToFunnel"
          >
            <i v-if="isAdding" class="i-lucide-loader-2 animate-spin mr-1" />
            Adicionar
          </button>
          <button
            class="text-xs px-3 py-1.5 rounded-lg border border-n-weak text-n-slate-9 hover:bg-n-alpha-2 transition-colors"
            @click="showAddFunnel = false; selectedNewFunnelId = null; selectedNewStageId = null"
          >
            Cancelar
          </button>
        </div>
      </div>

      <!-- Add to funnel button -->
      <button
        v-if="!showAddFunnel && availableFunnels.length > 0"
        class="w-full flex items-center justify-center gap-1.5 py-2 text-xs text-n-brand border border-dashed border-n-brand/40 rounded-lg hover:bg-n-brand/5 transition-colors"
        @click="showAddFunnel = true"
      >
        <i class="i-lucide-plus text-xs" />
        Adicionar a um funil
      </button>
    </template>
  </div>
</template>
