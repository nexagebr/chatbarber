<script setup>
import { ref, computed, onMounted, watch, nextTick, onActivated } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAccount } from 'dashboard/composables/useAccount';
import Draggable from 'vuedraggable';
import Button from 'dashboard/components-next/button/Button.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import KanbanSettingsModal from './KanbanSettingsModal.vue';
import KanbanCard from '../components/KanbanCard.vue';
import KanbanWonModal from '../components/KanbanWonModal.vue';
import KanbanLostModal from '../components/KanbanLostModal.vue';
import ContextMenu from 'dashboard/components/ui/ContextMenu.vue';
import ConversationContextMenu from 'dashboard/components/widgets/conversation/contextMenu/Index.vue';

const { t } = useI18n();
const store = useStore();
const router = useRouter();
const { accountId } = useAccount();

// --- Funnel state ---
const activeFunnelId = ref(null);
const showFunnelMenu = ref(false);
const showNewFunnelInput = ref(false);
const newFunnelName = ref('');
const editingFunnelId = ref(null);
const editingFunnelName = ref('');

const funnels = computed(() => store.getters['kanbanFunnels/getKanbanFunnels']);
const activeFunnel = computed(() => funnels.value.find(f => f.id === activeFunnelId.value) || null);

const selectFunnel = async funnelId => {
  activeFunnelId.value = funnelId;
  showFunnelMenu.value = false;
  await loadStages();
};

const createFunnel = async () => {
  const name = newFunnelName.value.trim();
  if (!name) return;
  try {
    const created = await store.dispatch('kanbanFunnels/create', { kanban_funnel: { name } });
    newFunnelName.value = '';
    showNewFunnelInput.value = false;
    await selectFunnel(created.id);
  } catch (e) {
    console.error('Error creating funnel', e);
  }
};

const startEditFunnel = funnel => {
  editingFunnelId.value = funnel.id;
  editingFunnelName.value = funnel.name;
};

const saveEditFunnel = async () => {
  if (!editingFunnelName.value.trim()) return;
  await store.dispatch('kanbanFunnels/update', {
    id: editingFunnelId.value,
    kanban_funnel: { name: editingFunnelName.value.trim() },
  });
  editingFunnelId.value = null;
  editingFunnelName.value = '';
};

const deleteFunnel = async funnel => {
  if (!confirm(`Excluir o funil "${funnel.name}"? Todos os estágios serão removidos.`)) return;
  await store.dispatch('kanbanFunnels/delete', funnel.id);
  if (activeFunnelId.value === funnel.id) {
    const remaining = funnels.value.filter(f => f.id !== funnel.id);
    if (remaining.length > 0) {
      await selectFunnel(remaining[0].id);
    } else {
      activeFunnelId.value = null;
      localStages.value = [];
    }
  }
};

// --- Context menu ---
const showContextMenu = ref(false);
const contextMenuPosition = ref({ x: 0, y: 0 });
const activeConversation = ref(null);

const handleCardContextMenu = (event, conversation) => {
  event.preventDefault();
  activeConversation.value = conversation;
  contextMenuPosition.value = { x: event.clientX, y: event.clientY };
  showContextMenu.value = true;
};

const closeContextMenu = () => {
  showContextMenu.value = false;
  activeConversation.value = null;
};

const onAssignAgent = async agent => {
  await store.dispatch('assignAgent', { conversationId: activeConversation.value.id, agentId: agent.id });
  closeContextMenu();
};
const onAssignTeam = async team => {
  await store.dispatch('assignTeam', { conversationId: activeConversation.value.id, teamId: team.id });
  closeContextMenu();
};
const onAssignLabel = async label => {
  const currentTitles = (activeConversation.value.labels || []).map(l => (typeof l === 'string' ? l : l.title));
  if (!currentTitles.includes(label.title)) {
    await store.dispatch('conversationLabels/update', {
      conversationId: activeConversation.value.id,
      labels: [...currentTitles, label.title],
    });
  }
  closeContextMenu();
};
const onUpdateStatus = async (status, snoozedUntil) => {
  await store.dispatch('toggleStatus', { conversationId: activeConversation.value.id, status, snoozedUntil });
  closeContextMenu();
};
const onAssignPriority = async priority => {
  await store.dispatch('assignPriority', { conversationId: activeConversation.value.id, priority });
  closeContextMenu();
};
const onMarkAsUnread = async () => {
  await store.dispatch('markMessagesUnread', { id: activeConversation.value.id });
  closeContextMenu();
};
const onMarkAsRead = async () => {
  await store.dispatch('markMessagesRead', { id: activeConversation.value.id });
  closeContextMenu();
};
const onDeleteConversation = async () => {
  if (confirm(t('CONTACTS_KANBAN.CARD.DELETE_CONFIRM') || 'Tem certeza?')) {
    await store.dispatch('deleteConversation', activeConversation.value.id);
  }
  closeContextMenu();
};

// --- View mode & filters ---
const viewMode = ref('board'); // 'board' | 'list'
const filterAgentId = ref(null);
const filterStatus = ref('all');
const filterPriority = ref('all');
const showStatusMenu = ref(false);
const showPriorityMenu = ref(false);

const statusOptions = [
  { value: 'all', label: 'Todos os status', icon: 'i-lucide-layers' },
  { value: 'open', label: 'Aberto', icon: 'i-lucide-circle-dot' },
  { value: 'resolved', label: 'Resolvido', icon: 'i-lucide-check-circle' },
  { value: 'pending', label: 'Pendente', icon: 'i-lucide-clock' },
  { value: 'snoozed', label: 'Adiado', icon: 'i-lucide-alarm-clock' },
];

const priorityOptions = [
  { value: 'all', label: 'Todas prioridades', icon: 'i-lucide-flag' },
  { value: 'urgent', label: 'Urgente', icon: 'i-lucide-alert-circle', color: 'text-n-ruby-9' },
  { value: 'high', label: 'Alta', icon: 'i-lucide-arrow-up', color: 'text-n-ruby-9' },
  { value: 'medium', label: 'Média', icon: 'i-lucide-minus', color: 'text-n-yellow-9' },
  { value: 'low', label: 'Baixa', icon: 'i-lucide-arrow-down', color: 'text-n-slate-9' },
  { value: 'none', label: 'Sem prioridade', icon: 'i-lucide-flag-off', color: 'text-n-slate-9' },
];

const hasActiveFilters = computed(() =>
  filterAgentId.value !== null || filterStatus.value !== 'all' || filterPriority.value !== 'all'
);

const clearFilters = () => {
  filterAgentId.value = null;
  filterStatus.value = 'all';
  filterPriority.value = 'all';
};

// Agents who have at least one conversation in the board
const activeAgents = computed(() => {
  const convs = allConversations.value || [];
  const agentMap = new Map();
  convs.forEach(c => {
    const a = c.meta?.assignee;
    if (a) agentMap.set(a.id, a);
  });
  return Array.from(agentMap.values());
});

const toggleAgentFilter = agentId => {
  filterAgentId.value = filterAgentId.value === agentId ? null : agentId;
};

// Filtered conversations (apply all active filters)
const filteredConversations = computed(() => {
  let convs = allConversations.value || [];
  if (filterAgentId.value !== null) {
    convs = convs.filter(c => c.meta?.assignee?.id === filterAgentId.value);
  }
  if (filterStatus.value !== 'all') {
    convs = convs.filter(c => c.status === filterStatus.value);
  }
  if (filterPriority.value !== 'all') {
    if (filterPriority.value === 'none') {
      convs = convs.filter(c => !c.priority);
    } else {
      convs = convs.filter(c => c.priority === filterPriority.value);
    }
  }
  return convs;
});

const activeStatusLabel = computed(
  () => statusOptions.find(o => o.value === filterStatus.value)?.label || 'Status'
);
const activePriorityLabel = computed(
  () => priorityOptions.find(o => o.value === filterPriority.value)?.label || 'Prioridade'
);

// --- Stages / Board ---
const isLoading = ref(false);
const showSettings = ref(false);
const isDragging = ref(false);

// Won / Lost modals
const pendingMove = ref(null); // { evt, stageId, stageType }
const showWonModal = ref(false);
const showLostModal = ref(false);
const UNASSIGNED_STAGE_ID = 'unassigned';

const localStages = ref([]);
const unassignedConversations = ref([]);

const kanbanStages = computed(() => store.getters['kanbanStages/getKanbanStages']);
const allConversations = computed(() => store.getters['getAllConversations']);
const stageItems = computed(() => store.getters['kanbanStageItems/getKanbanStageItems'] || []);

const syncStages = () => {
  if (isDragging.value) return;

  const currentStages = kanbanStages.value || [];
  const currentConversations = filteredConversations.value;
  const allLabels = store.getters['labels/getLabels'] || [];
  const items = stageItems.value;

  const conversationStageMap = new Map();

  currentConversations.forEach(conversation => {
    // Priority 1: explicit position persisted in kanban_stage_items
    const item = items.find(i => i.conversation_id === conversation.id);
    if (item) {
      conversationStageMap.set(conversation.id, item.stage_id);
      return;
    }

    // Priority 2: label-based fallback (retrocompat with tag-linked stages)
    if (conversation.labels && conversation.labels.length > 0) {
      const cLabels = conversation.labels.map(l => (typeof l === 'string' ? l : l.title));
      for (let i = cLabels.length - 1; i >= 0; i--) {
        const labelTitle = cLabels[i];
        const matchingLabelObj = allLabels.find(l => l.title === labelTitle);
        if (matchingLabelObj) {
          const matchingStage = currentStages.find(s => s.label_id === matchingLabelObj.id);
          if (matchingStage) {
            conversationStageMap.set(conversation.id, matchingStage.id);
            return;
          }
        }
      }
    }
    // Not placed in any stage → goes to "Leads novos"
  });

  // Sort: regular stages first (by position), then won, then lost
  const sortedStages = [...currentStages].sort((a, b) => {
    const order = { regular: 0, won: 1, lost: 2 };
    const ta = order[a.stage_type] ?? 0;
    const tb = order[b.stage_type] ?? 0;
    if (ta !== tb) return ta - tb;
    return (a.position ?? 0) - (b.position ?? 0);
  });

  localStages.value = sortedStages.filter(s => s.stage_type !== 'new_lead').map(stage => {
    const linkedLabel = allLabels.find(l => l.id === stage.label_id);
    return {
      ...stage,
      color: linkedLabel ? linkedLabel.color : (stage.color || '#64748b'),
      conversations: currentConversations.filter(c => conversationStageMap.get(c.id) === stage.id),
    };
  });

  const inboxIds = activeFunnel.value?.inbox_ids ?? [];
  const showUnassigned = activeFunnel.value?.show_unassigned !== false;
  unassignedConversations.value = showUnassigned ? currentConversations.filter(c => {
    if (conversationStageMap.has(c.id)) return false;
    if (inboxIds.length > 0) return inboxIds.includes(c.inbox_id);
    return true;
  }) : [];
};

// List view: all conversations grouped by stage
const listGroups = computed(() => {
  const groups = [];
  if (unassignedConversations.value.length > 0) {
    groups.push({ id: UNASSIGNED_STAGE_ID, name: 'Leads novos', color: '#94a3b8', conversations: unassignedConversations.value });
  }
  localStages.value.forEach(s => {
    groups.push({ id: s.id, name: s.name, color: s.color, conversations: s.conversations || [] });
  });
  return groups;
});

const totalFiltered = computed(() => filteredConversations.value.length);

const loadStages = async () => {
  if (!activeFunnelId.value) return;
  await Promise.all([
    store.dispatch('kanbanStages/get', activeFunnelId.value),
    store.dispatch('kanbanStageItems/get', activeFunnelId.value),
  ]);
  syncStages();
};

const loadData = async () => {
  isLoading.value = true;
  try {
    store.dispatch('setChatStatusFilter', 'all');
    store.dispatch('setChatListFilters', { assigneeType: 'all', status: 'all' });

    await Promise.all([
      store.dispatch('kanbanFunnels/get'),
      store.dispatch('labels/get'),
      store.dispatch('inboxes/get'),
      store.dispatch('fetchAllConversations'),
    ]);

    if (!activeFunnelId.value && funnels.value.length > 0) {
      activeFunnelId.value = funnels.value[0].id;
    }

    await loadStages();
  } catch (error) {
    console.error('Error loading kanban data:', error);
  } finally {
    isLoading.value = false;
  }
};

const onConversationMove = async (evt, stageId, stageType = 'regular') => {
  const { added, moved } = evt;
  if (!added && !moved) return;
  const conversation = added?.element || moved?.element;
  if (!conversation) return;

  // Intercept special stages
  if (stageType === 'won') {
    pendingMove.value = { evt, stageId, stageType, conversation };
    showWonModal.value = true;
    return;
  }
  if (stageType === 'lost') {
    pendingMove.value = { evt, stageId, stageType, conversation };
    showLostModal.value = true;
    return;
  }

  await commitMove(conversation, stageId, {});
};

const cancelPendingMove = () => {
  showWonModal.value = false;
  showLostModal.value = false;
  pendingMove.value = null;
  // Re-sync to restore the card to its original position
  syncStages();
};

const confirmWon = async ({ dealValue, outcomeNote }) => {
  showWonModal.value = false;
  const { conversation, stageId } = pendingMove.value;
  pendingMove.value = null;
  await commitMove(conversation, stageId, { dealValue, outcomeNote });
};

const confirmLost = async ({ lossReason, outcomeNote }) => {
  showLostModal.value = false;
  const { conversation, stageId } = pendingMove.value;
  pendingMove.value = null;
  await commitMove(conversation, stageId, { lossReason, outcomeNote });
};

const commitMove = async (conversation, stageId, outcomeParams = {}) => {
  try {
    if (stageId === UNASSIGNED_STAGE_ID) {
      await store.dispatch('kanbanStageItems/remove', {
        funnelId: activeFunnelId.value,
        conversationId: conversation.id,
      });
    } else {
      await store.dispatch('kanbanStageItems/move', {
        funnelId: activeFunnelId.value,
        conversationId: conversation.id,
        stageId,
        ...outcomeParams,
      });

      const targetStage = kanbanStages.value?.find(s => s.id === stageId);
      if (targetStage?.label_id) {
        const labels = store.getters['labels/getLabels'];
        const stageLabel = labels.find(l => l.id === targetStage.label_id);
        if (stageLabel) {
          const currentLabelTitles = (conversation.labels || []).map(l =>
            typeof l === 'string' ? l : l.title
          );
          const allStageLabelTitles = kanbanStages.value
            .filter(s => s.label_id)
            .map(s => labels.find(l => l.id === s.label_id)?.title)
            .filter(Boolean);
          const keptLabels = currentLabelTitles.filter(t => !allStageLabelTitles.includes(t));
          const updatedLabels = [...keptLabels, stageLabel.title];
          const updatedLabelObjects = updatedLabels.map(
            t => labels.find(l => l.title === t) || { title: t }
          );
          store.commit('UPDATE_CONVERSATION', {
            id: conversation.id,
            labels: updatedLabelObjects,
            updated_at: Math.floor(Date.now() / 1000),
          });
          await store.dispatch('conversationLabels/update', {
            conversationId: conversation.id,
            labels: updatedLabels,
          });
        }
      }
    }
  } catch (error) {
    console.error('Error updating conversation stage:', error);
    await loadStages();
  } finally {
    nextTick(() => { if (!isDragging.value) syncStages(); });
  }
};

const openConversation = conversation => {
  if (isDragging.value) return;
  router.push({
    name: 'inbox_conversation',
    params: { accountId: accountId.value, conversation_id: conversation.id },
  });
};

const openContact = conversation => {
  if (isDragging.value) return;
  const contactId = conversation.meta?.sender?.id;
  if (!contactId) return;
  router.push({
    name: 'contacts_edit',
    params: { accountId: accountId.value, contactId },
  });
};

const totalConversationsByStage = computed(() => {
  const totals = {};
  localStages.value.forEach(stage => { totals[stage.id] = stage.conversations?.length || 0; });
  return totals;
});

const unassignedCount = computed(() => unassignedConversations.value.length);

const statusColor = status => {
  switch (status) {
    case 'open': return 'bg-n-brand text-white';
    case 'resolved': return 'bg-n-slate-9 text-white';
    case 'pending': return 'bg-n-yellow-9 text-white';
    case 'snoozed': return 'bg-n-yellow-9 text-white';
    default: return 'bg-n-slate-3 text-n-slate-11';
  }
};

const priorityColor = priority => {
  if (priority === 'urgent' || priority === 'high') return 'text-n-ruby-9';
  if (priority === 'medium') return 'text-n-yellow-9';
  return 'text-n-slate-9';
};

const priorityIcon = priority => {
  if (priority === 'urgent') return 'i-lucide-alert-circle';
  if (priority === 'high') return 'i-lucide-arrow-up';
  if (priority === 'medium') return 'i-lucide-minus';
  if (priority === 'low') return 'i-lucide-arrow-down';
  return null;
};

const formatDate = ts => {
  if (!ts) return '-';
  return new Date(ts * 1000).toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit', year: '2-digit' });
};

watch([kanbanStages, allConversations, stageItems, filteredConversations], () => { syncStages(); }, { deep: true });

onMounted(() => { loadData(); });
onActivated(() => { loadData(); });
</script>

<template>
  <div class="flex flex-col w-full h-full bg-n-surface-1" @click="showStatusMenu = false; showPriorityMenu = false">
    <!-- Header -->
    <div class="flex items-center justify-between px-4 py-3 border-b border-n-weak">
      <div class="flex items-center gap-3">
        <!-- Funnel Selector -->
        <div class="relative">
          <button
            class="flex items-center gap-2 px-3 py-1.5 rounded-lg border border-n-weak bg-n-surface-2 text-sm font-semibold text-n-slate-12 hover:border-n-brand/50 hover:bg-n-alpha-2 transition-all"
            @click.stop="showFunnelMenu = !showFunnelMenu"
          >
            <i class="i-lucide-git-branch text-n-slate-10 text-xs" />
            <span class="max-w-[160px] truncate">{{ activeFunnel?.name || 'Selecionar funil' }}</span>
            <i class="i-lucide-chevron-down text-n-slate-9 text-xs" />
          </button>

          <div
            v-if="showFunnelMenu"
            v-click-outside="() => { showFunnelMenu = false; showNewFunnelInput = false; }"
            class="absolute left-0 top-full mt-1 w-64 bg-n-surface-1 border border-n-weak rounded-xl shadow-lg z-50 py-1"
          >
            <div
              v-for="funnel in funnels"
              :key="funnel.id"
              class="group flex items-center gap-2 px-3 py-2 hover:bg-n-alpha-2 cursor-pointer"
            >
              <template v-if="editingFunnelId === funnel.id">
                <input
                  v-model="editingFunnelName"
                  class="flex-1 text-sm bg-n-surface-2 border border-n-weak rounded px-2 py-0.5 text-n-slate-12 focus:outline-none focus:ring-1 focus:ring-n-brand"
                  @keyup.enter="saveEditFunnel"
                  @keyup.escape="editingFunnelId = null"
                  @click.stop
                />
                <button class="text-n-brand text-xs px-1 hover:opacity-70" @click.stop="saveEditFunnel">
                  <i class="i-lucide-check" />
                </button>
              </template>
              <template v-else>
                <i
                  class="i-lucide-check text-n-brand text-xs flex-shrink-0"
                  :class="activeFunnelId === funnel.id ? 'opacity-100' : 'opacity-0'"
                />
                <span class="flex-1 text-sm text-n-slate-12 truncate" @click="selectFunnel(funnel.id)">
                  {{ funnel.name }}
                </span>
                <div class="flex items-center gap-1 opacity-0 group-hover:opacity-100">
                  <button class="text-n-slate-10 hover:text-n-slate-12 p-0.5" title="Renomear" @click.stop="startEditFunnel(funnel)">
                    <i class="i-lucide-pencil text-xs" />
                  </button>
                  <button
                    v-if="funnels.length > 1"
                    class="text-n-ruby-9 hover:text-n-ruby-11 p-0.5"
                    title="Excluir"
                    @click.stop="deleteFunnel(funnel)"
                  >
                    <i class="i-lucide-trash-2 text-xs" />
                  </button>
                </div>
              </template>
            </div>

            <div class="border-t border-n-weak my-1" />

            <div v-if="showNewFunnelInput" class="px-3 py-2 flex items-center gap-2">
              <input
                v-model="newFunnelName"
                placeholder="Nome do funil"
                class="flex-1 text-sm bg-n-surface-2 border border-n-weak rounded px-2 py-1 text-n-slate-12 focus:outline-none focus:ring-1 focus:ring-n-brand"
                @keyup.enter="createFunnel"
                @keyup.escape="showNewFunnelInput = false"
              />
              <button class="text-n-brand text-xs px-1 hover:opacity-70" @click="createFunnel">
                <i class="i-lucide-check" />
              </button>
            </div>
            <button
              v-else
              class="w-full flex items-center gap-2 px-3 py-2 text-sm text-n-brand hover:bg-n-alpha-2"
              @click="showNewFunnelInput = true"
            >
              <i class="i-lucide-plus text-xs" />
              Novo funil
            </button>
          </div>
        </div>

        <!-- Divider -->
        <div class="w-px h-6 bg-n-weak" />

        <!-- Agent avatars (filterable) -->
        <div v-if="activeAgents.length > 0" class="flex items-center gap-1">
          <button
            v-for="agent in activeAgents.slice(0, 6)"
            :key="agent.id"
            v-tooltip.bottom="agent.name"
            class="relative transition-all rounded-full flex-shrink-0 w-7 h-7 p-0 flex items-center justify-center"
            :class="filterAgentId === agent.id ? 'ring-2 ring-n-brand' : 'opacity-60 hover:opacity-100'"
            @click.stop="toggleAgentFilter(agent.id)"
          >
            <Avatar
              :src="agent.thumbnail"
              :username="agent.name"
              :size="28"
              :rounded-full="true"
            />
          </button>
          <span v-if="activeAgents.length > 6" class="flex items-center justify-center w-7 h-7 rounded-full bg-n-alpha-2 text-[10px] font-semibold text-n-slate-11 border border-n-weak">
            +{{ activeAgents.length - 6 }}
          </span>
        </div>

        <!-- Total count -->
        <span class="text-xs text-n-slate-9 font-medium">
          {{ totalFiltered }} conversa{{ totalFiltered !== 1 ? 's' : '' }}
        </span>
      </div>

      <!-- Right side: view tabs + actions -->
      <div class="flex items-center gap-2">
        <!-- View mode tabs -->
        <div class="flex items-center rounded-lg border border-n-weak bg-n-surface-2 p-0.5">
          <button
            class="flex items-center gap-1.5 px-2.5 py-1 rounded-md text-xs font-medium transition-all"
            :class="viewMode === 'board' ? 'bg-n-surface-1 text-n-slate-12 shadow-sm' : 'text-n-slate-10 hover:text-n-slate-12'"
            @click="viewMode = 'board'"
          >
            <i class="i-lucide-layout-dashboard text-xs" />
            Board
          </button>
          <button
            class="flex items-center gap-1.5 px-2.5 py-1 rounded-md text-xs font-medium transition-all"
            :class="viewMode === 'list' ? 'bg-n-surface-1 text-n-slate-12 shadow-sm' : 'text-n-slate-10 hover:text-n-slate-12'"
            @click="viewMode = 'list'"
          >
            <i class="i-lucide-list text-xs" />
            Lista
          </button>
        </div>

        <div class="w-px h-5 bg-n-weak" />

        <Button
          v-if="activeFunnelId"
          variant="ghost"
          color="slate"
          size="sm"
          icon="i-lucide-settings"
          @click="router.push({ name: 'kanban_funnel_settings', params: { accountId, funnelId: activeFunnelId } })"
        />
        <Button
          variant="ghost"
          color="slate"
          size="sm"
          icon="i-lucide-refresh-cw"
          @click="loadData"
        />
      </div>
    </div>

    <!-- Filter bar -->
    <div class="flex items-center gap-2 px-4 py-2 border-b border-n-weak bg-n-surface-2/50">
      <i class="i-lucide-sliders-horizontal text-n-slate-9 text-xs flex-shrink-0" />
      <span class="text-xs text-n-slate-9 font-medium flex-shrink-0">Filtros:</span>

      <!-- Status filter -->
      <div class="relative" @click.stop>
        <button
          class="flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-medium border transition-all"
          :class="filterStatus !== 'all'
            ? 'bg-n-brand/10 text-n-brand border-n-brand/30'
            : 'bg-n-surface-1 text-n-slate-10 border-n-weak hover:text-n-slate-12 hover:border-n-brand/30'"
          @click="showStatusMenu = !showStatusMenu; showPriorityMenu = false"
        >
          <i class="i-lucide-circle-dot text-xs" />
          {{ activeStatusLabel }}
          <i class="i-lucide-chevron-down text-[10px]" />
        </button>
        <div
          v-if="showStatusMenu"
          class="absolute left-0 top-full mt-1 w-44 bg-n-surface-1 border border-n-weak rounded-lg shadow-lg z-50 py-1"
        >
          <button
            v-for="opt in statusOptions"
            :key="opt.value"
            class="w-full flex items-center gap-2 px-3 py-1.5 text-xs hover:bg-n-alpha-2 transition-colors"
            :class="filterStatus === opt.value ? 'text-n-brand font-medium' : 'text-n-slate-11'"
            @click="filterStatus = opt.value; showStatusMenu = false"
          >
            <i :class="[opt.icon, 'text-xs']" />
            {{ opt.label }}
            <i v-if="filterStatus === opt.value" class="i-lucide-check text-xs ml-auto text-n-brand" />
          </button>
        </div>
      </div>

      <!-- Priority filter -->
      <div class="relative" @click.stop>
        <button
          class="flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-medium border transition-all"
          :class="filterPriority !== 'all'
            ? 'bg-n-brand/10 text-n-brand border-n-brand/30'
            : 'bg-n-surface-1 text-n-slate-10 border-n-weak hover:text-n-slate-12 hover:border-n-brand/30'"
          @click="showPriorityMenu = !showPriorityMenu; showStatusMenu = false"
        >
          <i class="i-lucide-flag text-xs" />
          {{ activePriorityLabel }}
          <i class="i-lucide-chevron-down text-[10px]" />
        </button>
        <div
          v-if="showPriorityMenu"
          class="absolute left-0 top-full mt-1 w-48 bg-n-surface-1 border border-n-weak rounded-lg shadow-lg z-50 py-1"
        >
          <button
            v-for="opt in priorityOptions"
            :key="opt.value"
            class="w-full flex items-center gap-2 px-3 py-1.5 text-xs hover:bg-n-alpha-2 transition-colors"
            :class="filterPriority === opt.value ? 'text-n-brand font-medium' : 'text-n-slate-11'"
            @click="filterPriority = opt.value; showPriorityMenu = false"
          >
            <i :class="[opt.icon, opt.color || 'text-n-slate-9', 'text-xs']" />
            {{ opt.label }}
            <i v-if="filterPriority === opt.value" class="i-lucide-check text-xs ml-auto text-n-brand" />
          </button>
        </div>
      </div>

      <!-- Agent filter chip (when active) -->
      <div
        v-if="filterAgentId !== null"
        class="flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-xs font-medium bg-n-brand/10 text-n-brand border border-n-brand/30"
      >
        <Avatar
          :src="activeAgents.find(a => a.id === filterAgentId)?.thumbnail"
          :username="activeAgents.find(a => a.id === filterAgentId)?.name"
          :size="16"
          :rounded-full="true"
        />
        {{ activeAgents.find(a => a.id === filterAgentId)?.name }}
        <button class="ml-0.5 hover:opacity-70" @click.stop="filterAgentId = null">
          <i class="i-lucide-x text-[10px]" />
        </button>
      </div>

      <!-- Clear all -->
      <button
        v-if="hasActiveFilters"
        class="flex items-center gap-1 text-xs text-n-ruby-9 hover:text-n-ruby-11 ml-1 transition-colors"
        @click.stop="clearFilters"
      >
        <i class="i-lucide-x text-xs" />
        Limpar filtros
      </button>
    </div>

    <!-- No funnel selected -->
    <div v-if="!activeFunnelId && !isLoading" class="flex flex-col items-center justify-center flex-1">
      <div class="flex flex-col items-center max-w-lg p-8 text-center">
        <div class="flex items-center justify-center w-20 h-20 mb-6 rounded-full bg-n-alpha-2 text-n-slate-11">
          <i class="i-lucide-git-branch text-4xl" />
        </div>
        <h2 class="mb-3 text-xl font-semibold text-n-slate-12">Nenhum funil criado</h2>
        <p class="mb-8 text-base text-n-slate-11">Crie um funil para organizar seu fluxo de atendimento.</p>
        <Button variant="primary" size="large" icon="i-lucide-plus" @click="showNewFunnelInput = true; showFunnelMenu = true">
          Criar primeiro funil
        </Button>
      </div>
    </div>

    <!-- Loading -->
    <div v-else-if="isLoading" class="flex flex-1 items-center justify-center">
      <span class="w-6 h-6 border-2 border-n-weak border-t-n-brand rounded-full animate-spin" />
    </div>

    <!-- ==================== BOARD VIEW ==================== -->
    <div v-else-if="viewMode === 'board' && localStages.length > 0" class="flex flex-1 gap-4 p-4 overflow-x-auto">

      <!-- "Leads novos" column -->
      <div v-if="activeFunnel?.show_unassigned !== false" class="flex flex-col flex-shrink-0 w-72 bg-n-surface-2 rounded-lg border border-n-weak border-dashed">
        <div class="flex items-center gap-2 p-3 border-b border-n-weak">
          <div class="w-2.5 h-2.5 rounded-full bg-n-slate-7" />
          <h3 class="text-sm font-semibold text-n-slate-10">Leads novos</h3>
          <span class="px-1.5 py-0.5 text-[10px] font-medium rounded-full bg-n-alpha-2 text-n-surface-on-text-subtle">
            {{ unassignedCount }}
          </span>
        </div>
        <Draggable
          v-model="unassignedConversations"
          group="conversations"
          item-key="id"
          class="flex flex-col flex-1 gap-2 p-2 overflow-y-auto min-h-[200px]"
          ghost-class="ghost"
          drag-class="dragging"
          :animation="200"
          @change="evt => onConversationMove(evt, UNASSIGNED_STAGE_ID)"
          @start="isDragging = true"
          @end="isDragging = false"
        >
          <template #item="{ element: conversation }">
            <KanbanCard
              :conversation="conversation"
              :stage-id="null"
              @open-conversation="openConversation"
              @open-contact="openContact"
              @context-menu="handleCardContextMenu"
            />
          </template>
          <template #footer>
            <div v-if="unassignedConversations.length === 0" class="flex flex-col items-center justify-center py-8 text-n-slate-9 text-xs text-center">
              <i class="i-lucide-inbox text-xl mb-2 opacity-40" />
              <span>Arraste cards aqui para remover do estágio</span>
            </div>
          </template>
        </Draggable>
      </div>

      <!-- Stage columns -->
      <div
        v-for="stage in localStages"
        :key="stage.id"
        class="flex flex-col flex-shrink-0 w-72 rounded-lg border bg-n-surface-2 border-n-weak"
      >
        <!-- Column header -->
        <div class="flex items-center gap-2 px-3 py-2.5 border-b border-n-weak">
          <div
            class="w-2.5 h-2.5 rounded-full flex-shrink-0"
            :style="{ backgroundColor: stage.color?.startsWith('#') ? stage.color : '#64748b' }"
          />
          <h3 class="text-sm font-semibold truncate flex-1 text-n-surface-on-text-default">{{ stage.name }}</h3>
          <span
            v-if="stage.stage_type === 'won' || stage.stage_type === 'lost'"
            class="text-[9px] px-1.5 py-0.5 rounded font-semibold flex-shrink-0"
            :style="{ background: (stage.color || '#64748b') + '22', color: stage.color || '#64748b' }"
          >{{ stage.stage_type === 'won' ? 'GANHO' : 'PERDIDO' }}</span>
          <span class="px-1.5 py-0.5 text-[10px] font-medium rounded-full bg-n-alpha-2 text-n-surface-on-text-subtle flex-shrink-0">
            {{ totalConversationsByStage[stage.id] }}
          </span>
        </div>

        <Draggable
          v-model="stage.conversations"
          group="conversations"
          item-key="id"
          class="flex flex-col flex-1 gap-2 p-2 overflow-y-auto min-h-[200px]"
          ghost-class="ghost"
          drag-class="dragging"
          :animation="200"
          @change="evt => onConversationMove(evt, stage.id, stage.stage_type || 'regular')"
          @start="isDragging = true"
          @end="isDragging = false"
        >
          <template #item="{ element: conversation }">
            <KanbanCard
              :conversation="conversation"
              :stage-id="stage.id"
              :stage-type="stage.stage_type"
              @open-conversation="openConversation"
              @open-contact="openContact"
              @context-menu="handleCardContextMenu"
            />
          </template>
        </Draggable>
      </div>
    </div>

    <!-- ==================== LIST VIEW ==================== -->
    <div v-else-if="viewMode === 'list' && localStages.length > 0" class="flex flex-1 flex-col overflow-auto p-4 gap-4">

      <div v-for="group in listGroups" :key="group.id" class="flex flex-col gap-2">
        <!-- Group header -->
        <div class="flex items-center gap-2 px-1">
          <div
            class="w-3 h-3 rounded-sm flex-shrink-0"
            :style="{ backgroundColor: group.color?.startsWith('#') ? group.color : '#64748b' }"
          />
          <span class="text-sm font-bold text-n-slate-12">{{ group.name }}</span>
          <span class="text-xs text-n-slate-9 bg-n-alpha-2 px-2 py-0.5 rounded-full font-medium">{{ group.conversations.length }}</span>
        </div>

        <!-- Cards horizontais -->
        <div
          v-for="conv in group.conversations"
          :key="conv.id"
          class="flex items-center gap-4 px-4 py-3 bg-n-surface-1 rounded-xl border border-n-weak hover:border-n-brand/40 hover:shadow-sm transition-all"
          @contextmenu.prevent="handleCardContextMenu($event, conv)"
        >
          <!-- Avatar contato (grande) -->
          <Avatar
            :src="conv.meta?.sender?.thumbnail"
            :username="conv.meta?.sender?.name"
            :size="40"
            class="flex-shrink-0"
          />

          <!-- Nome + inbox + número -->
          <div class="flex flex-col min-w-0 w-44 flex-shrink-0">
            <span class="text-sm font-semibold text-n-slate-12 truncate leading-tight">
              {{ conv.meta?.sender?.name || 'Sem nome' }}
            </span>
            <span class="text-xs text-n-slate-9 truncate">
              #{{ conv.id }}
              <template v-if="conv.inbox_id && store.getters['inboxes/getInbox'](conv.inbox_id)?.name">
                · {{ store.getters['inboxes/getInbox'](conv.inbox_id).name }}
              </template>
            </span>
          </div>

          <!-- Status -->
          <span
            class="text-[10px] px-2.5 py-1 rounded-full font-bold uppercase tracking-wide flex-shrink-0 hidden sm:block"
            :class="statusColor(conv.status)"
          >
            {{ conv.status }}
          </span>

          <!-- Prioridade -->
          <div class="flex-shrink-0 w-6 flex justify-center hidden md:flex">
            <i
              v-if="conv.priority"
              :class="[priorityIcon(conv.priority), priorityColor(conv.priority), 'text-base']"
              :title="conv.priority"
            />
            <span v-else class="text-n-slate-7 text-xs">—</span>
          </div>

          <!-- Valor -->
          <div class="flex-1 min-w-0 hidden lg:block">
            <span
              v-if="(conv.additional_attributes?.deal_value ?? conv.custom_attributes?.deal_value) != null"
              class="text-sm font-semibold text-n-slate-12"
            >
              {{ Number(conv.additional_attributes?.deal_value ?? conv.custom_attributes?.deal_value).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' }) }}
            </span>
            <span v-else class="text-xs text-n-slate-7">Sem valor</span>
          </div>

          <!-- Data -->
          <span class="text-xs text-n-slate-9 flex-shrink-0 w-20 text-right hidden xl:block">
            {{ formatDate(conv.created_at) }}
          </span>

          <!-- Divisor -->
          <div class="w-px h-8 bg-n-weak flex-shrink-0 hidden md:block" />

          <!-- Agente (avatar grande + nome) -->
          <div class="flex items-center gap-2.5 flex-shrink-0 w-40">
            <template v-if="conv.meta?.assignee">
              <Avatar
                :src="conv.meta.assignee.thumbnail"
                :username="conv.meta.assignee.name"
                :size="36"
                class="flex-shrink-0"
              />
              <div class="flex flex-col min-w-0">
                <span class="text-xs font-semibold text-n-slate-12 truncate leading-tight">
                  {{ conv.meta.assignee.name }}
                </span>
                <span class="text-[10px] text-n-slate-9">Responsável</span>
              </div>
            </template>
            <template v-else>
              <div class="w-9 h-9 rounded-full bg-n-alpha-2 flex items-center justify-center border border-dashed border-n-weak flex-shrink-0">
                <i class="i-lucide-user-round text-n-slate-9 text-sm" />
              </div>
              <div class="flex flex-col min-w-0">
                <span class="text-xs text-n-slate-9 italic">Sem agente</span>
                <span class="text-[10px] text-n-slate-8">Não atribuído</span>
              </div>
            </template>
          </div>

          <!-- Navigation buttons -->
          <div class="flex items-center gap-1 flex-shrink-0">
            <Button
              v-tooltip.bottom="'Conversa'"
              icon="i-lucide-message-square"
              variant="ghost"
              color="slate"
              size="xs"
              @click.stop="openConversation(conv)"
            />
            <Button
              v-tooltip.bottom="'Contato'"
              icon="i-lucide-user-round"
              variant="ghost"
              color="slate"
              size="xs"
              @click.stop="openContact(conv)"
            />
          </div>
        </div>

        <!-- Grupo vazio -->
        <div v-if="group.conversations.length === 0" class="flex items-center gap-2 px-4 py-3 text-xs text-n-slate-8 italic border border-dashed border-n-weak/60 rounded-xl">
          <i class="i-lucide-inbox text-sm opacity-40" />
          Nenhuma conversa neste estágio
        </div>
      </div>

      <!-- Sem resultados com filtros -->
      <div v-if="listGroups.every(g => g.conversations.length === 0) && hasActiveFilters" class="flex flex-col items-center justify-center flex-1 py-16 text-n-slate-9">
        <i class="i-lucide-search-x text-3xl mb-3 opacity-50" />
        <p class="text-sm font-medium">Nenhuma conversa encontrada com os filtros aplicados</p>
        <button class="mt-3 text-xs text-n-brand hover:underline" @click="clearFilters">Limpar filtros</button>
      </div>
    </div>

    <!-- Empty stages -->
    <div v-else-if="activeFunnelId && !isLoading" class="flex flex-col items-center justify-center flex-1 w-full bg-n-surface-1">
      <div class="flex flex-col items-center max-w-lg p-8 text-center">
        <div class="flex items-center justify-center w-20 h-20 mb-6 rounded-full bg-n-alpha-2 text-n-slate-11">
          <i class="i-lucide-layout-list text-4xl" />
        </div>
        <h2 class="mb-3 text-xl font-semibold text-n-slate-12">Nenhum estágio neste funil</h2>
        <p class="mb-8 text-base text-n-slate-11">Configure os estágios para começar a organizar suas conversas.</p>
        <Button variant="primary" size="large" icon="i-lucide-plus" @click="router.push({ name: 'kanban_funnel_settings', params: { accountId, funnelId: activeFunnelId } })">
          Configurar estágios
        </Button>
      </div>
    </div>
  </div>

  <!-- Won modal -->
  <KanbanWonModal
    v-if="showWonModal && pendingMove"
    :conversation="pendingMove.conversation"
    :stage-name="localStages.find(s => s.id === pendingMove.stageId)?.name || 'Venda Ganha'"
    @confirm="confirmWon"
    @cancel="cancelPendingMove"
  />

  <!-- Lost modal -->
  <KanbanLostModal
    v-if="showLostModal && pendingMove"
    :conversation="pendingMove.conversation"
    :stage-name="localStages.find(s => s.id === pendingMove.stageId)?.name || 'Perdido'"
    @confirm="confirmLost"
    @cancel="cancelPendingMove"
  />

  <KanbanSettingsModal
    :show="showSettings"
    :funnel-id="activeFunnelId"
    :funnel-name="activeFunnel?.name"
    @close="showSettings = false"
    @update="loadStages"
    @update:show="value => showSettings = value"
  />

  <ContextMenu
    v-if="showContextMenu"
    :x="contextMenuPosition.x"
    :y="contextMenuPosition.y"
    @close="closeContextMenu"
  >
    <ConversationContextMenu
      :status="activeConversation.status"
      :inbox-id="activeConversation.inbox_id"
      :priority="activeConversation.priority"
      :chat-id="activeConversation.id"
      :has-unread-messages="activeConversation.unread_count > 0"
      :allowed-options="['assignAgent', 'assignTeam', 'assignLabel', 'priority', 'status', 'markAsRead', 'markAsUnread']"
      @update-conversation="onUpdateStatus"
      @assign-agent="onAssignAgent"
      @assign-team="onAssignTeam"
      @assign-label="onAssignLabel"
      @assign-priority="onAssignPriority"
      @mark-as-read="onMarkAsRead"
      @mark-as-unread="onMarkAsUnread"
      @delete-conversation="onDeleteConversation"
      @close="closeContextMenu"
    />
  </ContextMenu>
</template>

<style scoped>
.ghost {
  opacity: 0.4;
  background: var(--n-alpha-2);
}
.dragging {
  opacity: 0.9;
  transform: rotate(2deg);
  box-shadow: 0 8px 25px rgba(0, 0, 0, 0.15);
}
</style>
