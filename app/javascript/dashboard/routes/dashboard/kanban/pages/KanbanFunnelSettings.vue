<script setup>
import { ref, computed, onMounted, watch, nextTick } from 'vue';
import { useStore } from 'vuex';
import { useRouter, useRoute } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import Draggable from 'vuedraggable';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const store = useStore();
const router = useRouter();
const route = useRoute();
const { accountId } = useAccount();

const funnelId = computed(() => Number(route.params.funnelId));
const funnels = computed(() => store.getters['kanbanFunnels/getKanbanFunnels'] || []);
const funnel = computed(() => funnels.value.find(f => f.id === funnelId.value));
const localFunnelName = ref('');
const isSaving = ref(false);

const storeStages = computed(() => store.getters['kanbanStages/getKanbanStages'] || []);
const localStages = ref([]);
const allInboxes = computed(() => store.getters['inboxes/getInboxes'] || []);
const labels = computed(() => store.getters['labels/getLabels'] || []);
const agents = computed(() => store.getters['agents/getAgents'] || []);
const teams = computed(() => store.getters['teams/getTeams'] || []);

watch(storeStages, v => {
  localStages.value = v
    .filter(s => ['regular', 'won', 'lost', null, undefined].includes(s.stage_type))
    .map(s => ({ ...s }));
}, { immediate: true });

const wonStage = computed(() => storeStages.value.find(s => s.stage_type === 'won') || null);
const lostStage = computed(() => storeStages.value.find(s => s.stage_type === 'lost') || null);
const newLeadStage = computed(() => storeStages.value.find(s => s.stage_type === 'new_lead') || null);

const isTogglingSpecial = ref(false);
const toggleSpecialStage = async type => {
  const stageMap = {
    new_lead: { existing: newLeadStage, defaults: { name: 'Leads Novos', color: '#94a3b8', stage_type: 'new_lead' } },
    won:      { existing: wonStage,     defaults: { name: 'Venda Ganha',  color: '#22c55e', stage_type: 'won'      } },
    lost:     { existing: lostStage,    defaults: { name: 'Perdido',      color: '#ef4444', stage_type: 'lost'     } },
  };
  const { existing, defaults } = stageMap[type];
  isTogglingSpecial.value = true;
  try {
    if (existing.value) {
      await store.dispatch('kanbanStages/delete', { funnelId: funnelId.value, id: existing.value.id });
      if (type === 'new_lead') {
        showUnassigned.value = false;
        await store.dispatch('kanbanFunnels/update', { id: funnelId.value, kanban_funnel: { show_unassigned: false } });
      }
    } else {
      await store.dispatch('kanbanStages/create', { funnelId: funnelId.value, ...defaults });
      if (type === 'new_lead') {
        showUnassigned.value = true;
        await store.dispatch('kanbanFunnels/update', { id: funnelId.value, kanban_funnel: { show_unassigned: true } });
      }
    }
    await reloadStages();
  } finally { isTogglingSpecial.value = false; }
};

const STAGE_COLORS = ['#6366f1','#8b5cf6','#ec4899','#ef4444','#f97316','#eab308','#22c55e','#14b8a6','#3b82f6','#64748b'];

const hasGhost = computed(() => localStages.value.some(s => s._ghost));
const realCount = computed(() => localStages.value.filter(s => !s._ghost).length);
const isSpecialStage = s => s.stage_type === 'won' || s.stage_type === 'lost';

// Stage CRUD
const editingStageId = ref(null);
const editForm = ref({ name: '', color: '#64748b', label_id: null });
const isSavingStage = ref(false);

const startEdit = stage => {
  if (stage._ghost) return;
  editingStageId.value = stage.id;
  editForm.value = { name: stage.name, color: stage.color || '#64748b', label_id: stage.label_id ?? null };
  closePicker();
};
const cancelEdit = () => { editingStageId.value = null; };

const saveEdit = async () => {
  if (!editForm.value.name.trim()) return;
  isSavingStage.value = true;
  try {
    await store.dispatch('kanbanStages/update', {
      funnelId: funnelId.value, id: editingStageId.value,
      name: editForm.value.name.trim(), color: editForm.value.color, label_id: editForm.value.label_id,
    });
    useAlert('Etapa salva');
    editingStageId.value = null;
    await reloadStages();
  } finally { isSavingStage.value = false; }
};

const deleteStage = async id => {
  if (!confirm('Excluir esta etapa?')) return;
  await store.dispatch('kanbanStages/delete', { funnelId: funnelId.value, id });
  cancelEdit();
  await reloadStages();
};

// Ghost stage for inline insertion
const newStageName = ref('');
const isSavingNew = ref(false);
const newStageInput = ref(null);

const removeGhost = () => { localStages.value = localStages.value.filter(s => !s._ghost); };
const updateGhostColor = color => {
  const idx = localStages.value.findIndex(s => s._ghost);
  if (idx !== -1) localStages.value[idx] = { ...localStages.value[idx], color };
};

const openInsertAt = async afterRealIdx => {
  removeGhost();
  cancelEdit();
  closePicker();
  newStageName.value = '';
  const color = STAGE_COLORS[realCount.value % STAGE_COLORS.length];
  const ghost = { id: '__ghost__', name: '', color, _ghost: true };
  const insertPos = afterRealIdx === -1 ? 0 : afterRealIdx + 1;
  localStages.value.splice(insertPos, 0, ghost);
  await nextTick();
  if (newStageInput.value) {
    const el = Array.isArray(newStageInput.value) ? newStageInput.value[0] : newStageInput.value;
    el?.focus();
  }
};

const cancelInsert = () => { removeGhost(); newStageName.value = ''; };

const saveNewStage = async () => {
  if (!newStageName.value.trim()) return;
  isSavingNew.value = true;
  const position = localStages.value.findIndex(s => s._ghost);
  try {
    await store.dispatch('kanbanStages/create', {
      funnelId: funnelId.value,
      name: newStageName.value.trim(),
      color: localStages.value[position]?.color || STAGE_COLORS[0],
      position,
    });
    useAlert('Etapa criada');
    cancelInsert();
    await reloadStages();
  } finally { isSavingNew.value = false; }
};

const onDragEnd = async () => {
  try {
    const reordered = localStages.value.filter(s => !s._ghost).map((s, i) => ({ id: s.id, position: i }));
    await store.dispatch('kanbanStages/reorder', { funnelId: funnelId.value, stages: reordered });
    await reloadStages();
  } catch { await reloadStages(); }
};

// Automations
const automationsForStage = id => store.getters['kanbanStageAutomations/getAutomationsForStage'](id) || [];

const ACTION_TYPES = [
  { value: 'send_message',           label: 'Enviar mensagem',      icon: 'i-lucide-message-circle',    color: 'bg-blue-500/15 text-blue-400'    },
  { value: 'send_scheduled_message', label: 'Mensagem agendada',    icon: 'i-lucide-clock-4',            color: 'bg-violet-500/15 text-violet-400'},
  { value: 'move_to_stage',          label: 'Mover para etapa',     icon: 'i-lucide-arrow-right-circle', color: 'bg-teal-500/15 text-teal-400'    },
  { value: 'move_to_funnel',         label: 'Trocar de funil',      icon: 'i-lucide-shuffle',            color: 'bg-purple-500/15 text-purple-400'},
  { value: 'add_label',              label: 'Adicionar etiqueta',   icon: 'i-lucide-tag',                color: 'bg-green-500/15 text-green-400'  },
  { value: 'remove_label',           label: 'Remover etiqueta',     icon: 'i-lucide-circle-slash-2',     color: 'bg-orange-500/15 text-orange-400'},
  { value: 'assign_agent',           label: 'Atribuir agente',      icon: 'i-lucide-user-check',         color: 'bg-pink-500/15 text-pink-400'    },
  { value: 'assign_team',            label: 'Atribuir equipe',      icon: 'i-lucide-users',              color: 'bg-cyan-500/15 text-cyan-400'    },
  { value: 'update_status',          label: 'Alterar status',       icon: 'i-lucide-circle-dot',         color: 'bg-amber-500/15 text-amber-400'  },
  { value: 'update_priority',        label: 'Definir prioridade',   icon: 'i-lucide-flag',               color: 'bg-red-500/15 text-red-400'      },
  { value: 'add_note',               label: 'Adicionar nota',       icon: 'i-lucide-sticky-note',        color: 'bg-yellow-500/15 text-yellow-400'},
];
const actionSearch = ref('');
const filteredActions = computed(() => {
  const q = actionSearch.value.toLowerCase();
  return q ? ACTION_TYPES.filter(a => a.label.toLowerCase().includes(q)) : ACTION_TYPES;
});
const actionMeta = type => ACTION_TYPES.find(a => a.value === type) || { label: type, icon: 'i-lucide-zap', color: 'bg-n-alpha-2 text-n-slate-9' };

// Panel
const panelMode = ref(null);
const pickerStageId = ref(null);
const selectedActionType = ref(null);
const editingAutomationId = ref(null);
const isSavingAction = ref(false);
const panelOpen = computed(() => panelMode.value !== null);
const pickerStageName = computed(() => {
  const all = [...localStages.value, newLeadStage.value].filter(Boolean);
  return all.find(s => s.id === pickerStageId.value)?.name || '';
});

const blankForm = () => ({ action_type: '', delay_minutes: 0, active: true, action_params: {} });
const form = ref(blankForm());
const resetForm = () => { form.value = blankForm(); editingAutomationId.value = null; };

const STATUS_OPTIONS = [
  { value: 'open', label: 'Aberto' }, { value: 'resolved', label: 'Resolvido' },
  { value: 'pending', label: 'Pendente' }, { value: 'snoozed', label: 'Adiado' },
];
const PRIORITY_OPTIONS = [
  { value: 'none', label: 'Sem prioridade' }, { value: 'low', label: 'Baixa' },
  { value: 'medium', label: 'Média' }, { value: 'high', label: 'Alta' }, { value: 'urgent', label: 'Urgente' },
];
const DELAY_PRESETS = [
  { label: 'Imediato', value: 0 }, { label: '15 min', value: 15 }, { label: '30 min', value: 30 },
  { label: '1 hora', value: 60 }, { label: '4 horas', value: 240 }, { label: '1 dia', value: 1440 },
];

const openPicker = stageId => {
  pickerStageId.value = stageId; actionSearch.value = '';
  selectedActionType.value = null; editingAutomationId.value = null;
  resetForm(); panelMode.value = 'automation-pick'; cancelEdit();
};
const selectActionType = type => {
  selectedActionType.value = type; form.value = blankForm(); form.value.action_type = type;
  panelMode.value = 'automation-form';
};
const openEditAction = (stageId, auto) => {
  pickerStageId.value = stageId; editingAutomationId.value = auto.id;
  selectedActionType.value = auto.action_type;
  form.value = { action_type: auto.action_type, delay_minutes: auto.delay_minutes ?? 0, active: auto.active, action_params: { ...auto.action_params } };
  panelMode.value = 'automation-form'; cancelEdit();
};
const closePicker = () => { panelMode.value = null; pickerStageId.value = null; selectedActionType.value = null; resetForm(); };

const saveAction = async () => {
  if (!selectedActionType.value || !pickerStageId.value) return;
  isSavingAction.value = true;
  try {
    const payload = { action_type: form.value.action_type, delay_minutes: Number(form.value.delay_minutes) || 0, active: form.value.active, action_params: form.value.action_params };
    if (editingAutomationId.value) {
      await store.dispatch('kanbanStageAutomations/update', { funnelId: funnelId.value, stageId: pickerStageId.value, id: editingAutomationId.value, automation: payload });
    } else {
      await store.dispatch('kanbanStageAutomations/create', { funnelId: funnelId.value, stageId: pickerStageId.value, automation: payload });
    }
    useAlert('Automação salva'); closePicker();
    await store.dispatch('kanbanStageAutomations/get', { funnelId: funnelId.value, stageId: pickerStageId.value });
  } finally { isSavingAction.value = false; }
};
const deleteAction = async (stageId, id) => {
  if (!confirm('Excluir esta automação?')) return;
  await store.dispatch('kanbanStageAutomations/delete', { funnelId: funnelId.value, stageId, id });
};
const toggleAction = async (stageId, auto) => {
  await store.dispatch('kanbanStageAutomations/update', { funnelId: funnelId.value, stageId, id: auto.id, automation: { active: !auto.active } });
};

// Inboxes
const localInboxIds = ref([]);
const toggleInbox = id => {
  const idx = localInboxIds.value.indexOf(id);
  if (idx === -1) localInboxIds.value.push(id); else localInboxIds.value.splice(idx, 1);
};

const inboxChannelInfo = inbox => {
  const t = inbox.channel_type || '';
  if (t.includes('WebWidget'))  return { icon: 'i-lucide-layout-panel-left', cls: 'bg-indigo-500/15 text-indigo-400', label: 'Web Widget'  };
  if (t.includes('Api'))        return { icon: 'i-lucide-code-2',            cls: 'bg-slate-500/15 text-slate-400',   label: 'API'         };
  if (t.includes('Email'))      return { icon: 'i-lucide-mail',              cls: 'bg-amber-500/15 text-amber-400',   label: 'E-mail'      };
  if (/whatsapp/i.test(t))      return { icon: 'i-lucide-message-circle',    cls: 'bg-green-500/15 text-green-400',   label: 'WhatsApp'    };
  if (t.includes('Facebook'))   return { icon: 'i-lucide-facebook',          cls: 'bg-blue-600/15 text-blue-500',     label: 'Facebook'    };
  if (t.includes('Twitter'))    return { icon: 'i-lucide-twitter',           cls: 'bg-sky-500/15 text-sky-400',       label: 'Twitter'     };
  if (t.includes('Telegram'))   return { icon: 'i-lucide-send',              cls: 'bg-sky-400/15 text-sky-400',       label: 'Telegram'    };
  if (t.includes('Sms'))        return { icon: 'i-lucide-smartphone',        cls: 'bg-purple-500/15 text-purple-400', label: 'SMS'         };
  if (t.includes('Instagram'))  return { icon: 'i-lucide-instagram',         cls: 'bg-pink-500/15 text-pink-400',     label: 'Instagram'   };
  return { icon: 'i-lucide-inbox', cls: 'bg-n-alpha-2 text-n-slate-9', label: t.replace('Channel::', '') || 'Canal' };
};

const showUnassigned = ref(true);

const saveAll = async () => {
  if (!localFunnelName.value.trim()) return;
  isSaving.value = true;
  try {
    await store.dispatch('kanbanFunnels/update', {
      id: funnelId.value,
      kanban_funnel: { name: localFunnelName.value.trim(), inbox_ids: localInboxIds.value, show_unassigned: showUnassigned.value },
    });
    useAlert('Configurações salvas');
  } finally { isSaving.value = false; }
};

const stageColor = s => s.color?.startsWith('#') ? s.color : '#64748b';
const automationSummary = auto => {
  const p = auto.action_params || {};
  switch (auto.action_type) {
    case 'send_message': case 'add_note': case 'send_scheduled_message':
      return p.content ? `"${p.content.slice(0, 45)}${p.content.length > 45 ? '…' : ''}"` : null;
    case 'add_label': case 'remove_label': return p.label || null;
    case 'assign_agent': return agents.value.find(a => String(a.id) === String(p.agent_id))?.name || null;
    case 'assign_team': return teams.value.find(t => String(t.id) === String(p.team_id))?.name || null;
    case 'update_status': return STATUS_OPTIONS.find(s => s.value === p.status)?.label || null;
    case 'update_priority': return PRIORITY_OPTIONS.find(pr => pr.value === p.priority)?.label || null;
    case 'move_to_stage': return storeStages.value.find(s => String(s.id) === String(p.stage_id))?.name || null;
    case 'move_to_funnel': return funnels.value.find(f => String(f.id) === String(p.funnel_id))?.name || null;
    default: return null;
  }
};
const delayLabel = mins => { if (!mins) return null; if (mins < 60) return `+${mins}min`; if (mins < 1440) return `+${mins/60}h`; return `+${Math.floor(mins/1440)}d`; };

const reloadStages = async () => {
  await store.dispatch('kanbanStages/get', funnelId.value);
  await nextTick();
  for (const s of storeStages.value) store.dispatch('kanbanStageAutomations/get', { funnelId: funnelId.value, stageId: s.id });
};
const load = async () => {
  await Promise.all([
    store.dispatch('kanbanFunnels/get'),
    store.dispatch('kanbanStages/get', funnelId.value),
    store.dispatch('inboxes/get'),
    store.dispatch('agents/get'),
    store.dispatch('teams/get'),
    store.dispatch('labels/get'),
  ]);
  for (const s of storeStages.value) store.dispatch('kanbanStageAutomations/get', { funnelId: funnelId.value, stageId: s.id });
  const rec = funnel.value;
  localFunnelName.value = rec?.name ?? '';
  localInboxIds.value = rec?.inbox_ids ? [...rec.inbox_ids] : [];
  showUnassigned.value = rec?.show_unassigned !== false;
};
onMounted(load);
watch(funnelId, load);
</script>

<template>
  <div class="flex flex-col h-full bg-n-surface-2 overflow-hidden select-none kfs-enter">

    <div class="flex items-center justify-between px-5 h-12 border-b border-n-weak bg-n-surface-1 flex-shrink-0 z-10">
      <div class="flex items-center gap-3">
        <button class="flex items-center justify-center w-7 h-7 rounded-lg text-n-slate-9 hover:text-n-slate-12 hover:bg-n-alpha-2 transition-colors" @click="router.back()">
          <i class="i-lucide-arrow-left text-sm" />
        </button>
        <div class="w-px h-4 bg-n-weak" />
        <i class="i-lucide-layout-dashboard text-n-brand text-sm" />
        <span class="text-sm font-bold text-n-slate-12 uppercase tracking-widest">{{ funnel?.name || 'Funil' }}</span>
      </div>
      <div class="flex items-center gap-2">
        <Button variant="ghost" color="slate" size="sm" @click="router.back()">Cancelar</Button>
        <Button size="sm" :loading="isSaving" @click="saveAll">
          <i class="i-lucide-check text-xs mr-1.5" />Salvar
        </Button>
      </div>
    </div>

    <div class="flex flex-1 overflow-hidden">

      <div class="w-64 flex-shrink-0 border-r border-n-weak bg-n-surface-1 overflow-y-auto">
        <div class="p-4 space-y-5">
          <div class="space-y-1.5">
            <label class="text-[11px] font-semibold text-n-slate-9 uppercase tracking-wide">Nome do funil</label>
            <Input v-model="localFunnelName" placeholder="Nome" />
          </div>
          <div class="space-y-2">
            <label class="text-[11px] font-semibold text-n-slate-9 uppercase tracking-wide">Fontes de lead</label>
            <p class="text-[11px] text-n-slate-9 leading-relaxed">Conversas dessas caixas sem etapa entram automaticamente neste funil.</p>
            <div class="flex flex-col gap-0.5 max-h-52 overflow-y-auto">
              <div
                v-for="inbox in allInboxes"
                :key="inbox.id"
                class="flex items-center gap-2.5 px-2 py-1.5 rounded-lg cursor-pointer transition-all"
                :class="localInboxIds.includes(inbox.id) ? 'bg-n-brand/5' : 'hover:bg-n-alpha-1'"
                @click="toggleInbox(inbox.id)"
              >
                <div class="w-7 h-7 rounded-lg flex items-center justify-center flex-shrink-0" :class="inboxChannelInfo(inbox).cls">
                  <i :class="inboxChannelInfo(inbox).icon" class="text-sm" />
                </div>
                <div class="flex-1 min-w-0">
                  <p class="text-xs font-medium text-n-slate-12 truncate">{{ inbox.name }}</p>
                  <p class="text-[10px] text-n-slate-9">{{ inboxChannelInfo(inbox).label }}</p>
                </div>
                <div
                  class="w-4 h-4 rounded-full border flex-shrink-0 flex items-center justify-center transition-all"
                  :class="localInboxIds.includes(inbox.id) ? 'bg-n-brand border-n-brand' : 'border-n-weak'"
                >
                  <i v-if="localInboxIds.includes(inbox.id)" class="i-lucide-check text-white" style="font-size: 9px;" />
                </div>
              </div>
              <p v-if="!allInboxes.length" class="py-3 text-center text-xs text-n-slate-9">Nenhuma caixa</p>
            </div>
          </div>
          <div class="border-t border-n-weak" />
          <div class="space-y-2">
            <label class="text-[11px] font-semibold text-n-slate-9 uppercase tracking-wide">Etapas especiais</label>
            <div class="flex flex-col gap-2">
              <div
                v-for="sp in [
                  { key: 'new_lead', label: 'Leads Novos', desc: 'Leads sem etapa definida',   color: '#94a3b8', icon: 'i-lucide-user-plus', active: !!newLeadStage },
                  { key: 'won',      label: 'Venda Ganha', desc: 'Marca conversa como ganha',  color: '#22c55e', icon: 'i-lucide-trophy',    active: !!wonStage     },
                  { key: 'lost',     label: 'Perdido',      desc: 'Marca conversa como perdida',color: '#ef4444', icon: 'i-lucide-x-circle',  active: !!lostStage    },
                ]"
                :key="sp.key"
                class="flex items-center gap-3 p-3 rounded-xl border cursor-pointer transition-all"
                :class="sp.active ? 'border-n-weak bg-n-surface-2' : 'border-n-weak/40 hover:border-n-weak hover:bg-n-alpha-1'"
                @click="toggleSpecialStage(sp.key)"
              >
                <div class="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0" :style="{ background: sp.color + '20', color: sp.color }">
                  <i :class="sp.icon" class="text-sm" />
                </div>
                <div class="flex-1 min-w-0">
                  <p class="text-xs font-semibold text-n-slate-12 leading-snug">{{ sp.label }}</p>
                  <p class="text-[10px] text-n-slate-9 leading-snug mt-0.5">{{ sp.desc }}</p>
                </div>
                <div class="w-8 h-4 rounded-full transition-colors flex-shrink-0 relative" :class="sp.active ? 'bg-n-brand' : 'bg-n-alpha-2'">
                  <div class="absolute top-0.5 w-3 h-3 rounded-full bg-white shadow-sm transition-all" :style="{ left: sp.active ? '18px' : '2px' }" />
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div class="flex-1 overflow-hidden">
        <div class="h-full overflow-x-auto overflow-y-hidden">
          <div class="flex h-full min-w-max">

            <div v-if="newLeadStage" class="flex flex-col w-[260px] flex-shrink-0 border-r h-full border-n-weak bg-n-surface-1">
              <div class="group flex items-center gap-1.5 px-3 py-2.5 border-b-2 flex-shrink-0" :style="{ minHeight: '3.125rem', borderColor: stageColor(newLeadStage) }">
                <div class="w-2.5 h-2.5 rounded-full flex-shrink-0" :style="{ background: stageColor(newLeadStage) }" />
                <span class="flex-1 text-[11px] font-bold uppercase tracking-wider text-n-slate-12 truncate">{{ newLeadStage.name }}</span>
                <span class="text-[9px] px-1.5 py-0.5 rounded font-medium flex-shrink-0" :style="{ background: stageColor(newLeadStage) + '22', color: stageColor(newLeadStage) }">ENTRADA</span>
                <span class="text-[10px] text-n-slate-8 bg-n-alpha-2 px-1.5 py-0.5 rounded font-mono flex-shrink-0">{{ automationsForStage(newLeadStage.id).length }}</span>
              </div>
              <div class="flex-1 overflow-y-auto p-2 space-y-1.5">
                <div class="flex items-center gap-2 px-2.5 py-2 rounded-lg bg-n-alpha-1 border border-n-weak/50">
                  <i class="i-lucide-play-circle text-n-brand text-xs flex-shrink-0" />
                  <span class="text-[11px] text-n-slate-10">Quando entrar no funil sem etapa</span>
                </div>
                <div v-for="auto in automationsForStage(newLeadStage.id)" :key="auto.id" class="group relative rounded-lg border transition-all" :class="[auto.active ? 'bg-n-surface-1 border-n-weak hover:border-n-brand/30' : 'bg-n-alpha-1 border-n-weak/50 opacity-50', pickerStageId === newLeadStage.id && editingAutomationId === auto.id ? 'ring-1 ring-n-brand border-n-brand' : '']">
                  <div class="absolute -top-1.5 left-4 w-px h-1.5 bg-n-weak" />
                  <div class="flex items-center gap-2 px-2.5 py-2.5">
                    <div class="w-7 h-7 rounded-lg flex items-center justify-center flex-shrink-0 text-sm" :class="actionMeta(auto.action_type).color"><i :class="actionMeta(auto.action_type).icon" /></div>
                    <div class="flex-1 min-w-0">
                      <div class="flex items-center gap-1.5">
                        <span class="text-[11px] font-semibold text-n-slate-12 truncate">{{ actionMeta(auto.action_type).label }}</span>
                        <span v-if="delayLabel(auto.delay_minutes)" class="text-[9px] bg-n-alpha-2 text-n-slate-9 px-1 py-0.5 rounded font-mono flex-shrink-0">{{ delayLabel(auto.delay_minutes) }}</span>
                      </div>
                      <p v-if="automationSummary(auto)" class="text-[10px] text-n-slate-9 truncate">{{ automationSummary(auto) }}</p>
                    </div>
                  </div>
                  <div class="absolute top-1 right-1 flex items-center gap-0.5 opacity-0 group-hover:opacity-100 transition-opacity bg-n-surface-1 border border-n-weak/50 rounded-md shadow-sm px-0.5">
                    <button class="p-1 rounded text-n-slate-8 hover:text-n-brand" @click="openEditAction(newLeadStage.id, auto)"><i class="i-lucide-pencil text-[10px]" /></button>
                    <button class="p-1 rounded text-n-slate-8 hover:text-n-slate-12" @click="toggleAction(newLeadStage.id, auto)"><i :class="auto.active ? 'i-lucide-pause' : 'i-lucide-play'" class="text-[10px]" /></button>
                    <button class="p-1 rounded text-n-slate-8 hover:text-n-ruby-9" @click="deleteAction(newLeadStage.id, auto.id)"><i class="i-lucide-trash-2 text-[10px]" /></button>
                  </div>
                </div>
                <button class="flex items-center gap-1.5 w-full px-2.5 py-2 rounded-lg border border-dashed text-[11px] font-medium transition-all mt-1" :class="pickerStageId === newLeadStage.id && panelMode === 'automation-pick' ? 'border-n-brand bg-n-brand/5 text-n-brand' : 'border-n-brand/30 text-n-brand hover:bg-n-brand/5 hover:border-n-brand/50'" @click="openPicker(newLeadStage.id)">
                  <i class="i-lucide-plus text-xs flex-shrink-0" />Adicionar gatilho
                </button>
              </div>
            </div>

            <Draggable
              v-model="localStages"
              item-key="id"
              class="flex h-full"
              handle=".stage-drag-handle"
              :disabled="hasGhost"
              @end="onDragEnd"
            >
              <template #item="{ element: stage, index }"><div class="flex h-full flex-shrink-0"><div
                class="relative flex flex-col flex-shrink-0 border-r h-full"
                :class="stage._ghost
                  ? 'w-[260px] border-n-brand/30 bg-n-brand/[0.015]'
                  : ['w-[260px] border-n-weak', editingStageId === stage.id ? 'bg-n-surface-2' : 'bg-n-surface-1']"
              >
                <div v-if="stage._ghost" class="flex items-center gap-1.5 px-3 py-[11px] border-b-2 flex-shrink-0" :style="{ borderColor: stage.color }">
                  <div class="w-2.5 h-2.5 rounded-full flex-shrink-0 ring-2 ring-offset-1 ring-n-brand/30 transition-colors" :style="{ background: stage.color }" />
                  <input
                    ref="newStageInput"
                    v-model="newStageName"
                    class="flex-1 text-[11px] font-bold uppercase tracking-wider bg-transparent border-0 border-b border-n-brand/40 text-n-slate-12 outline-none pb-px focus:border-n-brand placeholder-n-slate-7"
                    placeholder="Nome da etapa…"
                    @keydown.enter="saveNewStage"
                    @keydown.escape="cancelInsert"
                  />
                </div>
                <div v-if="stage._ghost" class="px-3 pt-2.5 pb-2 border-b border-n-weak/40 flex-shrink-0 space-y-2">
                  <div class="flex items-center gap-1 flex-wrap">
                    <button v-for="c in STAGE_COLORS" :key="c" class="w-4 h-4 rounded-full transition-transform hover:scale-110 flex-shrink-0" :class="stage.color === c ? 'ring-2 ring-offset-1 ring-n-brand scale-110' : ''" :style="{ background: c }" @click="updateGhostColor(c)" />
                  </div>
                  <div class="flex gap-1.5">
                    <button class="flex-1 text-[11px] py-1 rounded-md bg-n-brand text-white font-semibold hover:bg-n-brand/90 transition-colors disabled:opacity-50" :disabled="isSavingNew" @click="saveNewStage">{{ isSavingNew ? '…' : 'Criar etapa' }}</button>
                    <button class="w-8 text-[11px] py-1 rounded-md border border-n-weak text-n-slate-9 hover:bg-n-alpha-2 transition-colors flex items-center justify-center" @click="cancelInsert"><i class="i-lucide-x text-[10px]" /></button>
                  </div>
                </div>
                <div v-if="stage._ghost" class="flex-1 flex flex-col items-center justify-center gap-2 opacity-25">
                  <i class="i-lucide-layers-2 text-2xl text-n-slate-8" />
                  <p class="text-[10px] text-n-slate-8 text-center px-6 leading-relaxed">Automações serão adicionadas após criar a etapa</p>
                </div>

                <div v-if="!stage._ghost && editingStageId !== stage.id" class="group flex items-center gap-1.5 px-3 py-2.5 border-b-2 flex-shrink-0" :style="{ minHeight: '3.125rem', borderColor: stageColor(stage) }">
                  <div class="stage-drag-handle cursor-grab active:cursor-grabbing text-n-slate-7 hover:text-n-slate-10 flex-shrink-0 transition-colors">
                    <i class="i-lucide-grip-vertical text-sm" />
                  </div>
                  <div class="w-2.5 h-2.5 rounded-full flex-shrink-0" :style="{ background: stageColor(stage) }" />
                  <span class="flex-1 text-[11px] font-bold uppercase tracking-wider text-n-slate-12 truncate">{{ stage.name }}</span>
                  <span v-if="isSpecialStage(stage)" class="text-[9px] px-1.5 py-0.5 rounded font-medium flex-shrink-0" :style="{ background: stageColor(stage) + '22', color: stageColor(stage) }">{{ stage.stage_type === 'won' ? 'GANHO' : 'PERDIDO' }}</span>
                  <div v-else class="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity flex-shrink-0">
                    <button class="w-7 h-7 flex items-center justify-center rounded-lg text-n-slate-9 hover:text-n-slate-12 hover:bg-n-alpha-2 transition-colors" @click.stop="startEdit(stage)">
                      <i class="i-lucide-pencil text-sm" />
                    </button>
                    <button class="w-7 h-7 flex items-center justify-center rounded-lg text-n-slate-9 hover:text-n-ruby-9 hover:bg-n-ruby-9/10 transition-colors" @click.stop="deleteStage(stage.id)">
                      <i class="i-lucide-trash-2 text-sm" />
                    </button>
                  </div>
                  <span class="text-[10px] text-n-slate-8 bg-n-alpha-2 px-1.5 py-0.5 rounded font-mono flex-shrink-0">{{ automationsForStage(stage.id).length }}</span>
                </div>

                <div v-if="!stage._ghost && editingStageId === stage.id" class="px-3 py-2.5 border-b-2 flex-shrink-0 space-y-2 bg-n-surface-2" :style="{ borderColor: editForm.color }">
                  <input v-model="editForm.name" class="w-full text-[11px] font-bold uppercase tracking-wider bg-transparent border-0 border-b border-n-brand/50 text-n-slate-12 outline-none pb-0.5 focus:border-n-brand" placeholder="Nome da etapa" @keydown.enter="saveEdit" @keydown.escape="cancelEdit" />
                  <div class="flex items-center gap-1 flex-wrap">
                    <button v-for="c in STAGE_COLORS" :key="c" class="w-5 h-5 rounded-full transition-transform hover:scale-110" :class="editForm.color === c ? 'ring-2 ring-n-brand scale-110' : ''" :style="{ background: c }" @click="editForm.color = c" />
                  </div>
                  <select v-model="editForm.label_id" class="w-full text-[11px] border border-n-weak rounded-md px-2 py-1 bg-n-surface-1 text-n-slate-11 focus:outline-none focus:ring-1 focus:ring-n-brand/40">
                    <option :value="null">— Sem etiqueta —</option>
                    <option v-for="lbl in labels" :key="lbl.id" :value="lbl.id">{{ lbl.title }}</option>
                  </select>
                  <div class="flex gap-1.5">
                    <button class="flex-1 text-[11px] py-1 rounded-md bg-n-brand text-white font-semibold hover:bg-n-brand/90" :disabled="isSavingStage" @click="saveEdit">{{ isSavingStage ? '…' : 'Salvar' }}</button>
                    <button class="flex-1 text-[11px] py-1 rounded-md border border-n-weak text-n-slate-10 hover:bg-n-alpha-2" @click="cancelEdit">Cancelar</button>
                  </div>
                </div>

                <div v-if="!stage._ghost" class="flex-1 overflow-y-auto p-2 space-y-1.5">
                  <div class="flex items-center gap-2 px-2.5 py-2 rounded-lg bg-n-alpha-1 border border-n-weak/50">
                    <i class="i-lucide-play-circle text-n-brand text-xs flex-shrink-0" />
                    <span class="text-[11px] text-n-slate-10">{{ isSpecialStage(stage) ? `Quando marcado como ${stage.stage_type === 'won' ? 'ganho' : 'perdido'}` : 'Quando entrar nesta etapa' }}</span>
                  </div>
                  <div v-for="auto in automationsForStage(stage.id)" :key="auto.id" class="group relative rounded-lg border transition-all" :class="[auto.active ? 'bg-n-surface-1 border-n-weak hover:border-n-brand/30' : 'bg-n-alpha-1 border-n-weak/50 opacity-50', pickerStageId === stage.id && editingAutomationId === auto.id ? 'ring-1 ring-n-brand border-n-brand' : '']">
                    <div class="absolute -top-1.5 left-4 w-px h-1.5 bg-n-weak" />
                    <div class="flex items-center gap-2 px-2.5 py-2.5">
                      <div class="w-7 h-7 rounded-lg flex items-center justify-center flex-shrink-0 text-sm" :class="actionMeta(auto.action_type).color"><i :class="actionMeta(auto.action_type).icon" /></div>
                      <div class="flex-1 min-w-0">
                        <div class="flex items-center gap-1.5">
                          <span class="text-[11px] font-semibold text-n-slate-12 truncate">{{ actionMeta(auto.action_type).label }}</span>
                          <span v-if="delayLabel(auto.delay_minutes)" class="text-[9px] bg-n-alpha-2 text-n-slate-9 px-1 py-0.5 rounded font-mono flex-shrink-0">{{ delayLabel(auto.delay_minutes) }}</span>
                        </div>
                        <p v-if="automationSummary(auto)" class="text-[10px] text-n-slate-9 truncate">{{ automationSummary(auto) }}</p>
                      </div>
                    </div>
                    <div class="absolute top-1 right-1 flex items-center gap-0.5 opacity-0 group-hover:opacity-100 transition-opacity bg-n-surface-1 border border-n-weak/50 rounded-md shadow-sm px-0.5">
                      <button class="p-1 rounded text-n-slate-8 hover:text-n-brand" @click="openEditAction(stage.id, auto)"><i class="i-lucide-pencil text-[10px]" /></button>
                      <button class="p-1 rounded text-n-slate-8 hover:text-n-slate-12" @click="toggleAction(stage.id, auto)"><i :class="auto.active ? 'i-lucide-pause' : 'i-lucide-play'" class="text-[10px]" /></button>
                      <button class="p-1 rounded text-n-slate-8 hover:text-n-ruby-9" @click="deleteAction(stage.id, auto.id)"><i class="i-lucide-trash-2 text-[10px]" /></button>
                    </div>
                  </div>
                  <button class="flex items-center gap-1.5 w-full px-2.5 py-2 rounded-lg border border-dashed text-[11px] font-medium transition-all mt-1" :class="pickerStageId === stage.id && panelMode === 'automation-pick' ? 'border-n-brand bg-n-brand/5 text-n-brand' : 'border-n-brand/30 text-n-brand hover:bg-n-brand/5 hover:border-n-brand/50'" @click="openPicker(stage.id)">
                    <i class="i-lucide-plus text-xs flex-shrink-0" />Adicionar gatilho
                  </button>
                </div>

              </div><div
                v-if="!stage._ghost && !hasGhost"
                class="relative w-0 h-full flex-shrink-0 flex items-center"
                style="z-index: 50;"
              >
                <button
                  class="absolute left-0 top-1/2 -translate-x-1/2 -translate-y-1/2 w-7 h-7 rounded-full bg-n-surface-1 border-2 border-current text-n-slate-11 flex items-center justify-center transition-all hover:scale-110 hover:text-n-slate-12 hover:shadow-md"
                  @click="openInsertAt(index)"
                >
                  <i class="i-lucide-plus text-xs" />
                </button>
              </div></div></template>
            </Draggable>

            <div v-if="!hasGhost && realCount === 0" class="flex flex-col items-center justify-center w-64 gap-4 px-8 text-center">
              <p class="text-sm text-n-slate-9">Nenhuma etapa. Use o "+" para adicionar.</p>
            </div>


          </div>
        </div>
      </div>

      <transition name="slide-right">
        <div v-if="panelOpen" class="w-[360px] flex-shrink-0 border-l border-n-weak bg-n-solid-1 flex flex-col overflow-hidden">

          <!-- Panel header -->
          <div class="flex items-center justify-between px-5 py-4 border-b border-n-weak flex-shrink-0">
            <div class="flex items-center gap-2.5 min-w-0">
              <div
                v-if="panelMode === 'automation-pick'"
                class="w-8 h-8 rounded-lg bg-n-brand/10 flex items-center justify-center flex-shrink-0"
              >
                <i class="i-lucide-zap text-n-brand text-base" />
              </div>
              <div
                v-else
                class="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0 text-base"
                :class="actionMeta(selectedActionType).color"
              >
                <i :class="actionMeta(selectedActionType).icon" />
              </div>
              <div class="min-w-0">
                <p class="text-sm font-semibold text-n-slate-12 leading-snug">
                  {{ panelMode === 'automation-pick' ? 'Adicionar gatilho' : (editingAutomationId ? 'Editar gatilho' : actionMeta(selectedActionType).label) }}
                </p>
                <p class="text-xs text-n-slate-8 truncate mt-px">{{ pickerStageName }}</p>
              </div>
            </div>
            <button
              class="w-8 h-8 flex items-center justify-center rounded-lg text-n-slate-9 hover:bg-n-alpha-2 transition-colors flex-shrink-0"
              @click="closePicker"
            >
              <i class="i-lucide-x text-base" />
            </button>
          </div>

          <!-- ── PICKER ── -->
          <template v-if="panelMode === 'automation-pick'">
            <div class="px-5 pt-4 pb-3 flex-shrink-0 flex flex-col gap-2">
              <!-- Search -->
              <div class="flex h-9 items-center gap-2 px-3 rounded-lg border border-n-weak bg-n-solid-2">
                <i class="i-lucide-search text-n-slate-7 text-sm flex-shrink-0" />
                <input
                  v-model="actionSearch"
                  type="text"
                  placeholder="Buscar ação…"
                  class="flex-1 bg-transparent text-sm text-n-slate-12 placeholder:text-n-slate-8 outline-none focus:outline-none focus-visible:outline-none border-0"
                />
              </div>
              <p class="text-xs text-n-slate-8 leading-relaxed">
                Executa quando um lead entra em
                <span class="font-semibold text-n-slate-11">{{ pickerStageName }}</span>
              </p>
            </div>

            <div class="flex-1 overflow-y-auto px-5 pb-5">
              <div class="grid grid-cols-2 gap-2">
                <button
                  v-for="action in filteredActions"
                  :key="action.value"
                  class="group flex flex-col items-center gap-2.5 p-4 rounded-xl border border-n-weak bg-n-solid-2 hover:border-n-brand/40 hover:bg-n-brand/[0.03] transition-all text-center"
                  @click="selectActionType(action.value)"
                >
                  <div
                    class="w-10 h-10 rounded-xl flex items-center justify-center text-xl transition-transform group-hover:scale-105"
                    :class="action.color"
                  >
                    <i :class="action.icon" />
                  </div>
                  <span class="text-xs font-semibold text-n-slate-11 group-hover:text-n-slate-12 leading-tight">{{ action.label }}</span>
                </button>
              </div>
            </div>
          </template>

          <!-- ── FORM ── -->
          <template v-else-if="panelMode === 'automation-form'">
            <div class="flex-1 overflow-y-auto px-5 py-4 flex flex-col gap-4">

              <!-- Back link -->
              <button
                v-if="!editingAutomationId"
                class="flex items-center gap-1.5 text-xs text-n-slate-8 hover:text-n-brand transition-colors w-fit"
                @click="panelMode = 'automation-pick'; selectedActionType = null"
              >
                <i class="i-lucide-arrow-left text-xs" />
                Escolher outra ação
              </button>

              <!-- send_message / add_note -->
              <div v-if="['send_message','add_note'].includes(form.action_type)" class="flex flex-col gap-1.5">
                <label class="text-xs font-semibold text-n-slate-10">
                  {{ form.action_type === 'add_note' ? 'Conteúdo da nota' : 'Mensagem' }}
                </label>
                <textarea
                  v-model="form.action_params.content"
                  rows="5"
                  class="px-3 py-2 rounded-lg border border-n-weak bg-n-solid-2 text-sm text-n-slate-12 placeholder:text-n-slate-8 focus:outline-none focus:ring-2 focus:ring-n-brand/30 resize-none"
                  :placeholder="form.action_type === 'add_note' ? 'Nota interna…' : 'Escreva a mensagem…'"
                />
                <label v-if="form.action_type === 'send_message'" class="flex items-center gap-2 cursor-pointer">
                  <input v-model="form.action_params.is_private" type="checkbox" class="accent-n-brand rounded" />
                  <span class="text-xs text-n-slate-11">Enviar como nota privada</span>
                </label>
              </div>

              <!-- send_scheduled_message -->
              <template v-else-if="form.action_type === 'send_scheduled_message'">
                <div class="flex flex-col gap-1.5">
                  <label class="text-xs font-semibold text-n-slate-10">Mensagem</label>
                  <textarea
                    v-model="form.action_params.content"
                    rows="4"
                    class="px-3 py-2 rounded-lg border border-n-weak bg-n-solid-2 text-sm text-n-slate-12 placeholder:text-n-slate-8 focus:outline-none focus:ring-2 focus:ring-n-brand/30 resize-none"
                    placeholder="Mensagem agendada…"
                  />
                </div>
                <div class="flex flex-col gap-1.5">
                  <label class="text-xs font-semibold text-n-slate-10">Enviar após</label>
                  <div class="flex flex-wrap gap-1.5">
                    <button
                      v-for="p in DELAY_PRESETS.slice(1)"
                      :key="p.value"
                      class="h-8 px-3 rounded-lg text-xs font-medium border transition-all"
                      :class="form.action_params.delay_minutes === p.value
                        ? 'bg-n-brand text-white border-n-brand'
                        : 'border-n-weak bg-n-solid-2 text-n-slate-11 hover:border-n-brand/40'"
                      @click="form.action_params.delay_minutes = p.value"
                    >{{ p.label }}</button>
                  </div>
                </div>
              </template>

              <!-- add_label / remove_label -->
              <div v-else-if="['add_label','remove_label'].includes(form.action_type)" class="flex flex-col gap-1.5">
                <label class="text-xs font-semibold text-n-slate-10">Etiqueta</label>
                <div class="flex flex-col gap-1 max-h-52 overflow-y-auto rounded-lg border border-n-weak bg-n-solid-2 p-1">
                  <button
                    v-for="lbl in labels"
                    :key="lbl.id"
                    class="flex items-center gap-2.5 px-2.5 py-2 rounded-lg border text-left transition-all"
                    :class="form.action_params.label === lbl.title
                      ? 'bg-n-brand/10 border-n-brand'
                      : 'border-transparent hover:bg-n-alpha-1'"
                    @click="form.action_params.label = lbl.title"
                  >
                    <span class="w-3 h-3 rounded-full flex-shrink-0" :style="{ background: lbl.color || '#64748b' }" />
                    <span class="text-xs text-n-slate-12 flex-1">{{ lbl.title }}</span>
                    <i v-if="form.action_params.label === lbl.title" class="i-lucide-check text-n-brand text-xs" />
                  </button>
                  <p v-if="!labels.length" class="text-center text-xs text-n-slate-9 py-3">Nenhuma etiqueta</p>
                </div>
              </div>

              <!-- assign_agent -->
              <div v-else-if="form.action_type === 'assign_agent'" class="flex flex-col gap-1.5">
                <label class="text-xs font-semibold text-n-slate-10">Agente</label>
                <div class="flex flex-col gap-1 max-h-52 overflow-y-auto rounded-lg border border-n-weak bg-n-solid-2 p-1">
                  <button
                    v-for="agent in agents"
                    :key="agent.id"
                    class="flex items-center gap-2.5 px-2.5 py-2 rounded-lg border transition-all"
                    :class="String(form.action_params.agent_id) === String(agent.id)
                      ? 'bg-n-brand/10 border-n-brand'
                      : 'border-transparent hover:bg-n-alpha-1'"
                    @click="form.action_params.agent_id = agent.id"
                  >
                    <Avatar :src="agent.thumbnail" :username="agent.name" :size="26" />
                    <div class="min-w-0 flex-1">
                      <p class="text-xs font-medium text-n-slate-12 truncate">{{ agent.name }}</p>
                      <p class="text-[10px] text-n-slate-9 truncate">{{ agent.email }}</p>
                    </div>
                    <i v-if="String(form.action_params.agent_id) === String(agent.id)" class="i-lucide-check text-n-brand text-xs" />
                  </button>
                </div>
              </div>

              <!-- assign_team -->
              <div v-else-if="form.action_type === 'assign_team'" class="flex flex-col gap-1.5">
                <label class="text-xs font-semibold text-n-slate-10">Equipe</label>
                <div class="flex flex-col gap-1 rounded-lg border border-n-weak bg-n-solid-2 p-1">
                  <button
                    v-for="team in teams"
                    :key="team.id"
                    class="flex items-center gap-2.5 px-2.5 py-2 rounded-lg border transition-all"
                    :class="String(form.action_params.team_id) === String(team.id)
                      ? 'bg-n-brand/10 border-n-brand'
                      : 'border-transparent hover:bg-n-alpha-1'"
                    @click="form.action_params.team_id = team.id"
                  >
                    <div class="w-7 h-7 rounded-full bg-n-brand/10 flex items-center justify-center flex-shrink-0">
                      <i class="i-lucide-users text-n-brand text-xs" />
                    </div>
                    <span class="text-xs text-n-slate-12 flex-1 truncate">{{ team.name }}</span>
                    <i v-if="String(form.action_params.team_id) === String(team.id)" class="i-lucide-check text-n-brand text-xs" />
                  </button>
                  <p v-if="!teams.length" class="text-center text-xs text-n-slate-9 py-3">Nenhuma equipe</p>
                </div>
              </div>

              <!-- update_status -->
              <div v-else-if="form.action_type === 'update_status'" class="flex flex-col gap-1.5">
                <label class="text-xs font-semibold text-n-slate-10">Novo status</label>
                <div class="grid grid-cols-2 gap-1.5">
                  <button
                    v-for="opt in STATUS_OPTIONS"
                    :key="opt.value"
                    class="h-10 rounded-lg text-xs font-semibold border transition-all"
                    :class="form.action_params.status === opt.value
                      ? 'bg-n-brand text-white border-n-brand'
                      : 'border-n-weak bg-n-solid-2 text-n-slate-11 hover:border-n-brand/40 hover:bg-n-brand/5'"
                    @click="form.action_params.status = opt.value"
                  >{{ opt.label }}</button>
                </div>
              </div>

              <!-- update_priority -->
              <div v-else-if="form.action_type === 'update_priority'" class="flex flex-col gap-1.5">
                <label class="text-xs font-semibold text-n-slate-10">Prioridade</label>
                <div class="flex flex-col gap-1.5">
                  <button
                    v-for="opt in PRIORITY_OPTIONS"
                    :key="opt.value"
                    class="flex items-center gap-2.5 h-10 px-3 rounded-lg border text-sm font-medium transition-all"
                    :class="form.action_params.priority === opt.value
                      ? 'bg-n-brand/10 border-n-brand text-n-brand'
                      : 'border-n-weak bg-n-solid-2 text-n-slate-11 hover:border-n-brand/40'"
                    @click="form.action_params.priority = opt.value"
                  >
                    <i class="i-lucide-flag text-xs" />
                    {{ opt.label }}
                    <i v-if="form.action_params.priority === opt.value" class="i-lucide-check text-n-brand text-xs ml-auto" />
                  </button>
                </div>
              </div>

              <!-- move_to_stage -->
              <div v-else-if="form.action_type === 'move_to_stage'" class="flex flex-col gap-1.5">
                <label class="text-xs font-semibold text-n-slate-10">Mover para a etapa</label>
                <div class="flex flex-col gap-1 max-h-52 overflow-y-auto rounded-lg border border-n-weak bg-n-solid-2 p-1">
                  <button
                    v-for="s in storeStages.filter(s => s.id !== pickerStageId && (s.stage_type === 'regular' || !s.stage_type || s.stage_type === 'won' || s.stage_type === 'lost'))"
                    :key="s.id"
                    class="flex items-center gap-2.5 px-2.5 py-2 rounded-lg border transition-all"
                    :class="String(form.action_params.stage_id) === String(s.id) ? 'bg-n-brand/10 border-n-brand' : 'border-transparent hover:bg-n-alpha-1'"
                    @click="form.action_params.stage_id = s.id"
                  >
                    <div class="w-2.5 h-2.5 rounded-full flex-shrink-0" :style="{ background: stageColor(s) }" />
                    <span class="text-xs text-n-slate-12 flex-1 truncate">{{ s.name }}</span>
                    <span v-if="s.stage_type === 'won'" class="text-[9px] px-1 py-0.5 rounded" style="background:#22c55e22;color:#22c55e">GANHO</span>
                    <span v-else-if="s.stage_type === 'lost'" class="text-[9px] px-1 py-0.5 rounded" style="background:#ef444422;color:#ef4444">PERDIDO</span>
                    <i v-if="String(form.action_params.stage_id) === String(s.id)" class="i-lucide-check text-n-brand text-xs" />
                  </button>
                  <p v-if="!storeStages.filter(s => s.id !== pickerStageId).length" class="text-center text-xs text-n-slate-9 py-3">Nenhuma etapa disponível</p>
                </div>
              </div>

              <!-- move_to_funnel -->
              <div v-else-if="form.action_type === 'move_to_funnel'" class="flex flex-col gap-1.5">
                <label class="text-xs font-semibold text-n-slate-10">Mover para o funil</label>
                <div class="flex flex-col gap-1 max-h-52 overflow-y-auto rounded-lg border border-n-weak bg-n-solid-2 p-1">
                  <button
                    v-for="f in funnels.filter(f => f.id !== funnelId)"
                    :key="f.id"
                    class="flex items-center gap-2.5 px-2.5 py-2 rounded-lg border transition-all"
                    :class="String(form.action_params.funnel_id) === String(f.id) ? 'bg-n-brand/10 border-n-brand' : 'border-transparent hover:bg-n-alpha-1'"
                    @click="form.action_params.funnel_id = f.id"
                  >
                    <i class="i-lucide-layout-dashboard text-n-brand text-xs flex-shrink-0" />
                    <span class="text-xs text-n-slate-12 flex-1 truncate">{{ f.name }}</span>
                    <i v-if="String(form.action_params.funnel_id) === String(f.id)" class="i-lucide-check text-n-brand text-xs" />
                  </button>
                  <p v-if="!funnels.filter(f => f.id !== funnelId).length" class="text-center text-xs text-n-slate-9 py-3">Nenhum outro funil</p>
                </div>
              </div>

              <!-- Delay presets (shared, except send_scheduled_message) -->
              <div v-if="form.action_type && form.action_type !== 'send_scheduled_message'" class="flex flex-col gap-1.5 pt-2 border-t border-n-weak">
                <label class="text-xs font-semibold text-n-slate-10">Executar após entrar na etapa</label>
                <div class="flex flex-wrap gap-1.5">
                  <button
                    v-for="p in DELAY_PRESETS"
                    :key="p.value"
                    class="h-8 px-3 rounded-lg text-xs font-medium border transition-all"
                    :class="form.delay_minutes === p.value
                      ? 'bg-n-brand text-white border-n-brand'
                      : 'border-n-weak bg-n-solid-2 text-n-slate-11 hover:border-n-brand/40'"
                    @click="form.delay_minutes = p.value"
                  >{{ p.label }}</button>
                </div>
              </div>
            </div>

            <!-- Footer -->
            <div class="flex items-center gap-3 px-5 py-4 border-t border-n-weak flex-shrink-0">
              <button
                class="flex-1 h-9 rounded-lg border border-n-weak text-sm font-semibold text-n-slate-11 hover:bg-n-alpha-2 transition-colors"
                @click="closePicker"
              >
                Cancelar
              </button>
              <button
                class="flex-1 h-9 rounded-lg bg-n-brand text-white text-sm font-semibold hover:brightness-110 transition-all disabled:opacity-50 flex items-center justify-center gap-1.5"
                :disabled="isSavingAction"
                @click="saveAction"
              >
                <i v-if="isSavingAction" class="i-lucide-loader-2 animate-spin text-sm" />
                <i v-else class="i-lucide-check text-sm" />
                {{ editingAutomationId ? 'Atualizar' : 'Adicionar gatilho' }}
              </button>
            </div>
          </template>
        </div>
      </transition>

    </div>
  </div>
</template>

<style scoped>
.slide-right-enter-active, .slide-right-leave-active { transition: transform 0.22s cubic-bezier(0.4,0,0.2,1), opacity 0.22s ease; }
.slide-right-enter-from, .slide-right-leave-to { transform: translateX(20px); opacity: 0; }

.kfs-enter { animation: kfsFadeIn 0.25s ease both; }
@keyframes kfsFadeIn { from { opacity: 0; transform: translateY(6px); } to { opacity: 1; transform: translateY(0); } }

</style>
