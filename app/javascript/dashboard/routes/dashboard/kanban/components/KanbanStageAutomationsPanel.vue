<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useStore } from 'vuex';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  funnelId: { type: Number, required: true },
  stage: { type: Object, required: true },
});

const store = useStore();

const automations = computed(
  () => store.getters['kanbanStageAutomations/getAutomationsForStage'](props.stage.id)
);

const agents = computed(() => store.getters['agents/getAgents'] || []);
const teams = computed(() => store.getters['teams/getTeams'] || []);
const labels = computed(() => store.getters['labels/getLabels'] || []);

// ─── Form state ────────────────────────────────────────────────

const showForm = ref(false);
const isSaving = ref(false);
const editingId = ref(null);

const blankForm = () => ({
  action_type: 'send_message',
  delay_minutes: 0,
  active: true,
  action_params: {},
});

const form = ref(blankForm());

const ACTION_TYPES = [
  { value: 'send_message',           label: 'Enviar mensagem',          icon: 'i-lucide-message-circle' },
  { value: 'send_scheduled_message', label: 'Agendar mensagem (delay)', icon: 'i-lucide-clock' },
  { value: 'add_label',              label: 'Adicionar etiqueta',       icon: 'i-lucide-tag' },
  { value: 'remove_label',           label: 'Remover etiqueta',         icon: 'i-lucide-tag-off' },
  { value: 'assign_agent',           label: 'Atribuir agente',          icon: 'i-lucide-user-check' },
  { value: 'assign_team',            label: 'Atribuir equipe',          icon: 'i-lucide-users' },
  { value: 'update_status',          label: 'Alterar status',           icon: 'i-lucide-circle-dot' },
  { value: 'update_priority',        label: 'Definir prioridade',       icon: 'i-lucide-flag' },
  { value: 'add_note',               label: 'Adicionar nota privada',   icon: 'i-lucide-sticky-note' },
];

const STATUS_OPTIONS = [
  { value: 'open',     label: 'Aberto' },
  { value: 'resolved', label: 'Resolvido' },
  { value: 'pending',  label: 'Pendente' },
  { value: 'snoozed',  label: 'Adiado' },
];

const PRIORITY_OPTIONS = [
  { value: 'none',   label: 'Sem prioridade' },
  { value: 'low',    label: 'Baixa' },
  { value: 'medium', label: 'Média' },
  { value: 'high',   label: 'Alta' },
  { value: 'urgent', label: 'Urgente' },
];

const DELAY_PRESETS = [
  { label: '0 min', value: 0 },
  { label: '15 min', value: 15 },
  { label: '30 min', value: 30 },
  { label: '1 h', value: 60 },
  { label: '4 h', value: 240 },
  { label: '1 dia', value: 1440 },
];

watch(() => form.value.action_type, () => {
  form.value.action_params = {};
});

const openCreate = () => {
  editingId.value = null;
  form.value = blankForm();
  showForm.value = true;
};

const openEdit = automation => {
  editingId.value = automation.id;
  form.value = {
    action_type: automation.action_type,
    delay_minutes: automation.delay_minutes ?? 0,
    active: automation.active,
    action_params: { ...automation.action_params },
  };
  showForm.value = true;
};

const cancelForm = () => {
  showForm.value = false;
  editingId.value = null;
  form.value = blankForm();
};

const saveForm = async () => {
  isSaving.value = true;
  try {
    const payload = {
      action_type: form.value.action_type,
      delay_minutes: Number(form.value.delay_minutes) || 0,
      active: form.value.active,
      action_params: form.value.action_params,
    };

    if (editingId.value) {
      await store.dispatch('kanbanStageAutomations/update', {
        funnelId: props.funnelId,
        stageId: props.stage.id,
        id: editingId.value,
        automation: payload,
      });
    } else {
      await store.dispatch('kanbanStageAutomations/create', {
        funnelId: props.funnelId,
        stageId: props.stage.id,
        automation: payload,
      });
    }
    cancelForm();
  } finally {
    isSaving.value = false;
  }
};

const deleteAutomation = async id => {
  if (!confirm('Excluir esta automação?')) return;
  await store.dispatch('kanbanStageAutomations/delete', {
    funnelId: props.funnelId,
    stageId: props.stage.id,
    id,
  });
};

const toggleActive = async automation => {
  await store.dispatch('kanbanStageAutomations/update', {
    funnelId: props.funnelId,
    stageId: props.stage.id,
    id: automation.id,
    automation: { active: !automation.active },
  });
};

// ─── Display helpers ────────────────────────────────────────────

const actionLabel = type => ACTION_TYPES.find(a => a.value === type)?.label || type;
const actionIcon  = type => ACTION_TYPES.find(a => a.value === type)?.icon || 'i-lucide-zap';

const automationSummary = automation => {
  const p = automation.action_params || {};
  switch (automation.action_type) {
    case 'send_message':
    case 'add_note':
    case 'send_scheduled_message':
      return p.content ? `"${p.content.slice(0, 60)}${p.content.length > 60 ? '…' : ''}"` : '(sem conteúdo)';
    case 'add_label':
    case 'remove_label':
      return p.label ? `Etiqueta: ${p.label}` : '(sem etiqueta)';
    case 'assign_agent':
      if (p.agent_id) {
        const a = agents.value.find(ag => String(ag.id) === String(p.agent_id));
        return a ? a.name : `Agente #${p.agent_id}`;
      }
      return '(sem agente)';
    case 'assign_team':
      if (p.team_id) {
        const tm = teams.value.find(t => String(t.id) === String(p.team_id));
        return tm ? tm.name : `Equipe #${p.team_id}`;
      }
      return '(sem equipe)';
    case 'update_status':
      return STATUS_OPTIONS.find(s => s.value === p.status)?.label || p.status || '(sem status)';
    case 'update_priority':
      return PRIORITY_OPTIONS.find(pr => pr.value === p.priority)?.label || p.priority || '(sem prioridade)';
    default:
      return '';
  }
};

const delayLabel = mins => {
  if (!mins || mins === 0) return 'Imediato';
  if (mins < 60) return `${mins} min após entrar no estágio`;
  if (mins < 1440) return `${mins / 60}h após entrar no estágio`;
  return `${Math.floor(mins / 1440)} dia(s) após entrar no estágio`;
};

const agentForId = id => agents.value.find(a => String(a.id) === String(id));
const teamForId  = id => teams.value.find(t => String(t.id) === String(id));

onMounted(async () => {
  await Promise.all([
    store.dispatch('kanbanStageAutomations/get', { funnelId: props.funnelId, stageId: props.stage.id }),
    store.dispatch('agents/get'),
    store.dispatch('teams/get'),
    store.dispatch('labels/get'),
  ]);
});

// Reload when stage changes
watch(() => props.stage.id, async newId => {
  if (newId) {
    await store.dispatch('kanbanStageAutomations/get', { funnelId: props.funnelId, stageId: newId });
  }
});
</script>

<template>
  <div class="flex flex-col gap-3">

    <!-- List of automations -->
    <div v-if="automations.length > 0" class="flex flex-col gap-2">
      <div
        v-for="auto in automations"
        :key="auto.id"
        class="group flex items-start gap-3 p-3 rounded-xl border transition-all"
        :class="auto.active ? 'bg-n-surface-1 border-n-weak hover:border-n-brand/30' : 'bg-n-alpha-1 border-n-weak/50 opacity-60'"
      >
        <!-- Action icon -->
        <div
          class="flex-shrink-0 w-9 h-9 rounded-lg flex items-center justify-center"
          :class="auto.active ? 'bg-n-brand/10 text-n-brand' : 'bg-n-alpha-2 text-n-slate-9'"
        >
          <i :class="[actionIcon(auto.action_type), 'text-base']" />
        </div>

        <!-- Content -->
        <div class="flex-1 min-w-0">
          <div class="flex items-center gap-2 flex-wrap">
            <span class="text-sm font-semibold text-n-slate-12">{{ actionLabel(auto.action_type) }}</span>
            <span
              class="text-[10px] px-1.5 py-0.5 rounded font-medium"
              :class="auto.active ? 'bg-n-brand/10 text-n-brand' : 'bg-n-alpha-2 text-n-slate-9'"
            >
              {{ auto.active ? 'Ativo' : 'Pausado' }}
            </span>
          </div>
          <p class="text-xs text-n-slate-11 mt-0.5 truncate">{{ automationSummary(auto) }}</p>
          <p class="text-[11px] text-n-slate-9 flex items-center gap-1 mt-0.5">
            <i class="i-lucide-clock text-[10px]" />
            {{ delayLabel(auto.delay_minutes) }}
          </p>
        </div>

        <!-- Actions (hover) -->
        <div class="flex items-center gap-1 flex-shrink-0 opacity-0 group-hover:opacity-100 transition-opacity">
          <button
            v-tooltip.top="auto.active ? 'Pausar' : 'Ativar'"
            class="p-1.5 rounded-lg text-n-slate-9 hover:text-n-slate-12 hover:bg-n-alpha-2 transition-colors"
            @click="toggleActive(auto)"
          >
            <i :class="auto.active ? 'i-lucide-pause' : 'i-lucide-play'" class="text-sm" />
          </button>
          <button
            v-tooltip.top="'Editar'"
            class="p-1.5 rounded-lg text-n-slate-9 hover:text-n-slate-12 hover:bg-n-alpha-2 transition-colors"
            @click="openEdit(auto)"
          >
            <i class="i-lucide-pencil text-sm" />
          </button>
          <button
            v-tooltip.top="'Excluir'"
            class="p-1.5 rounded-lg text-n-slate-9 hover:text-n-ruby-9 hover:bg-n-ruby-9/10 transition-colors"
            @click="deleteAutomation(auto.id)"
          >
            <i class="i-lucide-trash-2 text-sm" />
          </button>
        </div>
      </div>
    </div>

    <!-- Empty state -->
    <div v-else-if="!showForm" class="flex flex-col items-center justify-center py-8 text-center gap-3">
      <div class="w-12 h-12 rounded-2xl bg-n-alpha-2 flex items-center justify-center">
        <i class="i-lucide-zap text-xl text-n-slate-9" />
      </div>
      <div>
        <p class="text-sm font-medium text-n-slate-11">Nenhuma automação ainda</p>
        <p class="text-xs text-n-slate-9 mt-0.5">Adicione ações que executam quando um lead entra neste estágio</p>
      </div>
    </div>

    <!-- Add button (when not showing form) -->
    <button
      v-if="!showForm"
      class="flex items-center gap-2 w-full px-3 py-2.5 rounded-xl border border-dashed border-n-brand/40 text-n-brand text-sm font-medium hover:bg-n-brand/5 transition-all"
      @click="openCreate"
    >
      <i class="i-lucide-plus text-base" />
      Adicionar automação
    </button>

    <!-- ─── Inline form ────────────────────────────────────── -->
    <div v-if="showForm" class="rounded-xl border border-n-brand/30 bg-n-surface-1 overflow-hidden">
      <!-- Form header -->
      <div class="flex items-center justify-between px-4 py-3 bg-n-brand/5 border-b border-n-brand/20">
        <span class="text-sm font-semibold text-n-brand">
          {{ editingId ? 'Editar automação' : 'Nova automação' }}
        </span>
        <button class="text-n-slate-9 hover:text-n-slate-12 transition-colors" @click="cancelForm">
          <i class="i-lucide-x text-base" />
        </button>
      </div>

      <div class="px-4 py-4 space-y-4">

        <!-- Action type -->
        <div class="space-y-1.5">
          <label class="text-xs font-semibold text-n-slate-11 uppercase tracking-wide">Tipo de ação</label>
          <div class="grid grid-cols-2 gap-1.5 sm:grid-cols-3">
            <button
              v-for="opt in ACTION_TYPES"
              :key="opt.value"
              class="flex items-center gap-2 px-2.5 py-2 rounded-lg border text-xs font-medium transition-all text-left"
              :class="form.action_type === opt.value
                ? 'bg-n-brand/10 border-n-brand text-n-brand'
                : 'border-n-weak text-n-slate-11 hover:border-n-brand/40 hover:text-n-slate-12'"
              @click="form.action_type = opt.value"
            >
              <i :class="[opt.icon, 'text-sm flex-shrink-0']" />
              <span class="truncate">{{ opt.label }}</span>
            </button>
          </div>
        </div>

        <!-- Dynamic params -->
        <!-- send_message / add_note -->
        <div v-if="['send_message', 'add_note'].includes(form.action_type)" class="space-y-1.5">
          <label class="text-xs font-semibold text-n-slate-11 uppercase tracking-wide">
            {{ form.action_type === 'add_note' ? 'Conteúdo da nota' : 'Mensagem' }}
          </label>
          <textarea
            v-model="form.action_params.content"
            rows="3"
            class="w-full text-sm border border-n-weak rounded-lg px-3 py-2.5 bg-n-surface-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand/30 focus:border-n-brand resize-none"
            :placeholder="form.action_type === 'add_note' ? 'Escreva a nota interna…' : 'Digite a mensagem…'"
          />
          <label v-if="form.action_type === 'send_message'" class="flex items-center gap-2 cursor-pointer">
            <input v-model="form.action_params.is_private" type="checkbox" class="rounded" />
            <span class="text-xs text-n-slate-11">Enviar como nota privada</span>
          </label>
        </div>

        <!-- send_scheduled_message -->
        <div v-else-if="form.action_type === 'send_scheduled_message'" class="space-y-3">
          <div class="space-y-1.5">
            <label class="text-xs font-semibold text-n-slate-11 uppercase tracking-wide">Mensagem</label>
            <textarea
              v-model="form.action_params.content"
              rows="3"
              class="w-full text-sm border border-n-weak rounded-lg px-3 py-2.5 bg-n-surface-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand/30 focus:border-n-brand resize-none"
              placeholder="Mensagem a ser enviada no horário agendado…"
            />
          </div>
          <div class="space-y-1.5">
            <label class="text-xs font-semibold text-n-slate-11 uppercase tracking-wide">Enviar após</label>
            <div class="flex flex-wrap gap-1.5">
              <button
                v-for="p in DELAY_PRESETS.slice(1)"
                :key="p.value"
                class="px-3 py-1.5 rounded-lg text-xs font-medium border transition-all"
                :class="form.action_params.delay_minutes === p.value
                  ? 'bg-n-brand text-white border-n-brand'
                  : 'border-n-weak text-n-slate-11 hover:border-n-brand/40'"
                @click="form.action_params.delay_minutes = p.value"
              >
                {{ p.label }}
              </button>
            </div>
            <div class="flex items-center gap-2">
              <input
                v-model.number="form.action_params.delay_minutes"
                type="number"
                min="1"
                class="w-24 text-sm border border-n-weak rounded-lg px-2.5 py-1.5 bg-n-surface-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand/30 focus:border-n-brand"
              />
              <span class="text-xs text-n-slate-9">minutos após entrar no estágio</span>
            </div>
          </div>
          <label class="flex items-center gap-2 cursor-pointer">
            <input v-model="form.action_params.is_private" type="checkbox" class="rounded" />
            <span class="text-xs text-n-slate-11">Enviar como nota privada</span>
          </label>
        </div>

        <!-- add_label / remove_label -->
        <div v-else-if="['add_label', 'remove_label'].includes(form.action_type)" class="space-y-1.5">
          <label class="text-xs font-semibold text-n-slate-11 uppercase tracking-wide">Etiqueta</label>
          <select
            v-model="form.action_params.label"
            class="w-full text-sm border border-n-weak rounded-lg px-3 py-2.5 bg-n-surface-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand/30 focus:border-n-brand"
          >
            <option value="">— Selecione uma etiqueta —</option>
            <option v-for="lbl in labels" :key="lbl.id" :value="lbl.title">
              {{ lbl.title }}
            </option>
          </select>
        </div>

        <!-- assign_agent -->
        <div v-else-if="form.action_type === 'assign_agent'" class="space-y-1.5">
          <label class="text-xs font-semibold text-n-slate-11 uppercase tracking-wide">Agente</label>
          <div class="flex flex-col gap-1.5 max-h-48 overflow-y-auto">
            <button
              v-for="agent in agents"
              :key="agent.id"
              class="flex items-center gap-2.5 px-3 py-2 rounded-lg border text-left transition-all"
              :class="String(form.action_params.agent_id) === String(agent.id)
                ? 'bg-n-brand/10 border-n-brand'
                : 'border-n-weak hover:border-n-brand/40'"
              @click="form.action_params.agent_id = agent.id"
            >
              <Avatar :src="agent.thumbnail" :username="agent.name" :size="28" />
              <div class="flex flex-col min-w-0">
                <span class="text-sm font-medium text-n-slate-12 truncate">{{ agent.name }}</span>
                <span class="text-xs text-n-slate-9 truncate">{{ agent.email }}</span>
              </div>
              <i
                v-if="String(form.action_params.agent_id) === String(agent.id)"
                class="i-lucide-check text-n-brand text-sm ml-auto flex-shrink-0"
              />
            </button>
          </div>
        </div>

        <!-- assign_team -->
        <div v-else-if="form.action_type === 'assign_team'" class="space-y-1.5">
          <label class="text-xs font-semibold text-n-slate-11 uppercase tracking-wide">Equipe</label>
          <div class="flex flex-col gap-1.5">
            <button
              v-for="team in teams"
              :key="team.id"
              class="flex items-center gap-2.5 px-3 py-2 rounded-lg border text-left transition-all"
              :class="String(form.action_params.team_id) === String(team.id)
                ? 'bg-n-brand/10 border-n-brand'
                : 'border-n-weak hover:border-n-brand/40'"
              @click="form.action_params.team_id = team.id"
            >
              <div class="w-7 h-7 rounded-full bg-n-brand/10 flex items-center justify-center flex-shrink-0">
                <i class="i-lucide-users text-n-brand text-xs" />
              </div>
              <span class="text-sm font-medium text-n-slate-12 truncate">{{ team.name }}</span>
              <i
                v-if="String(form.action_params.team_id) === String(team.id)"
                class="i-lucide-check text-n-brand text-sm ml-auto flex-shrink-0"
              />
            </button>
          </div>
        </div>

        <!-- update_status -->
        <div v-else-if="form.action_type === 'update_status'" class="space-y-1.5">
          <label class="text-xs font-semibold text-n-slate-11 uppercase tracking-wide">Status</label>
          <div class="flex flex-wrap gap-1.5">
            <button
              v-for="opt in STATUS_OPTIONS"
              :key="opt.value"
              class="px-3 py-1.5 rounded-lg text-xs font-medium border transition-all"
              :class="form.action_params.status === opt.value
                ? 'bg-n-brand text-white border-n-brand'
                : 'border-n-weak text-n-slate-11 hover:border-n-brand/40'"
              @click="form.action_params.status = opt.value"
            >
              {{ opt.label }}
            </button>
          </div>
        </div>

        <!-- update_priority -->
        <div v-else-if="form.action_type === 'update_priority'" class="space-y-1.5">
          <label class="text-xs font-semibold text-n-slate-11 uppercase tracking-wide">Prioridade</label>
          <div class="flex flex-wrap gap-1.5">
            <button
              v-for="opt in PRIORITY_OPTIONS"
              :key="opt.value"
              class="px-3 py-1.5 rounded-lg text-xs font-medium border transition-all"
              :class="form.action_params.priority === opt.value
                ? 'bg-n-brand text-white border-n-brand'
                : 'border-n-weak text-n-slate-11 hover:border-n-brand/40'"
              @click="form.action_params.priority = opt.value"
            >
              {{ opt.label }}
            </button>
          </div>
        </div>

        <!-- Delay (for non-scheduled) -->
        <div v-if="form.action_type !== 'send_scheduled_message'" class="space-y-1.5">
          <label class="text-xs font-semibold text-n-slate-11 uppercase tracking-wide">
            Executar após entrar no estágio
          </label>
          <div class="flex flex-wrap gap-1.5">
            <button
              v-for="p in DELAY_PRESETS"
              :key="p.value"
              class="px-3 py-1.5 rounded-lg text-xs font-medium border transition-all"
              :class="form.delay_minutes === p.value
                ? 'bg-n-brand text-white border-n-brand'
                : 'border-n-weak text-n-slate-11 hover:border-n-brand/40'"
              @click="form.delay_minutes = p.value"
            >
              {{ p.label }}
            </button>
          </div>
          <div v-if="!DELAY_PRESETS.map(p => p.value).includes(form.delay_minutes)" class="flex items-center gap-2 mt-1">
            <input
              v-model.number="form.delay_minutes"
              type="number"
              min="0"
              class="w-24 text-sm border border-n-weak rounded-lg px-2.5 py-1.5 bg-n-surface-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand/30 focus:border-n-brand"
            />
            <span class="text-xs text-n-slate-9">minutos (customizado)</span>
          </div>
        </div>

        <!-- Form buttons -->
        <div class="flex items-center justify-end gap-2 pt-1 border-t border-n-weak">
          <Button variant="secondary" size="sm" @click="cancelForm">Cancelar</Button>
          <Button size="sm" :loading="isSaving" @click="saveForm">
            <i class="i-lucide-check text-sm mr-1" />
            Salvar automação
          </Button>
        </div>
      </div>
    </div>
  </div>
</template>
