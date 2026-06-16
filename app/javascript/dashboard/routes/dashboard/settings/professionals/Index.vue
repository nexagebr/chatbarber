<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { professionalsAPI } from 'dashboard/api/professionals';

const store = useStore();
const agents        = computed(() => store.getters['agents/getAgents'] ?? []);
const professionals = computed(() => store.getters['professionals/getProfessionals'] ?? []);
const uiFlags       = computed(() => store.getters['professionals/getUIFlags'] ?? {});

const profByAgentId = computed(() => {
  const m = {};
  for (const p of professionals.value) if (p.agent_id) m[p.agent_id] = p;
  return m;
});

onMounted(() => {
  store.dispatch('professionals/fetchProfessionals');
  store.dispatch('agents/get');
});

const DAYS = ['Dom','Seg','Ter','Qua','Qui','Sex','Sáb'];

function getBrandColor() {
  const rgb = getComputedStyle(document.documentElement).getPropertyValue('--n-brand').trim() || '66 65 255';
  return '#' + rgb.split(' ').map(n => parseInt(n).toString(16).padStart(2,'0')).join('');
}
function profColor(agent) {
  const p = profByAgentId.value[agent.id];
  return p?.color || getBrandColor();
}
function initials(name) { return (name||'?').split(' ').slice(0,2).map(w=>w[0]).join('').toUpperCase(); }
function isActive(agent) { const p = profByAgentId.value[agent.id]; return !!(p && p.active); }

// ── color picker ──────────────────────────────────────────────────────────────
const colorRefs = ref({});
async function pickColor(agent, newColor) {
  const p = profByAgentId.value[agent.id];
  if (!p) return;
  try {
    await store.dispatch('professionals/updateProfessional', { id: p.id, color: newColor });
  } catch { useAlert('Erro ao salvar cor.'); }
}

// ── toggle ────────────────────────────────────────────────────────────────────
const togglingId = ref(null);
async function toggleAgent(agent) {
  togglingId.value = agent.id;
  try {
    await store.dispatch('professionals/activateAgent', { agentId: agent.id, active: !isActive(agent) });
  } catch { useAlert('Erro ao atualizar.'); }
  togglingId.value = null;
}

// ── detail modal ──────────────────────────────────────────────────────────────
const detailModal = ref(null);
const detailForm  = ref({ specialty: '', commission_pct: 40 });
function openDetail(agent) {
  const p = profByAgentId.value[agent.id];
  detailForm.value = { specialty: p?.specialty||'', commission_pct: p?.commission_pct??40 };
  detailModal.value = { agent, professional: p };
}
async function saveDetail() {
  try {
    await store.dispatch('professionals/updateProfessional', { id: detailModal.value.professional.id, ...detailForm.value });
    useAlert('Salvo!'); detailModal.value = null;
  } catch { useAlert('Erro.'); }
}

// ── schedules modal ───────────────────────────────────────────────────────────
const schedModal = ref(null);
const schedules  = ref([]);
function openSchedules(agent) {
  const p = profByAgentId.value[agent.id];
  if (!p) { useAlert('Ative o agente como profissional primeiro.'); return; }
  const ex = p.schedules || [];
  schedules.value = DAYS.map((_, i) => {
    const f = ex.find(s => s.day_of_week === i);
    return { day_of_week: i, active: f ? f.active : i>=1&&i<=5, start_time: f?.start_time||'09:00', end_time: f?.end_time||'18:00' };
  });
  schedModal.value = { agent, professional: p };
}
async function saveSchedules() {
  try {
    await store.dispatch('professionals/setSchedules', { id: schedModal.value.professional.id, schedules: schedules.value });
    useAlert('Horários salvos!'); schedModal.value = null;
  } catch { useAlert('Erro.'); }
}

// ── blocked dates modal ───────────────────────────────────────────────────────
const blockedModal = ref(null);
const blockedDates = ref([]);
const blockedForm  = ref({ date:'', start_time:'', end_time:'', reason:'' });
async function openBlocked(agent) {
  const p = profByAgentId.value[agent.id];
  if (!p) { useAlert('Ative o agente como profissional primeiro.'); return; }
  blockedModal.value = { agent, professional: p };
  blockedDates.value = [];
  try { const { data } = await professionalsAPI.getBlockedDates(p.id); blockedDates.value = data; } catch { blockedDates.value = []; }
}
async function addBlocked() {
  if (!blockedForm.value.date) { useAlert('Selecione uma data.'); return; }
  try {
    const { data } = await professionalsAPI.addBlockedDate(blockedModal.value.professional.id, blockedForm.value);
    blockedDates.value.push(data);
    blockedForm.value = { date:'', start_time:'', end_time:'', reason:'' };
  } catch { useAlert('Erro.'); }
}
async function removeBlocked(bd) {
  try {
    await professionalsAPI.delBlockedDate(blockedModal.value.professional.id, bd.id);
    blockedDates.value = blockedDates.value.filter(x => x.id !== bd.id);
  } catch { useAlert('Erro.'); }
}

// ── breaks modal ──────────────────────────────────────────────────────────────
const breaksModal = ref(null);
const breaks      = ref([]);
const breakForm   = ref({ day_of_week: 1, start_time: '12:00', end_time: '13:00', label: 'Almoço' });
async function openBreaks(agent) {
  const p = profByAgentId.value[agent.id];
  if (!p) { useAlert('Ative o agente como profissional primeiro.'); return; }
  breaksModal.value = { agent, professional: p };
  breaks.value = [];
  try { const { data } = await professionalsAPI.getBreaks(p.id); breaks.value = data; } catch { breaks.value = []; }
}
async function addBreak() {
  try {
    const { data } = await professionalsAPI.addBreak(breaksModal.value.professional.id, breakForm.value);
    breaks.value.push(data);
    breakForm.value = { day_of_week: 1, start_time: '12:00', end_time: '13:00', label: 'Almoço' };
  } catch { useAlert('Erro.'); }
}
async function removeBreak(b) {
  try {
    await professionalsAPI.delBreak(breaksModal.value.professional.id, b.id);
    breaks.value = breaks.value.filter(x => x.id !== b.id);
  } catch { useAlert('Erro.'); }
}

// ── delete professional ───────────────────────────────────────────────────────
const deleteTarget = ref(null);
async function confirmDelete() {
  try {
    await store.dispatch('professionals/deleteProfessional', deleteTarget.value.professional.id);
    useAlert('Removido.');
  } catch { useAlert('Erro.'); }
  deleteTarget.value = null;
}
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">

    <!-- Header -->
    <header class="sticky top-0 z-10 px-6">
      <div class="w-full max-w-[60rem] mx-auto">
        <div class="flex items-center justify-between w-full py-0 h-20 gap-2">
          <span class="text-xl font-medium text-n-slate-12">Profissionais</span>
          <p class="text-sm text-n-slate-9 hidden lg:block flex-1 ml-6">
            Ative agentes como profissionais e configure horários, especialidade e datas bloqueadas.
          </p>
        </div>
      </div>
    </header>

    <!-- Content -->
    <main class="flex-1 px-6 overflow-y-auto">
      <div class="w-full max-w-[60rem] mx-auto py-4">

        <!-- Loading -->
        <div v-if="uiFlags.isFetching && !agents.length" class="flex items-center justify-center py-10 text-n-slate-11">
          <Spinner />
        </div>

        <!-- Empty -->
        <div v-else-if="agents.length === 0" class="flex flex-col items-center justify-center py-16 gap-6">
          <div class="w-16 h-16 rounded-2xl bg-n-alpha-black2 flex items-center justify-center">
            <span class="i-lucide-users text-3xl text-n-slate-8" />
          </div>
          <div class="text-center">
            <p class="text-base font-medium text-n-slate-12">Nenhum agente encontrado</p>
            <p class="text-sm text-n-slate-9 mt-1">Adicione agentes em Configurações → Agentes primeiro.</p>
          </div>
        </div>

        <!-- List -->
        <div v-else class="flex flex-col gap-2">
          <div
            v-for="agent in agents" :key="agent.id"
            class="flex items-center gap-4 px-4 py-3 rounded-xl border transition-all"
            :class="isActive(agent)
              ? 'bg-n-solid-1 border-n-brand/40 shadow-sm'
              : 'bg-n-solid-1 border-n-weak'"
          >
            <!-- Active accent bar -->
            <div
              class="w-0.5 self-stretch rounded-full flex-shrink-0 transition-all"
              :style="isActive(agent) ? { background: profColor(agent) } : { background: 'transparent' }"
            />

            <!-- Avatar -->
            <div
              class="w-11 h-11 rounded-full flex-shrink-0 flex items-center justify-center font-bold text-sm overflow-hidden"
              :style="{
                background: `${profColor(agent)}18`,
                border: `2px solid ${isActive(agent) ? profColor(agent) + '60' : profColor(agent) + '25'}`,
                color: profColor(agent)
              }"
            >
              <img v-if="agent.thumbnail" :src="agent.thumbnail" class="w-full h-full object-cover rounded-full" />
              <template v-else>{{ initials(agent.name) }}</template>
            </div>

            <!-- Info -->
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2">
                <p class="text-sm font-semibold text-n-slate-12 truncate">{{ agent.name }}</p>
                <span
                  v-if="isActive(agent)"
                  class="inline-flex items-center gap-1 px-1.5 py-0.5 rounded-md text-[10px] font-bold flex-shrink-0"
                  :style="{ background: profColor(agent) + '18', color: profColor(agent) }"
                >
                  <span class="w-1 h-1 rounded-full" :style="{ background: profColor(agent) }" />
                  Na agenda
                </span>
              </div>
              <p class="text-xs text-n-slate-9 truncate">{{ agent.email }}</p>
              <p v-if="profByAgentId[agent.id]" class="text-xs mt-0.5 text-n-slate-10">
                <template v-if="profByAgentId[agent.id].specialty">
                  <span class="font-medium">{{ profByAgentId[agent.id].specialty }}</span>
                  <span class="text-n-slate-8 mx-1">·</span>
                </template>
                {{ profByAgentId[agent.id].commission_pct }}% comissão
              </p>
            </div>

            <!-- Actions (active professional) -->
            <div v-if="isActive(agent) && profByAgentId[agent.id]" class="flex items-center gap-1 flex-shrink-0" @click.stop>
              <!-- Color picker -->
              <label
                class="w-8 h-8 rounded-lg flex items-center justify-center cursor-pointer hover:bg-n-alpha-2 transition-colors relative"
                :title="`Cor do profissional: ${profColor(agent)}`"
              >
                <span
                  class="w-4 h-4 rounded-full border-2 border-white shadow-sm"
                  :style="{ background: profColor(agent) }"
                />
                <input
                  type="color"
                  :value="profColor(agent)"
                  class="absolute opacity-0 w-0 h-0 pointer-events-none"
                  @change="e => pickColor(agent, e.target.value)"
                />
              </label>
              <button
                class="w-8 h-8 rounded-lg flex items-center justify-center text-n-slate-9 hover:bg-n-alpha-2 hover:text-n-slate-12 transition-colors"
                title="Editar especialidade e comissão"
                @click="openDetail(agent)"
              >
                <span class="i-lucide-pencil text-sm" />
              </button>
              <button
                class="w-8 h-8 rounded-lg flex items-center justify-center text-n-slate-9 hover:bg-n-alpha-2 hover:text-n-slate-12 transition-colors"
                title="Horários de trabalho"
                @click="openSchedules(agent)"
              >
                <span class="i-lucide-clock text-sm" />
              </button>
              <button
                class="w-8 h-8 rounded-lg flex items-center justify-center text-n-slate-9 hover:bg-n-alpha-2 hover:text-n-slate-12 transition-colors"
                title="Datas bloqueadas"
                @click="openBlocked(agent)"
              >
                <span class="i-lucide-calendar-x text-sm" />
              </button>
              <button
                class="w-8 h-8 rounded-lg flex items-center justify-center text-n-slate-9 hover:bg-n-alpha-2 hover:text-n-slate-12 transition-colors"
                title="Intervalos (almoço, pausa)"
                @click="openBreaks(agent)"
              >
                <span class="i-lucide-coffee text-sm" />
              </button>
              <div class="w-px h-5 bg-n-weak mx-1 flex-shrink-0" />
              <button
                class="w-8 h-8 rounded-lg flex items-center justify-center text-n-slate-9 hover:bg-ruby-3 hover:text-ruby-11 transition-colors"
                title="Remover da agenda"
                @click="deleteTarget = { agent, professional: profByAgentId[agent.id] }"
              >
                <span class="i-lucide-user-x text-sm" />
              </button>
            </div>

            <!-- Toggle -->
            <button
              class="relative h-6 w-11 rounded-full overflow-hidden transition-colors duration-200 flex-shrink-0 disabled:opacity-40 focus:outline-none"
              :class="isActive(agent) ? 'bg-n-brand' : 'bg-n-slate-5'"
              :disabled="togglingId === agent.id"
              :title="isActive(agent) ? 'Remover da agenda' : 'Adicionar à agenda'"
              @click="toggleAgent(agent)"
            >
              <span
                v-if="togglingId === agent.id"
                class="absolute inset-0 flex items-center justify-center"
              >
                <span class="w-3 h-3 rounded-full border-2 border-white border-t-transparent animate-spin" />
              </span>
              <span
                v-else
                class="absolute left-0.5 top-0.5 h-5 w-5 rounded-full bg-white shadow-sm transition-transform duration-200"
                :class="isActive(agent) ? 'translate-x-5' : 'translate-x-0'"
              />
            </button>
          </div>
        </div>
      </div>
    </main>

    <!-- ══ MODAL: detail ══════════════════════════════════════════════════════ -->
    <Teleport to="body">
      <div v-if="detailModal" class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div class="absolute inset-0 bg-black/50" @click="detailModal = null" />
        <div class="relative w-full max-w-sm bg-n-solid-1 rounded-2xl shadow-2xl border border-n-weak overflow-hidden">
          <div class="flex items-center justify-between px-6 py-4 border-b border-n-weak">
            <div class="flex items-center gap-2">
              <span class="i-lucide-pencil text-n-brand text-base" />
              <h3 class="text-sm font-semibold text-n-slate-12">{{ detailModal.agent.name }}</h3>
            </div>
            <button class="w-7 h-7 rounded-lg flex items-center justify-center text-n-slate-9 hover:bg-n-alpha-2 transition-colors" @click="detailModal = null">
              <span class="i-lucide-x text-sm" />
            </button>
          </div>
          <div class="px-6 py-5 flex flex-col gap-4">
            <div class="flex flex-col gap-1.5">
              <label class="text-xs font-semibold text-n-slate-10">Especialidade / Função</label>
              <input v-model="detailForm.specialty" class="h-10 px-3 rounded-lg border border-n-weak bg-n-solid-2 text-sm text-n-slate-12 placeholder:text-n-slate-8 focus:outline-none focus:ring-2 focus:ring-n-brand/30" placeholder="Ex: Barbeiro, Cabeleireiro..." />
            </div>
            <div class="flex flex-col gap-1.5">
              <label class="text-xs font-semibold text-n-slate-10">Comissão (%)</label>
              <input v-model.number="detailForm.commission_pct" type="number" min="0" max="100" step="0.5" class="h-10 px-3 rounded-lg border border-n-weak bg-n-solid-2 text-sm text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand/30" />
            </div>
          </div>
          <div class="flex items-center justify-end gap-3 px-6 py-4 border-t border-n-weak">
            <button class="h-9 px-4 rounded-lg border border-n-weak text-sm font-semibold text-n-slate-11 hover:bg-n-alpha-2 transition-colors" @click="detailModal = null">Cancelar</button>
            <button class="h-9 px-4 rounded-lg bg-n-brand text-white text-sm font-semibold hover:brightness-110 transition-all" @click="saveDetail">Salvar</button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ══ MODAL: schedules ═══════════════════════════════════════════════════ -->
    <Teleport to="body">
      <div v-if="schedModal" class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div class="absolute inset-0 bg-black/50" @click="schedModal = null" />
        <div class="relative w-full max-w-md bg-n-solid-1 rounded-2xl shadow-2xl border border-n-weak overflow-hidden">
          <div class="flex items-center justify-between px-6 py-4 border-b border-n-weak">
            <div class="flex items-center gap-2">
              <span class="i-lucide-clock text-n-brand text-base" />
              <h3 class="text-sm font-semibold text-n-slate-12">Horários — {{ schedModal.agent.name }}</h3>
            </div>
            <button class="w-7 h-7 rounded-lg flex items-center justify-center text-n-slate-9 hover:bg-n-alpha-2 transition-colors" @click="schedModal = null">
              <span class="i-lucide-x text-sm" />
            </button>
          </div>
          <div class="px-6 py-5 flex flex-col gap-3">
            <div v-for="s in schedules" :key="s.day_of_week" class="flex items-center gap-3">
              <button
                class="w-10 h-8 rounded-lg text-xs font-bold transition-all flex-shrink-0"
                :class="s.active ? 'text-white' : 'border border-n-weak bg-n-solid-2 text-n-slate-9'"
                :style="s.active ? { background: profColor(schedModal.agent.name) } : {}"
                @click="s.active = !s.active"
              >{{ DAYS[s.day_of_week] }}</button>
              <template v-if="s.active">
                <input v-model="s.start_time" type="time" class="h-8 px-2 rounded-lg border border-n-weak bg-n-solid-2 text-xs text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand/30 w-28" />
                <span class="text-n-slate-8 text-xs">–</span>
                <input v-model="s.end_time" type="time" class="h-8 px-2 rounded-lg border border-n-weak bg-n-solid-2 text-xs text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand/30 w-28" />
              </template>
              <span v-else class="text-xs text-n-slate-8 ml-1">Folga</span>
            </div>
          </div>
          <div class="flex items-center justify-end gap-3 px-6 py-4 border-t border-n-weak">
            <button class="h-9 px-4 rounded-lg border border-n-weak text-sm font-semibold text-n-slate-11 hover:bg-n-alpha-2 transition-colors" @click="schedModal = null">Cancelar</button>
            <button class="h-9 px-4 rounded-lg bg-n-brand text-white text-sm font-semibold hover:brightness-110 transition-all" @click="saveSchedules">Salvar horários</button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ══ MODAL: blocked dates ════════════════════════════════════════════════ -->
    <Teleport to="body">
      <div v-if="blockedModal" class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div class="absolute inset-0 bg-black/50" @click="blockedModal = null" />
        <div class="relative w-full max-w-lg bg-n-solid-1 rounded-2xl shadow-2xl border border-n-weak overflow-hidden">
          <div class="flex items-center justify-between px-6 py-4 border-b border-n-weak">
            <div class="flex items-center gap-2">
              <span class="i-lucide-calendar-x text-n-brand text-base" />
              <h3 class="text-sm font-semibold text-n-slate-12">Bloqueios — {{ blockedModal.agent.name }}</h3>
            </div>
            <button class="w-7 h-7 rounded-lg flex items-center justify-center text-n-slate-9 hover:bg-n-alpha-2 transition-colors" @click="blockedModal = null">
              <span class="i-lucide-x text-sm" />
            </button>
          </div>
          <div class="px-6 py-5 flex flex-col gap-4 max-h-[70vh] overflow-y-auto">
            <!-- Add form -->
            <div class="p-4 rounded-xl border border-n-weak bg-n-solid-2 flex flex-col gap-3">
              <p class="text-xs font-semibold text-n-slate-10">Adicionar bloqueio</p>
              <div class="grid grid-cols-2 gap-3">
                <div class="flex flex-col gap-1">
                  <label class="text-xs text-n-slate-9">Data *</label>
                  <input v-model="blockedForm.date" type="date" class="h-9 px-3 rounded-lg border border-n-weak bg-n-solid-1 text-sm text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand/30" />
                </div>
                <div class="flex flex-col gap-1">
                  <label class="text-xs text-n-slate-9">Motivo</label>
                  <input v-model="blockedForm.reason" class="h-9 px-3 rounded-lg border border-n-weak bg-n-solid-1 text-sm text-n-slate-12 placeholder:text-n-slate-8 focus:outline-none focus:ring-2 focus:ring-n-brand/30" placeholder="Opcional" />
                </div>
                <div class="flex flex-col gap-1">
                  <label class="text-xs text-n-slate-9">Início</label>
                  <input v-model="blockedForm.start_time" type="time" class="h-9 px-3 rounded-lg border border-n-weak bg-n-solid-1 text-sm text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand/30" />
                </div>
                <div class="flex flex-col gap-1">
                  <label class="text-xs text-n-slate-9">Fim</label>
                  <input v-model="blockedForm.end_time" type="time" class="h-9 px-3 rounded-lg border border-n-weak bg-n-solid-1 text-sm text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand/30" />
                </div>
              </div>
              <button
                class="inline-flex items-center gap-1.5 h-8 px-3 rounded-lg bg-n-brand text-white text-xs font-semibold hover:brightness-110 transition-all self-start"
                @click="addBlocked"
              >
                <span class="i-lucide-plus text-sm" />
                Adicionar
              </button>
            </div>
            <!-- List -->
            <div v-if="blockedDates.length" class="flex flex-col gap-2">
              <div v-for="bd in blockedDates" :key="bd.id" class="flex items-center gap-3 p-3 rounded-lg border border-n-weak bg-n-solid-2">
                <div class="w-2 h-2 rounded-full bg-ruby-9 flex-shrink-0" />
                <div class="flex-1 min-w-0">
                  <p class="text-sm font-semibold text-n-slate-12">{{ bd.date }}</p>
                  <p class="text-xs text-n-slate-9">
                    <template v-if="bd.start_time">{{ bd.start_time }} – {{ bd.end_time }}</template>
                    <template v-else>Dia inteiro</template>
                    <template v-if="bd.reason"> · {{ bd.reason }}</template>
                  </p>
                </div>
                <button class="w-7 h-7 rounded-lg flex items-center justify-center text-n-slate-9 hover:bg-ruby-3 hover:text-ruby-11 transition-colors flex-shrink-0" @click="removeBlocked(bd)">
                  <span class="i-lucide-x text-sm" />
                </button>
              </div>
            </div>
            <p v-else class="text-xs text-n-slate-8 text-center py-2">Nenhum bloqueio cadastrado.</p>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ══ MODAL: breaks ══════════════════════════════════════════════════════ -->
    <Teleport to="body">
      <div v-if="breaksModal" class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div class="absolute inset-0 bg-black/50" @click="breaksModal = null" />
        <div class="relative w-full max-w-lg bg-n-solid-1 rounded-2xl shadow-2xl border border-n-weak overflow-hidden">
          <div class="flex items-center justify-between px-6 py-4 border-b border-n-weak">
            <div class="flex items-center gap-2">
              <span class="i-lucide-coffee text-n-brand text-base" />
              <h3 class="text-sm font-semibold text-n-slate-12">Intervalos — {{ breaksModal.agent.name }}</h3>
            </div>
            <button class="w-7 h-7 rounded-lg flex items-center justify-center text-n-slate-9 hover:bg-n-alpha-2 transition-colors" @click="breaksModal = null">
              <span class="i-lucide-x text-sm" />
            </button>
          </div>
          <div class="px-6 py-5 flex flex-col gap-4 max-h-[70vh] overflow-y-auto">
            <!-- Add form -->
            <div class="p-4 rounded-xl border border-n-weak bg-n-solid-2 flex flex-col gap-3">
              <p class="text-xs font-semibold text-n-slate-10">Novo intervalo recorrente</p>
              <div class="grid grid-cols-2 gap-3">
                <div class="flex flex-col gap-1">
                  <label class="text-xs text-n-slate-9">Dia da semana</label>
                  <select v-model.number="breakForm.day_of_week" class="h-9 px-3 rounded-lg border border-n-weak bg-n-solid-1 text-sm text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand/30">
                    <option v-for="(d, i) in DAYS" :key="i" :value="i">{{ d }}</option>
                  </select>
                </div>
                <div class="flex flex-col gap-1">
                  <label class="text-xs text-n-slate-9">Descrição</label>
                  <input v-model="breakForm.label" class="h-9 px-3 rounded-lg border border-n-weak bg-n-solid-1 text-sm text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand/30" placeholder="Ex: Almoço" />
                </div>
                <div class="flex flex-col gap-1">
                  <label class="text-xs text-n-slate-9">Início</label>
                  <input v-model="breakForm.start_time" type="time" class="h-9 px-3 rounded-lg border border-n-weak bg-n-solid-1 text-sm text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand/30" />
                </div>
                <div class="flex flex-col gap-1">
                  <label class="text-xs text-n-slate-9">Fim</label>
                  <input v-model="breakForm.end_time" type="time" class="h-9 px-3 rounded-lg border border-n-weak bg-n-solid-1 text-sm text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand/30" />
                </div>
              </div>
              <button class="inline-flex items-center gap-1.5 h-8 px-3 rounded-lg bg-n-brand text-white text-xs font-semibold hover:brightness-110 transition-all self-start" @click="addBreak">
                <span class="i-lucide-plus text-sm" />
                Adicionar intervalo
              </button>
            </div>
            <!-- List -->
            <div v-if="breaks.length" class="flex flex-col gap-2">
              <div v-for="b in breaks" :key="b.id" class="flex items-center gap-3 p-3 rounded-lg border border-n-weak bg-n-solid-2">
                <span class="i-lucide-coffee text-n-slate-8 text-sm flex-shrink-0" />
                <div class="flex-1 min-w-0">
                  <p class="text-sm font-semibold text-n-slate-12">{{ DAYS[b.day_of_week] }} · {{ b.label }}</p>
                  <p class="text-xs text-n-slate-9">{{ b.start_time }} – {{ b.end_time }}</p>
                </div>
                <button class="w-7 h-7 rounded-lg flex items-center justify-center text-n-slate-9 hover:bg-ruby-3 hover:text-ruby-11 transition-colors" @click="removeBreak(b)">
                  <span class="i-lucide-x text-sm" />
                </button>
              </div>
            </div>
            <p v-else class="text-xs text-n-slate-8 text-center py-2">Nenhum intervalo cadastrado.</p>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ══ MODAL: delete confirm ═══════════════════════════════════════════════ -->
    <Teleport to="body">
      <div v-if="deleteTarget" class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div class="absolute inset-0 bg-black/50" @click="deleteTarget = null" />
        <div class="relative w-full max-w-sm bg-n-solid-1 rounded-2xl shadow-2xl border border-n-weak p-6 flex flex-col gap-4">
          <div class="flex items-start gap-3">
            <div class="w-10 h-10 rounded-full bg-ruby-3 flex items-center justify-center flex-shrink-0">
              <span class="i-lucide-trash-2 text-ruby-11 text-lg" />
            </div>
            <div>
              <h3 class="text-base font-semibold text-n-slate-12">Remover da agenda</h3>
              <p class="text-sm text-n-slate-10 mt-1">
                Remover <strong>{{ deleteTarget.agent.name }}</strong> como profissional?
                Os agendamentos existentes não serão afetados.
              </p>
            </div>
          </div>
          <div class="flex items-center justify-end gap-3">
            <button class="h-9 px-4 rounded-lg border border-n-weak text-sm font-semibold text-n-slate-11 hover:bg-n-alpha-2 transition-colors" @click="deleteTarget = null">Cancelar</button>
            <button class="h-9 px-4 rounded-lg bg-ruby-9 text-white text-sm font-semibold hover:bg-ruby-10 transition-colors" @click="confirmDelete">Remover</button>
          </div>
        </div>
      </div>
    </Teleport>

  </section>
</template>
