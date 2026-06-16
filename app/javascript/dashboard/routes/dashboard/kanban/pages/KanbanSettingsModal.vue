<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Draggable from 'vuedraggable';

import Modal from 'dashboard/components/Modal.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import AutomationActionInput from 'dashboard/components/widgets/AutomationActionInput.vue';
import KanbanStageAutomationsPanel from '../components/KanbanStageAutomationsPanel.vue';
import KanbanLossReasonsTab from '../components/KanbanLossReasonsTab.vue';
import { useAutomation } from 'dashboard/composables/useAutomation';
import { AUTOMATION_ACTION_TYPES } from 'dashboard/routes/dashboard/settings/automation/constants';
import { showActionInput, generateAutomationPayload } from 'dashboard/helper/automationHelper';

const props = defineProps({
  show: { type: Boolean, default: false },
  funnelId: { type: Number, default: null },
  funnelName: { type: String, default: '' },
});

const emit = defineEmits(['close', 'update', 'update:show']);

const { t } = useI18n();
const store = useStore();

const localStages = ref([]);
const editingStage = ref(null);
const showEditModal = ref(false);
const isLoadingStages = ref(false);
const activeTab = ref('stages'); // 'general' | 'stages' | 'automations' | 'loss_reasons'
const expandedStageId = ref(null);

// ── Geral (funnel-level settings) ──
const allInboxes  = computed(() => store.getters['inboxes/getInboxes'] || []);
const funnelRecord = computed(() => store.getters['kanbanFunnels/getKanbanFunnelById'](props.funnelId));
const editFunnelName   = ref('');
const editFunnelInboxIds = ref([]);
const isSavingGeneral = ref(false);

const toggleInbox = id => {
  const idx = editFunnelInboxIds.value.indexOf(id);
  if (idx === -1) editFunnelInboxIds.value.push(id);
  else editFunnelInboxIds.value.splice(idx, 1);
};

const saveGeneral = async () => {
  if (!editFunnelName.value.trim()) return;
  isSavingGeneral.value = true;
  try {
    await store.dispatch('kanbanFunnels/update', {
      id: props.funnelId,
      kanban_funnel: { name: editFunnelName.value.trim(), inbox_ids: editFunnelInboxIds.value },
    });
    emit('update');
    useAlert('Configurações salvas');
  } finally {
    isSavingGeneral.value = false;
  }
};

// Special stages helpers
const wonStage = computed(() => localStages.value.find(s => s.stage_type === 'won'));
const lostStage = computed(() => localStages.value.find(s => s.stage_type === 'lost'));

const toggleSpecialStage = async (type) => {
  const existing = type === 'won' ? wonStage.value : lostStage.value;
  if (existing) {
    if (!confirm(`Desativar o estágio "${existing.name}"? Ele será excluído.`)) return;
    await store.dispatch('kanbanStages/delete', { funnelId: props.funnelId, id: existing.id });
    await loadStages();
    return;
  }
  const defaults = {
    won: { name: 'Venda Ganha', color: '#f59e0b', stage_type: 'won' },
    lost: { name: 'Perdido', color: '#ef4444', stage_type: 'lost' },
  };
  await store.dispatch('kanbanStages/create', { funnelId: props.funnelId, ...defaults[type] });
  await loadStages();
};

const kanbanStages = computed(() => store.getters['kanbanStages/getKanbanStages']);
const labels = computed(() => store.getters['labels/getLabels']);
const uiFlags = computed(() => store.getters['kanbanStages/getUIFlags']);
const userAutomations = computed(() => store.getters['automations/getAutomations']);

// Automation Logic
const {
  automation: stageAutomation,
  appendNewAction,
  removeAction,
  resetAction,
  getActionDropdownValues,
  manifestCustomAttributes, // ensure attributes are loaded
} = useAutomation(null);

const automationActionTypes = computed(() => {
  return AUTOMATION_ACTION_TYPES.map(action => ({
    ...action,
    label: t(`AUTOMATION.ACTIONS.${action.label}`),
  }));
});

const availableColors = [
  { value: 'bg-blue-500', label: t('CONTACTS_KANBAN.COLORS.BLUE') },
  { value: 'bg-green-500', label: t('CONTACTS_KANBAN.COLORS.GREEN') },
  { value: 'bg-yellow-500', label: t('CONTACTS_KANBAN.COLORS.YELLOW') },
  { value: 'bg-red-500', label: t('CONTACTS_KANBAN.COLORS.RED') },
  { value: 'bg-purple-500', label: t('CONTACTS_KANBAN.COLORS.PURPLE') },
  { value: 'bg-pink-500', label: t('CONTACTS_KANBAN.COLORS.PINK') },
  { value: 'bg-indigo-500', label: t('CONTACTS_KANBAN.COLORS.INDIGO') },
  { value: 'bg-gray-500', label: t('CONTACTS_KANBAN.COLORS.GRAY') },
];

const loadStages = async () => {
  if (!props.funnelId) return;
  isLoadingStages.value = true;
  try {
    await store.dispatch('kanbanStages/get', props.funnelId);
    // Map with label color override
    const stages = kanbanStages.value || [];
    const allLabels = store.getters['labels/getLabels'] || [];

    localStages.value = stages.map(stage => {
       const linkedLabel = allLabels.find(l => l.id === stage.label_id);
       return {
          ...stage,
          color: linkedLabel ? linkedLabel.color : '#64748b'
       };
    });
    
    // Ensure automations and other resources are loaded for settings
    await Promise.all([
      store.dispatch('automations/get'),
      store.dispatch('agents/get'),
      store.dispatch('teams/get'),
      store.dispatch('labels/get'),
      store.dispatch('inboxes/get'),
      store.dispatch('attributes/get'),
      store.dispatch('kanbanFunnels/get'),
    ]);
    manifestCustomAttributes();
    // Init general tab from store
    const rec = store.getters['kanbanFunnels/getKanbanFunnelById'](props.funnelId);
    editFunnelName.value = rec?.name ?? props.funnelName ?? '';
    editFunnelInboxIds.value = rec?.inbox_ids ? [...rec.inbox_ids] : [];
  } catch (error) {
    console.error('Error loading stages:', error);
    useAlert(t('CONTACTS_KANBAN.SETTINGS.LOAD_ERROR') || 'Erro ao carregar estágios');
    localStages.value = [];
  } finally {
    isLoadingStages.value = false;
  }
};

watch(() => props.show, (newVal) => {
  if (newVal) {
    loadStages();
  }
});

// Watch for Label changes in Edit Modal to sync Color
watch(() => editingStage.value?.label_id, (newLabelId) => {
  if (!editingStage.value) return; // Guard against null when modal closes

  if (newLabelId) {
    const label = labels.value.find(l => l.id === newLabelId);
    if (label && label.color) {
       editingStage.value.color = label.color;
    }
  } else {
    // If tag is removed, reset to default gray
    editingStage.value.color = '#64748b';
  }
});

const initAutomation = (stageName = '') => {
  stageAutomation.value = {
    name: `Kanban: ${stageName}`,
    description: `Auto-generated for Kanban Stage: ${stageName}`,
    event_name: 'conversation_updated',
    conditions: [], // Will be set on save to match label
    actions: [], // User configures this
  };
};

const findAutomationForStage = (labelId, stageName) => {
  // 1. Try finding by Label Title (Tags use name/title as ID in automations)
  if (labelId) {
    const label = labels.value.find(l => l.id === labelId);
    if (label) {
        // Automation saves tags as strings (titles)
      const byLabel = userAutomations.value.find(a => 
        a.event_name === 'conversation_updated' &&
        a.conditions.some(c => 
          c.attribute_key === 'labels' && 
          (c.values.includes(label.title) || c.values.some(v => v?.id === label.title))
        )
      );
      if (byLabel) return byLabel;
    }
  }

  // 2. Fallback: Find by Name
  if (stageName) {
     return userAutomations.value.find(a => a.name === `Kanban: ${stageName}`);
  }

  return null;
};

const addNewStage = () => {
  editingStage.value = {
    id: null,
    name: '',
    color: '#64748b',
    label_id: null,
    position: localStages.value.length,
  };
  initAutomation();
  showEditModal.value = true;
};

const editStage = stage => {
  editingStage.value = { ...stage };
  const existingRule = findAutomationForStage(stage.label_id, stage.name);
  if (existingRule) {
    stageAutomation.value = JSON.parse(JSON.stringify(existingRule));
    // Hydrate labels conditions if they are strings (title)
    stageAutomation.value.conditions = stageAutomation.value.conditions.map(c => {
       if (c.attribute_key === 'labels' && c.values && c.values.length > 0) {
          if (typeof c.values[0] !== 'object') {
             const labelObjs = c.values.map(title => ({ id: title, name: title }));
             return { ...c, values: labelObjs };
          }
       }
       return c;
    });

    // Hydrate actions (agents, teams) so they show up in dropdowns
    stageAutomation.value.actions = stageAutomation.value.actions.map(a => {
      // Assign Agent (search_select expects single object, not array)
      if (a.action_name === 'assign_agent' && a.action_params) {
         // Determine if it's already an array or single value
         const params = Array.isArray(a.action_params) ? a.action_params : [a.action_params];
         if (params.length === 0) return a;

         const agents = store.getters['agents/getAgents'];
         const hydratedParams = params.map(param => {
            if (typeof param === 'object') return param;
            return agents.find(agent => String(agent.id) === String(param)) || param;
         });
         // Unwrap array for search_select
         return { ...a, action_params: hydratedParams[0] };
      }
      // Assign Team (search_select expects single object)
      if (a.action_name === 'assign_team' && a.action_params) {
         const params = Array.isArray(a.action_params) ? a.action_params : [a.action_params];
         if (params.length === 0) return a;
         
         const teams = store.getters['teams/getTeams'];
         const hydratedParams = params.map(param => {
            if (typeof param === 'object') return param;
            return teams.find(team => String(team.id) === String(param)) || param;
         });
         // Unwrap array for search_select
         return { ...a, action_params: hydratedParams[0] };
      }
      return a;
    });
  } else {
    initAutomation(stage.name);
    // Pre-populate if label is selected
    if (stage.label_id) {
       const l = labels.value.find(x => x.id === stage.label_id);
       if (l) {
         stageAutomation.value.conditions = [{
            attribute_key: 'labels',
            filter_operator: 'equal_to',
            values: [{ id: l.title, name: l.title }],
            query_operator: 'and',
         }];
       }
    }
  }
  showEditModal.value = true;
};

const saveStage = async () => {
  if (!editingStage.value.name || !editingStage.value.name.trim()) {
    useAlert(t('CONTACTS_KANBAN.SETTINGS.NAME_REQUIRED') || 'Nome é obrigatório');
    return;
  }

  try {
    let stageId = editingStage.value.id;
    let savedLabelId = editingStage.value.label_id;

    // 1. Save Stage
    if (stageId) {
      await store.dispatch('kanbanStages/update', { funnelId: props.funnelId, ...editingStage.value });
      useAlert(t('CONTACTS_KANBAN.SETTINGS.STAGE_UPDATED') || 'Estágio atualizado');
    } else {
      const res = await store.dispatch('kanbanStages/create', { funnelId: props.funnelId, ...editingStage.value });
      stageId = res.id;
    }

    // 2. Save Automation (if label is present)
    if (savedLabelId && stageAutomation.value.actions.length > 0) {
      // Ensure conditions match current label (in case it changed)
      const labelObj = labels.value.find(l => String(l.id) === String(savedLabelId));
      stageAutomation.value.conditions = [{
        attribute_key: 'labels',
        filter_operator: 'equal_to',
        values: labelObj ? [{ id: labelObj.title, name: labelObj.title }] : [],
        query_operator: 'and',
      }];
      stageAutomation.value.name = `Kanban: ${editingStage.value.name}`;

      const payload = generateAutomationPayload(stageAutomation.value);

      if (stageAutomation.value.id) {
        await store.dispatch('automations/update', payload);
      } else {
        await store.dispatch('automations/create', payload);
      }
    }

    await loadStages();
    showEditModal.value = false;
    editingStage.value = null;
    emit('update');
  } catch (error) {
    console.error('Error saving stage:', error);
    useAlert(t('CONTACTS_KANBAN.SETTINGS.STAGE_ERROR') || 'Erro ao salvar estágio');
  }
};

const deleteStage = async id => {
  if (!confirm(t('CONTACTS_KANBAN.SETTINGS.DELETE_CONFIRM') || 'Tem certeza que deseja excluir este estágio?')) return;
  
  try {
    // Note: We are not deleting the automation rule automatically to be safe, 
    // but we could if we wanted to cleanup.
    await store.dispatch('kanbanStages/delete', { funnelId: props.funnelId, id });
    await loadStages();
    useAlert(t('CONTACTS_KANBAN.SETTINGS.STAGE_DELETED') || 'Estágio excluído');
    emit('update');
  } catch (error) {
    console.error('Error deleting stage:', error);
    useAlert(t('CONTACTS_KANBAN.SETTINGS.DELETE_ERROR') || 'Erro ao excluir estágio');
  }
};

const onDragEnd = async () => {
  try {
    const reorderedStages = localStages.value.map((stage, index) => ({
      id: stage.id,
      position: index,
    }));
    await store.dispatch('kanbanStages/reorder', { funnelId: props.funnelId, stages: reorderedStages });
    useAlert(t('CONTACTS_KANBAN.SETTINGS.ORDER_SAVED') || 'Ordem salva');
    await loadStages();
    emit('update');
  } catch (error) {
    console.error('Error reordering stages:', error);
    useAlert(t('CONTACTS_KANBAN.SETTINGS.ORDER_ERROR') || 'Erro ao reordenar');
    await loadStages();
  }
};

const close = () => {
  showEditModal.value = false;
  editingStage.value = null;
  emit('update:show', false);
  emit('close');
};
</script>

<template>
  <!-- ─── Stage List Modal ─────────────────────────────────────── -->
  <Modal :show="show" :on-close="close" size="large" :show-close-button="false">
    <div class="flex flex-col h-full max-h-[80vh]">

      <!-- Header -->
      <div class="flex items-center justify-between px-6 pt-5 pb-4 border-b border-n-weak flex-shrink-0">
        <div class="flex items-center gap-3">
          <div class="flex items-center justify-center w-9 h-9 rounded-lg bg-n-brand/10 flex-shrink-0">
            <i class="i-lucide-layout-dashboard text-n-brand text-base" />
          </div>
          <div>
            <h2 class="text-base font-semibold text-n-slate-12 leading-tight">
              {{ funnelName || $t('CONTACTS_KANBAN.SETTINGS.TITLE') }}
            </h2>
            <p class="text-xs text-n-slate-10 mt-0.5">Configurações do funil</p>
          </div>
        </div>
        <div class="flex items-center gap-2">
          <Button v-if="activeTab === 'stages'" size="sm" icon="i-lucide-plus" @click="addNewStage">
            Novo estágio
          </Button>
          <button
            class="flex items-center justify-center w-8 h-8 rounded-lg text-n-slate-9 hover:text-n-slate-12 hover:bg-n-alpha-2 transition-colors"
            @click="close"
          >
            <i class="i-lucide-x text-base" />
          </button>
        </div>
      </div>

      <!-- Tabs -->
      <div class="flex items-center gap-1 px-6 pt-3 pb-0 flex-shrink-0 border-b border-n-weak">
        <button
          class="px-3 py-2 text-sm font-medium border-b-2 -mb-px transition-colors"
          :class="activeTab === 'general'
            ? 'border-n-brand text-n-brand'
            : 'border-transparent text-n-slate-10 hover:text-n-slate-12'"
          @click="activeTab = 'general'"
        >
          <i class="i-lucide-settings-2 text-xs mr-1.5" />
          Geral
        </button>
        <button
          class="px-3 py-2 text-sm font-medium border-b-2 -mb-px transition-colors"
          :class="activeTab === 'stages'
            ? 'border-n-brand text-n-brand'
            : 'border-transparent text-n-slate-10 hover:text-n-slate-12'"
          @click="activeTab = 'stages'"
        >
          <i class="i-lucide-layers text-xs mr-1.5" />
          Estágios
        </button>
        <button
          class="px-3 py-2 text-sm font-medium border-b-2 -mb-px transition-colors"
          :class="activeTab === 'automations'
            ? 'border-n-brand text-n-brand'
            : 'border-transparent text-n-slate-10 hover:text-n-slate-12'"
          @click="activeTab = 'automations'"
        >
          <i class="i-lucide-zap text-xs mr-1.5" />
          Automações
        </button>
        <button
          class="px-3 py-2 text-sm font-medium border-b-2 -mb-px transition-colors"
          :class="activeTab === 'loss_reasons'
            ? 'border-n-brand text-n-brand'
            : 'border-transparent text-n-slate-10 hover:text-n-slate-12'"
          @click="activeTab = 'loss_reasons'"
        >
          <i class="i-lucide-flag text-xs mr-1.5" />
          Motivos de Perda
        </button>
      </div>

      <!-- Body -->
      <div class="flex-1 overflow-y-auto px-6 py-4">

        <!-- ── TAB: Geral ── -->
        <template v-if="activeTab === 'general'">
          <div class="flex flex-col gap-5">
            <!-- Funnel name -->
            <div class="space-y-1.5">
              <label class="text-xs font-semibold text-n-slate-11 uppercase tracking-wide">Nome do funil</label>
              <Input v-model="editFunnelName" placeholder="Nome do funil" />
            </div>

            <!-- Inbox multiselect -->
            <div class="space-y-2">
              <div class="flex items-center gap-1.5">
                <label class="text-xs font-semibold text-n-slate-11 uppercase tracking-wide">Caixas de entrada vinculadas</label>
                <span class="normal-case text-[10px] font-normal text-n-slate-9 bg-n-alpha-2 px-1.5 py-0.5 rounded">opcional</span>
              </div>
              <p class="text-xs text-n-slate-9 flex items-start gap-1.5">
                <i class="i-lucide-info flex-shrink-0 mt-0.5" />
                Conversas dessas caixas de entrada sem estágio aparecerão automaticamente em "Leads novos" deste funil.
              </p>
              <div class="flex flex-col gap-1.5 max-h-52 overflow-y-auto rounded-xl border border-n-weak p-2">
                <label
                  v-for="inbox in allInboxes"
                  :key="inbox.id"
                  class="flex items-center gap-3 px-3 py-2.5 rounded-lg cursor-pointer transition-colors hover:bg-n-alpha-1"
                  :class="editFunnelInboxIds.includes(inbox.id) ? 'bg-n-brand/5 border border-n-brand/20' : 'border border-transparent'"
                >
                  <input
                    type="checkbox"
                    class="accent-n-brand w-4 h-4 flex-shrink-0"
                    :checked="editFunnelInboxIds.includes(inbox.id)"
                    @change="toggleInbox(inbox.id)"
                  />
                  <div class="flex flex-col min-w-0">
                    <span class="text-sm font-medium text-n-slate-12 truncate">{{ inbox.name }}</span>
                    <span class="text-[11px] text-n-slate-9 truncate">{{ inbox.channel_type?.replace('Channel::', '') }}</span>
                  </div>
                </label>
                <div v-if="allInboxes.length === 0" class="py-4 text-center text-xs text-n-slate-9">
                  Nenhuma caixa de entrada encontrada
                </div>
              </div>
            </div>

            <div class="flex justify-end pt-2">
              <Button size="sm" :is-loading="isSavingGeneral" @click="saveGeneral">
                <i class="i-lucide-check text-sm mr-1" />
                Salvar configurações
              </Button>
            </div>
          </div>
        </template>

        <!-- Loading -->
        <div v-if="isLoadingStages && activeTab !== 'general'" class="flex flex-col items-center justify-center py-16 gap-3">
          <i class="i-lucide-loader-2 animate-spin text-2xl text-n-brand" />
          <span class="text-sm text-n-slate-10">Carregando estágios…</span>
        </div>

        <!-- ── TAB: Estágios ── -->
        <template v-if="!isLoadingStages && activeTab === 'stages'">
          <!-- Empty -->
          <div v-if="!localStages.length" class="flex flex-col items-center justify-center py-16 text-center gap-4">
            <div class="w-14 h-14 rounded-2xl bg-n-alpha-2 flex items-center justify-center">
              <i class="i-lucide-layers text-2xl text-n-slate-9" />
            </div>
            <div>
              <p class="text-sm font-medium text-n-slate-11">Nenhum estágio ainda</p>
              <p class="text-xs text-n-slate-9 mt-1">Crie o primeiro estágio para começar</p>
            </div>
            <Button size="sm" icon="i-lucide-plus" @click="addNewStage">
              Criar primeiro estágio
            </Button>
          </div>

          <!-- Stage rows -->
          <Draggable
            v-else
            v-model="localStages"
            item-key="id"
            class="flex flex-col gap-2"
            handle=".drag-handle"
            @end="onDragEnd"
          >
            <template #item="{ element: stage, index }">
              <div class="group flex items-center gap-3 p-3 rounded-xl border border-n-weak bg-n-surface-1 hover:border-n-brand/40 hover:bg-n-alpha-1 transition-all duration-150">

                <!-- Drag handle -->
                <div class="drag-handle cursor-grab active:cursor-grabbing flex-shrink-0 text-n-slate-8 hover:text-n-slate-11 transition-colors">
                  <i class="i-lucide-grip-vertical text-base" />
                </div>

                <!-- Position badge -->
                <span class="flex-shrink-0 w-5 h-5 rounded-full bg-n-alpha-2 text-[10px] font-semibold text-n-slate-10 flex items-center justify-center">
                  {{ index + 1 }}
                </span>

                <!-- Color dot -->
                <div
                  class="flex-shrink-0 w-3 h-3 rounded-full ring-2 ring-white/20 shadow-sm"
                  :style="{ backgroundColor: stage.color && stage.color.startsWith('#') ? stage.color : '#64748b' }"
                />

                <!-- Name -->
                <span class="flex-1 min-w-0 text-sm font-medium text-n-slate-12 truncate">
                  {{ stage.name }}
                </span>

                <!-- Tag pill -->
                <div class="flex-shrink-0">
                  <div
                    v-if="stage.label"
                    class="flex items-center gap-1.5 px-2 py-1 rounded-full text-[11px] font-medium"
                    :style="{ backgroundColor: (stage.label.color || '#64748b') + '20', color: stage.label.color || '#64748b' }"
                  >
                    <i class="i-lucide-tag text-[10px]" />
                    {{ stage.label.title }}
                  </div>
                  <span v-else class="text-[11px] text-n-slate-8 italic">Sem tag</span>
                </div>

                <!-- Actions (visible on hover) -->
                <div class="flex items-center gap-1 flex-shrink-0 opacity-0 group-hover:opacity-100 transition-opacity">
                  <button
                    v-tooltip.top="'Automações'"
                    class="p-1.5 rounded-lg text-n-slate-9 hover:text-n-brand hover:bg-n-brand/10 transition-colors"
                    @click="activeTab = 'automations'; expandedStageId = stage.id"
                  >
                    <i class="i-lucide-zap text-sm" />
                  </button>
                  <button
                    v-tooltip.top="'Editar'"
                    class="p-1.5 rounded-lg text-n-slate-9 hover:text-n-slate-12 hover:bg-n-alpha-2 transition-colors"
                    @click="editStage(stage)"
                  >
                    <i class="i-lucide-pencil text-sm" />
                  </button>
                  <button
                    v-tooltip.top="'Excluir'"
                    class="p-1.5 rounded-lg text-n-slate-9 hover:text-n-ruby-9 hover:bg-n-ruby-9/10 transition-colors"
                    @click="deleteStage(stage.id)"
                  >
                    <i class="i-lucide-trash-2 text-sm" />
                  </button>
                </div>
              </div>
            </template>
          </Draggable>
        </template>

        <!-- Special stages section -->
        <div v-if="!isLoadingStages && activeTab === 'stages'" class="mt-4 rounded-xl border border-n-weak overflow-hidden">
          <div class="px-4 py-3 bg-n-alpha-1 border-b border-n-weak flex items-center gap-2">
            <i class="i-lucide-star text-n-brand text-sm" />
            <span class="text-sm font-semibold text-n-slate-12">Estágios Especiais</span>
            <span class="text-xs text-n-slate-9 ml-1">Configure estágios de fechamento do funil</span>
          </div>
          <div class="divide-y divide-n-weak">
            <!-- Won -->
            <div class="flex items-center gap-3 px-4 py-3">
              <div class="w-8 h-8 rounded-lg bg-amber-400/15 flex items-center justify-center flex-shrink-0">
                <i class="i-lucide-trophy text-amber-500 text-sm" />
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-sm font-semibold text-n-slate-12">Venda Ganha</p>
                <p class="text-xs text-n-slate-9">Exige valor da venda ao mover um lead para este estágio</p>
              </div>
              <div class="flex items-center gap-2 flex-shrink-0">
                <span v-if="wonStage" class="text-xs text-amber-600 font-medium bg-amber-400/10 px-2 py-0.5 rounded truncate max-w-[100px]">{{ wonStage.name }}</span>
                <button
                  class="relative w-10 h-5 rounded-full transition-colors flex-shrink-0"
                  :class="wonStage ? 'bg-amber-400' : 'bg-n-slate-5'"
                  @click="toggleSpecialStage('won')"
                >
                  <span
                    class="absolute top-0.5 w-4 h-4 bg-white rounded-full shadow transition-all"
                    :class="wonStage ? 'left-5' : 'left-0.5'"
                  />
                </button>
              </div>
            </div>
            <!-- Lost -->
            <div class="flex items-center gap-3 px-4 py-3">
              <div class="w-8 h-8 rounded-lg bg-n-ruby-9/15 flex items-center justify-center flex-shrink-0">
                <i class="i-lucide-x-circle text-n-ruby-9 text-sm" />
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-sm font-semibold text-n-slate-12">Perdido</p>
                <p class="text-xs text-n-slate-9">Exige motivo de perda ao mover um lead para este estágio</p>
              </div>
              <div class="flex items-center gap-2 flex-shrink-0">
                <span v-if="lostStage" class="text-xs text-n-ruby-9 font-medium bg-n-ruby-9/10 px-2 py-0.5 rounded truncate max-w-[100px]">{{ lostStage.name }}</span>
                <button
                  class="relative w-10 h-5 rounded-full transition-colors flex-shrink-0"
                  :class="lostStage ? 'bg-n-ruby-9' : 'bg-n-slate-5'"
                  @click="toggleSpecialStage('lost')"
                >
                  <span
                    class="absolute top-0.5 w-4 h-4 bg-white rounded-full shadow transition-all"
                    :class="lostStage ? 'left-5' : 'left-0.5'"
                  />
                </button>
              </div>
            </div>
          </div>
        </div>

        <!-- ── TAB: Motivos de Perda ── -->
        <template v-else-if="activeTab === 'loss_reasons'">
          <KanbanLossReasonsTab />
        </template>

        <!-- ── TAB: Automações por estágio ── -->
        <template v-else-if="activeTab === 'automations'">
          <div v-if="!localStages.length" class="flex flex-col items-center justify-center py-16 text-center gap-4">
            <i class="i-lucide-layers text-3xl text-n-slate-9 opacity-40" />
            <p class="text-sm text-n-slate-9">Crie estágios primeiro para configurar automações</p>
          </div>

          <div v-else class="flex flex-col gap-3">
            <p class="text-xs text-n-slate-9 flex items-center gap-1.5">
              <i class="i-lucide-info" />
              As automações executam automaticamente quando um lead entra no estágio
            </p>

            <!-- One accordion per stage -->
            <div
              v-for="stage in localStages"
              :key="stage.id"
              class="rounded-xl border border-n-weak overflow-hidden"
              :class="expandedStageId === stage.id ? 'border-n-brand/40' : ''"
            >
              <!-- Stage accordion header -->
              <button
                class="w-full flex items-center gap-3 px-4 py-3 hover:bg-n-alpha-1 transition-colors text-left"
                :class="expandedStageId === stage.id ? 'bg-n-alpha-1' : 'bg-n-surface-1'"
                @click="expandedStageId = expandedStageId === stage.id ? null : stage.id"
              >
                <div
                  class="w-2.5 h-2.5 rounded-full flex-shrink-0"
                  :style="{ backgroundColor: stage.color?.startsWith('#') ? stage.color : '#64748b' }"
                />
                <span class="flex-1 text-sm font-semibold text-n-slate-12">{{ stage.name }}</span>
                <i
                  class="i-lucide-chevron-right text-n-slate-9 text-sm transition-transform"
                  :class="expandedStageId === stage.id ? 'rotate-90' : ''"
                />
              </button>

              <!-- Panel -->
              <div v-if="expandedStageId === stage.id" class="border-t border-n-weak px-4 py-4 bg-n-surface-2/50">
                <KanbanStageAutomationsPanel
                  :funnel-id="funnelId"
                  :stage="stage"
                />
              </div>
            </div>
          </div>
        </template>

      </div>

    </div>
  </Modal>

  <!-- ─── Edit / Create Stage Modal ───────────────────────────── -->
  <Modal :show="showEditModal" :on-close="() => showEditModal = false" size="medium" :show-close-button="false">
    <div v-if="editingStage" class="flex flex-col">

      <!-- Header -->
      <div class="flex items-center gap-3 px-6 pt-5 pb-4 border-b border-n-weak">
        <!-- Color preview circle -->
        <div
          class="w-10 h-10 rounded-xl flex-shrink-0 shadow-inner ring-1 ring-black/5"
          :style="{ backgroundColor: editingStage.color && editingStage.color.startsWith('#') ? editingStage.color : '#64748b' }"
        />
        <div class="flex-1 min-w-0">
          <h2 class="text-base font-semibold text-n-slate-12">
            {{ editingStage.id ? 'Editar estágio' : 'Novo estágio' }}
          </h2>
          <p class="text-xs text-n-slate-10 mt-0.5">
            {{ editingStage.id ? 'Atualize as configurações do estágio' : 'Configure o novo estágio do funil' }}
          </p>
        </div>
        <button
          class="flex-shrink-0 flex items-center justify-center w-8 h-8 rounded-lg text-n-slate-9 hover:text-n-slate-12 hover:bg-n-alpha-2 transition-colors"
          @click="showEditModal = false"
        >
          <i class="i-lucide-x text-base" />
        </button>
      </div>

      <!-- Form body -->
      <div class="px-6 py-5 space-y-5">

        <!-- Stage name -->
        <div class="space-y-1.5">
          <label class="text-xs font-semibold text-n-slate-11 uppercase tracking-wide">
            Nome do estágio
          </label>
          <Input
            v-model="editingStage.name"
            :placeholder="$t('CONTACTS_KANBAN.SETTINGS.STAGE_NAME_PLACEHOLDER')"
          />
        </div>

        <!-- Hidden color field (kept for reactivity) -->
        <input type="hidden" v-model="editingStage.color" />

        <!-- Linked tag -->
        <div class="space-y-1.5">
          <label class="flex items-center gap-1.5 text-xs font-semibold text-n-slate-11 uppercase tracking-wide">
            Tag vinculada
            <span class="normal-case text-[10px] font-normal text-n-slate-9 bg-n-alpha-2 px-1.5 py-0.5 rounded">opcional</span>
          </label>

          <!-- Custom styled select -->
          <div class="relative">
            <select
              v-model="editingStage.label_id"
              class="w-full appearance-none pl-3 pr-8 py-2.5 text-sm border border-n-weak rounded-lg bg-n-surface-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand/30 focus:border-n-brand transition-all cursor-pointer"
            >
              <option :value="null">— Nenhuma tag —</option>
              <option v-for="label in labels" :key="label.id" :value="label.id">
                {{ label.title }}
              </option>
            </select>
            <i class="i-lucide-chevron-down absolute right-2.5 top-1/2 -translate-y-1/2 text-n-slate-9 text-sm pointer-events-none" />
          </div>

          <p class="text-xs text-n-slate-9 flex items-start gap-1.5">
            <i class="i-lucide-info flex-shrink-0 mt-0.5" />
            <span>{{ $t('CONTACTS_KANBAN.SETTINGS.TAG_DESCRIPTION') }}</span>
          </p>
        </div>

        <!-- Automations section -->
        <div v-if="stageAutomation" class="rounded-xl border border-n-weak overflow-hidden">
          <!-- Section header -->
          <div class="flex items-center justify-between px-4 py-3 bg-n-alpha-1 border-b border-n-weak">
            <div class="flex items-center gap-2">
              <i class="i-lucide-zap text-n-brand text-sm" />
              <span class="text-sm font-semibold text-n-slate-12">Automações</span>
              <span
                v-if="stageAutomation.id"
                class="text-[10px] text-n-slate-9 bg-n-alpha-2 px-1.5 py-0.5 rounded font-medium"
              >
                ID {{ stageAutomation.id }}
              </span>
              <span v-else class="text-[10px] text-n-brand bg-n-brand/10 px-1.5 py-0.5 rounded font-medium">
                Nova
              </span>
            </div>
          </div>

          <!-- Automation body -->
          <div class="p-4">
            <div v-if="editingStage.label_id" class="space-y-3">
              <AutomationActionInput
                v-for="(action, i) in stageAutomation.actions"
                :key="i"
                v-model="stageAutomation.actions[i]"
                :action-types="automationActionTypes"
                :dropdown-values="getActionDropdownValues(stageAutomation.actions[i].action_name)"
                :show-action-input="showActionInput(automationActionTypes, stageAutomation.actions[i].action_name)"
                @reset-action="resetAction(i)"
                @remove-action="removeAction(i)"
              />
              <button
                class="flex items-center gap-1.5 text-xs text-n-brand hover:text-n-brand/80 font-medium mt-1 transition-colors"
                @click="appendNewAction"
              >
                <i class="i-lucide-plus text-sm" />
                Adicionar ação
              </button>
            </div>

            <div v-else class="flex items-start gap-2.5 text-sm text-n-slate-11">
              <i class="i-lucide-info text-n-yellow-10 flex-shrink-0 mt-0.5" />
              <span>Vincule uma tag acima para habilitar automações neste estágio.</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Footer -->
      <div class="flex items-center justify-between px-6 py-4 border-t border-n-weak bg-n-alpha-1">
        <p v-if="editingStage.id" class="text-xs text-n-slate-9 flex items-center gap-1">
          <i class="i-lucide-info" />
          {{ $t('CONTACTS_KANBAN.SETTINGS.EDIT_NOTICE') }}
        </p>
        <div class="flex gap-2 ml-auto">
          <Button variant="secondary" size="sm" @click="showEditModal = false">
            Cancelar
          </Button>
          <Button size="sm" :loading="uiFlags.isCreating || uiFlags.isUpdating" @click="saveStage">
            <i class="i-lucide-check text-sm mr-1" />
            Salvar estágio
          </Button>
        </div>
      </div>
    </div>
  </Modal>
</template>
