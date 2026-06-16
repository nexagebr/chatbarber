<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { branchesAPI } from 'dashboard/api/professionals';

const store = useStore();

const branches      = computed(() => store.getters['professionals/getBranches'] ?? []);
const professionals = computed(() => store.getters['professionals/getProfessionals'] ?? []);
const uiFlags       = computed(() => store.getters['professionals/getUIFlags'] ?? {});

onMounted(() => {
  store.dispatch('professionals/fetchBranches');
  store.dispatch('professionals/fetchProfessionals');
});

const DAYS = ['Dom','Seg','Ter','Qua','Qui','Sex','Sáb'];

function initials(name) {
  return (name||'?').split(' ').slice(0,2).map(w=>w[0]).join('').toUpperCase();
}
const PROF_COLORS = ['#5B6CF5','#A855F7','#0EA5E9','#F97316','#22C55E','#EF4444','#EC4899','#EAB308'];
function profColor(name) { return PROF_COLORS[(name||'?').charCodeAt(0) % PROF_COLORS.length]; }

// ── create / edit modal ───────────────────────────────────────────────────────
const formModal = ref(null);
const form      = ref({ name:'', address:'', phone:'', description:'', active:true });
const saving    = ref(false);

function openNew() {
  form.value = { name:'', address:'', phone:'', description:'', active:true };
  formModal.value = {};
}
function openEdit(b) {
  form.value = { name: b.name||'', address: b.address||'', phone: b.phone||'', description: b.description||'', active: b.active!==false };
  formModal.value = b;
}
async function saveBranch() {
  if (!form.value.name?.trim()) { useAlert('Nome é obrigatório.'); return; }
  saving.value = true;
  try {
    if (formModal.value?.id) {
      await store.dispatch('professionals/updateBranch', { id: formModal.value.id, ...form.value });
    } else {
      await store.dispatch('professionals/createBranch', form.value);
    }
    useAlert('Salvo!'); formModal.value = null;
  } catch { useAlert('Erro ao salvar.'); }
  saving.value = false;
}

// ── professionals modal ────────────────────────────────────────────────────────
const profModal   = ref(null);
const profSaving  = ref(false);
const selectedIds = ref([]);

function openProfs(b) {
  selectedIds.value = [...(b.professional_ids || [])];
  profModal.value = b;
}
function toggleProf(id) {
  if (selectedIds.value.includes(id)) {
    selectedIds.value = selectedIds.value.filter(x => x !== id);
  } else {
    selectedIds.value = [...selectedIds.value, id];
  }
}
async function saveProfs() {
  profSaving.value = true;
  try {
    await store.dispatch('professionals/updateBranch', { id: profModal.value.id, professional_ids: selectedIds.value });
    useAlert('Profissionais atualizados!'); profModal.value = null;
  } catch { useAlert('Erro.'); }
  profSaving.value = false;
}

// ── schedules modal ───────────────────────────────────────────────────────────
const schedModal  = ref(null);
const schedules   = ref([]);
const schedSaving = ref(false);

function openSchedules(b) {
  const ex = b.branch_schedules || [];
  schedules.value = DAYS.map((_, i) => {
    const f = ex.find(s => s.day_of_week === i);
    return { day_of_week: i, active: f ? f.active : i>=1&&i<=5, start_time: f?.start_time||'09:00', end_time: f?.end_time||'18:00' };
  });
  schedModal.value = b;
}
async function saveSchedules() {
  schedSaving.value = true;
  try {
    await store.dispatch('professionals/setBranchSchedules', { id: schedModal.value.id, schedules: schedules.value });
    useAlert('Horários salvos!'); schedModal.value = null;
  } catch { useAlert('Erro.'); }
  schedSaving.value = false;
}

// ── holidays modal ────────────────────────────────────────────────────────────
const holidayModal = ref(null);
const holidays     = ref([]);
const holidayForm  = ref({ date: '', name: '' });
const holidaySaving = ref(false);

async function openHolidays(b) {
  holidayModal.value = b;
  holidays.value = [];
  try { const { data } = await branchesAPI.getHolidays(b.id); holidays.value = data; } catch { holidays.value = []; }
}
async function addHoliday() {
  if (!holidayForm.value.date || !holidayForm.value.name) { useAlert('Data e nome são obrigatórios.'); return; }
  holidaySaving.value = true;
  try {
    const { data } = await branchesAPI.addHoliday(holidayModal.value.id, holidayForm.value);
    holidays.value = holidays.value.filter(h => h.date !== data.date);
    holidays.value.push(data);
    holidays.value.sort((a,b) => a.date.localeCompare(b.date));
    holidayForm.value = { date: '', name: '' };
  } catch { useAlert('Erro.'); }
  holidaySaving.value = false;
}
async function removeHoliday(h) {
  try {
    await branchesAPI.delHoliday(holidayModal.value.id, h.id);
    holidays.value = holidays.value.filter(x => x.id !== h.id);
  } catch { useAlert('Erro.'); }
}

// ── delete ────────────────────────────────────────────────────────────────────
const deleteTarget = ref(null);
async function confirmDelete() {
  try {
    await store.dispatch('professionals/deleteBranch', deleteTarget.value.id);
    useAlert('Filial removida.');
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
          <span class="text-xl font-medium text-n-slate-12">Filiais</span>
          <p class="text-sm text-n-slate-9 hidden lg:block flex-1 ml-6">
            Gerencie as filiais, seus profissionais e horários de funcionamento.
          </p>
          <button
            class="inline-flex items-center gap-1.5 h-8 px-3 rounded-lg bg-n-brand text-white text-sm font-medium hover:brightness-110 transition-all flex-shrink-0"
            @click="openNew"
          >
            <span class="i-lucide-plus text-base" />
            Nova filial
          </button>
        </div>
      </div>
    </header>

    <!-- Content -->
    <main class="flex-1 px-6 overflow-y-auto">
      <div class="w-full max-w-[60rem] mx-auto py-4">

        <!-- Loading -->
        <div v-if="uiFlags.isFetchingBranches && !branches.length" class="flex items-center justify-center py-10 text-n-slate-11">
          <Spinner />
        </div>

        <!-- Empty -->
        <div v-else-if="branches.length === 0" class="flex flex-col items-center justify-center py-16 gap-6">
          <div class="w-16 h-16 rounded-2xl bg-n-alpha-black2 flex items-center justify-center">
            <span class="i-lucide-store text-3xl text-n-slate-8" />
          </div>
          <div class="text-center">
            <p class="text-base font-medium text-n-slate-12">Nenhuma filial cadastrada</p>
            <p class="text-sm text-n-slate-9 mt-1">Crie sua primeira filial para organizar profissionais por unidade.</p>
          </div>
          <button
            class="inline-flex items-center gap-1.5 h-9 px-4 rounded-lg bg-n-brand text-white text-sm font-medium hover:brightness-110 transition-all"
            @click="openNew"
          >
            <span class="i-lucide-plus text-base" />
            Nova filial
          </button>
        </div>

        <!-- List -->
        <div v-else class="flex flex-col gap-3">
          <div
            v-for="b in branches" :key="b.id"
            class="flex items-start gap-4 p-4 rounded-xl border border-n-weak bg-n-solid-1 transition-colors group"
          >
            <!-- Icon -->
            <div class="w-10 h-10 rounded-xl bg-n-alpha-black2 flex items-center justify-center flex-shrink-0">
              <span class="i-lucide-store text-xl text-n-brand" />
            </div>

            <!-- Info -->
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2 flex-wrap">
                <p class="text-base text-n-slate-12 font-medium">{{ b.name }}</p>
                <span
                  class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-semibold"
                  :class="b.active !== false ? 'bg-woot-50 text-woot-600' : 'bg-n-alpha-black2 text-n-slate-9'"
                >{{ b.active !== false ? 'Ativa' : 'Inativa' }}</span>
              </div>
              <p v-if="b.address" class="text-sm text-n-slate-9 mt-0.5 truncate">
                <span class="i-lucide-map-pin text-xs mr-1" />{{ b.address }}
              </p>
              <p v-if="b.phone" class="text-sm text-n-slate-9 mt-0.5">
                <span class="i-lucide-phone text-xs mr-1" />{{ b.phone }}
              </p>

              <!-- Professionals avatars -->
              <div v-if="b.professionals && b.professionals.length" class="flex items-center gap-1.5 mt-2 flex-wrap">
                <div
                  v-for="p in b.professionals.slice(0,8)" :key="p.id"
                  class="w-6 h-6 rounded-full overflow-hidden flex items-center justify-center text-xs font-bold flex-shrink-0"
                  :style="{ background: `${profColor(p.name)}14`, border: `1.5px solid ${profColor(p.name)}40`, color: profColor(p.name) }"
                  :title="p.name"
                >
                  <img v-if="p.thumbnail" :src="p.thumbnail" class="w-full h-full object-cover rounded-full" />
                  <template v-else>{{ initials(p.name) }}</template>
                </div>
                <span v-if="b.professionals.length > 8" class="text-xs text-n-slate-9">+{{ b.professionals.length - 8 }}</span>
                <span class="text-xs text-n-slate-9">{{ b.professionals.length }} profissional{{ b.professionals.length > 1 ? 'is' : '' }}</span>
              </div>
              <div v-else class="mt-1.5">
                <span class="text-xs text-n-slate-8">Nenhum profissional vinculado</span>
              </div>
            </div>

            <!-- Actions -->
            <div
              class="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity flex-shrink-0 pt-0.5"
              @click.stop
            >
              <button
                class="h-8 px-2.5 rounded-lg flex items-center gap-1.5 text-xs font-medium text-n-slate-10 hover:bg-n-alpha-2 transition-colors"
                @click="openProfs(b)"
              >
                <span class="i-lucide-users text-sm" />
                Profissionais
              </button>
              <button
                class="h-8 px-2.5 rounded-lg flex items-center gap-1.5 text-xs font-medium text-n-slate-10 hover:bg-n-alpha-2 transition-colors"
                @click="openSchedules(b)"
              >
                <span class="i-lucide-clock text-sm" />
                Horários
              </button>
              <button
                class="h-8 px-2.5 rounded-lg flex items-center gap-1.5 text-xs font-medium text-n-slate-10 hover:bg-n-alpha-2 transition-colors"
                @click="openHolidays(b)"
              >
                <span class="i-lucide-calendar-days text-sm" />
                Feriados
              </button>
              <button
                class="h-8 px-2.5 rounded-lg flex items-center gap-1.5 text-xs font-medium text-n-slate-10 hover:bg-n-alpha-2 transition-colors"
                @click="openEdit(b)"
              >
                <span class="i-lucide-pencil text-sm" />
                Editar
              </button>
              <button
                class="w-8 h-8 rounded-lg flex items-center justify-center text-n-slate-9 hover:bg-ruby-3 hover:text-ruby-11 transition-colors"
                @click="deleteTarget = b"
              >
                <span class="i-lucide-trash-2 text-sm" />
              </button>
            </div>
          </div>
        </div>
      </div>
    </main>

    <!-- ══ MODAL: create / edit ═══════════════════════════════════════════════ -->
    <Teleport to="body">
      <div v-if="formModal !== null" class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div class="absolute inset-0 bg-black/50" @click="formModal = null" />
        <div class="relative w-full max-w-md bg-n-solid-1 rounded-2xl shadow-2xl border border-n-weak overflow-hidden">
          <div class="flex items-center justify-between px-6 py-4 border-b border-n-weak">
            <div class="flex items-center gap-2">
              <span class="i-lucide-store text-n-brand text-base" />
              <h3 class="text-sm font-semibold text-n-slate-12">{{ formModal?.id ? 'Editar filial' : 'Nova filial' }}</h3>
            </div>
            <button class="w-7 h-7 rounded-lg flex items-center justify-center text-n-slate-9 hover:bg-n-alpha-2 transition-colors" @click="formModal = null">
              <span class="i-lucide-x text-sm" />
            </button>
          </div>
          <div class="px-6 py-5 flex flex-col gap-4">
            <div class="flex flex-col gap-1.5">
              <label class="text-xs font-semibold text-n-slate-10">Nome *</label>
              <input v-model="form.name" class="h-10 px-3 rounded-lg border border-n-weak bg-n-solid-2 text-sm text-n-slate-12 placeholder:text-n-slate-8 focus:outline-none focus:ring-2 focus:ring-n-brand/30" placeholder="Ex: Filial Centro" />
            </div>
            <div class="flex flex-col gap-1.5">
              <label class="text-xs font-semibold text-n-slate-10">Endereço</label>
              <input v-model="form.address" class="h-10 px-3 rounded-lg border border-n-weak bg-n-solid-2 text-sm text-n-slate-12 placeholder:text-n-slate-8 focus:outline-none focus:ring-2 focus:ring-n-brand/30" placeholder="Rua, número, bairro..." />
            </div>
            <div class="flex flex-col gap-1.5">
              <label class="text-xs font-semibold text-n-slate-10">Telefone</label>
              <input v-model="form.phone" class="h-10 px-3 rounded-lg border border-n-weak bg-n-solid-2 text-sm text-n-slate-12 placeholder:text-n-slate-8 focus:outline-none focus:ring-2 focus:ring-n-brand/30" placeholder="(11) 99999-0000" />
            </div>
            <div class="flex flex-col gap-1.5">
              <label class="text-xs font-semibold text-n-slate-10">Descrição</label>
              <textarea v-model="form.description" rows="2" class="px-3 py-2.5 rounded-lg border border-n-weak bg-n-solid-2 text-sm text-n-slate-12 placeholder:text-n-slate-8 focus:outline-none focus:ring-2 focus:ring-n-brand/30 resize-none" placeholder="Observações..." />
            </div>
            <div class="flex items-center justify-between py-1">
              <label class="text-xs font-semibold text-n-slate-10">Filial ativa</label>
              <button
                class="relative inline-flex h-5 w-9 items-center rounded-full transition-colors"
                :class="form.active ? 'bg-n-brand' : 'bg-n-alpha-black2'"
                type="button"
                @click="form.active = !form.active"
              >
                <span class="inline-block h-3.5 w-3.5 transform rounded-full bg-white shadow transition-transform" :class="form.active ? 'translate-x-4' : 'translate-x-0.5'" />
              </button>
            </div>
          </div>
          <div class="flex items-center justify-end gap-3 px-6 py-4 border-t border-n-weak">
            <button class="h-9 px-4 rounded-lg border border-n-weak text-sm font-semibold text-n-slate-11 hover:bg-n-alpha-2 transition-colors" @click="formModal = null">Cancelar</button>
            <button class="h-9 px-4 rounded-lg bg-n-brand text-white text-sm font-semibold hover:brightness-110 transition-all disabled:opacity-50" :disabled="saving" @click="saveBranch">
              {{ saving ? 'Salvando...' : 'Salvar' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ══ MODAL: professionals ════════════════════════════════════════════════ -->
    <Teleport to="body">
      <div v-if="profModal" class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div class="absolute inset-0 bg-black/50" @click="profModal = null" />
        <div class="relative w-full max-w-md bg-n-solid-1 rounded-2xl shadow-2xl border border-n-weak overflow-hidden">
          <div class="flex items-center justify-between px-6 py-4 border-b border-n-weak">
            <div class="flex items-center gap-2">
              <span class="i-lucide-users text-n-brand text-base" />
              <h3 class="text-sm font-semibold text-n-slate-12">Profissionais — {{ profModal.name }}</h3>
            </div>
            <button class="w-7 h-7 rounded-lg flex items-center justify-center text-n-slate-9 hover:bg-n-alpha-2 transition-colors" @click="profModal = null">
              <span class="i-lucide-x text-sm" />
            </button>
          </div>
          <div class="px-6 py-5 flex flex-col gap-2 max-h-[50vh] overflow-y-auto">
            <p v-if="professionals.length === 0" class="text-sm text-n-slate-9 text-center py-4">Nenhum profissional ativo.</p>
            <button
              v-for="p in professionals" :key="p.id"
              class="flex items-center gap-3 p-3 rounded-xl border transition-all"
              :class="selectedIds.includes(p.id) ? 'border-n-brand bg-n-brand/5' : 'border-n-weak bg-n-solid-2 hover:bg-n-alpha-1'"
              @click="toggleProf(p.id)"
            >
              <div
                class="w-8 h-8 rounded-full flex-shrink-0 flex items-center justify-center text-xs font-bold overflow-hidden"
                :style="{ background: `${profColor(p.name)}14`, border: `1.5px solid ${profColor(p.name)}40`, color: profColor(p.name) }"
              >
                <img v-if="p.thumbnail" :src="p.thumbnail" class="w-full h-full object-cover rounded-full" />
                <template v-else>{{ initials(p.name) }}</template>
              </div>
              <div class="flex-1 min-w-0 text-left">
                <p class="text-sm font-semibold text-n-slate-12 truncate">{{ p.name }}</p>
                <p v-if="p.specialty" class="text-xs text-n-slate-9 truncate">{{ p.specialty }}</p>
              </div>
              <span v-if="selectedIds.includes(p.id)" class="i-lucide-check-circle text-n-brand text-base flex-shrink-0" />
            </button>
          </div>
          <div class="flex items-center justify-between px-6 py-4 border-t border-n-weak">
            <p class="text-xs text-n-slate-9">{{ selectedIds.length }} selecionado{{ selectedIds.length !== 1 ? 's' : '' }}</p>
            <div class="flex items-center gap-3">
              <button class="h-9 px-4 rounded-lg border border-n-weak text-sm font-semibold text-n-slate-11 hover:bg-n-alpha-2 transition-colors" @click="profModal = null">Cancelar</button>
              <button class="h-9 px-4 rounded-lg bg-n-brand text-white text-sm font-semibold hover:brightness-110 transition-all disabled:opacity-50" :disabled="profSaving" @click="saveProfs">
                {{ profSaving ? 'Salvando...' : 'Salvar' }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ══ MODAL: schedules ════════════════════════════════════════════════════ -->
    <Teleport to="body">
      <div v-if="schedModal" class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div class="absolute inset-0 bg-black/50" @click="schedModal = null" />
        <div class="relative w-full max-w-md bg-n-solid-1 rounded-2xl shadow-2xl border border-n-weak overflow-hidden">
          <div class="flex items-center justify-between px-6 py-4 border-b border-n-weak">
            <div class="flex items-center gap-2">
              <span class="i-lucide-clock text-n-brand text-base" />
              <h3 class="text-sm font-semibold text-n-slate-12">Horários — {{ schedModal.name }}</h3>
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
                :style="s.active ? { background: 'rgb(var(--n-brand,66 65 255))' } : {}"
                @click="s.active = !s.active"
              >{{ DAYS[s.day_of_week] }}</button>
              <template v-if="s.active">
                <input v-model="s.start_time" type="time" class="h-8 px-2 rounded-lg border border-n-weak bg-n-solid-2 text-xs text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand/30 w-28" />
                <span class="text-n-slate-8 text-xs">–</span>
                <input v-model="s.end_time" type="time" class="h-8 px-2 rounded-lg border border-n-weak bg-n-solid-2 text-xs text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand/30 w-28" />
              </template>
              <span v-else class="text-xs text-n-slate-8 ml-1">Fechado</span>
            </div>
          </div>
          <div class="flex items-center justify-end gap-3 px-6 py-4 border-t border-n-weak">
            <button class="h-9 px-4 rounded-lg border border-n-weak text-sm font-semibold text-n-slate-11 hover:bg-n-alpha-2 transition-colors" @click="schedModal = null">Cancelar</button>
            <button class="h-9 px-4 rounded-lg bg-n-brand text-white text-sm font-semibold hover:brightness-110 transition-all disabled:opacity-50" :disabled="schedSaving" @click="saveSchedules">
              {{ schedSaving ? 'Salvando...' : 'Salvar horários' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ══ MODAL: holidays ════════════════════════════════════════════════════ -->
    <Teleport to="body">
      <div v-if="holidayModal" class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div class="absolute inset-0 bg-black/50" @click="holidayModal = null" />
        <div class="relative w-full max-w-lg bg-n-solid-1 rounded-2xl shadow-2xl border border-n-weak overflow-hidden">
          <div class="flex items-center justify-between px-6 py-4 border-b border-n-weak">
            <div class="flex items-center gap-2">
              <span class="i-lucide-calendar-days text-n-brand text-base" />
              <h3 class="text-sm font-semibold text-n-slate-12">Feriados — {{ holidayModal.name }}</h3>
            </div>
            <button class="w-7 h-7 rounded-lg flex items-center justify-center text-n-slate-9 hover:bg-n-alpha-2 transition-colors" @click="holidayModal = null">
              <span class="i-lucide-x text-sm" />
            </button>
          </div>
          <div class="px-6 py-5 flex flex-col gap-4 max-h-[70vh] overflow-y-auto">
            <!-- Add form -->
            <div class="p-4 rounded-xl border border-n-weak bg-n-solid-2 flex flex-col gap-3">
              <p class="text-xs font-semibold text-n-slate-10">Adicionar feriado / folga</p>
              <div class="grid grid-cols-2 gap-3">
                <div class="flex flex-col gap-1">
                  <label class="text-xs text-n-slate-9">Data *</label>
                  <input v-model="holidayForm.date" type="date" class="h-9 px-3 rounded-lg border border-n-weak bg-n-solid-1 text-sm text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand/30" />
                </div>
                <div class="flex flex-col gap-1">
                  <label class="text-xs text-n-slate-9">Nome *</label>
                  <input v-model="holidayForm.name" class="h-9 px-3 rounded-lg border border-n-weak bg-n-solid-1 text-sm text-n-slate-12 placeholder:text-n-slate-8 focus:outline-none focus:ring-2 focus:ring-n-brand/30" placeholder="Ex: Natal, Folga..." />
                </div>
              </div>
              <button
                class="inline-flex items-center gap-1.5 h-8 px-3 rounded-lg bg-n-brand text-white text-xs font-semibold hover:brightness-110 transition-all self-start disabled:opacity-50"
                :disabled="holidaySaving"
                @click="addHoliday"
              >
                <span class="i-lucide-plus text-sm" />
                Adicionar
              </button>
            </div>
            <!-- List -->
            <div v-if="holidays.length" class="flex flex-col gap-2">
              <div v-for="h in holidays" :key="h.id" class="flex items-center gap-3 p-3 rounded-lg border border-n-weak bg-n-solid-2">
                <div class="w-2 h-2 rounded-full bg-amber-400 flex-shrink-0" />
                <div class="flex-1 min-w-0">
                  <p class="text-sm font-semibold text-n-slate-12">{{ h.name }}</p>
                  <p class="text-xs text-n-slate-9">{{ new Date(h.date + 'T12:00:00').toLocaleDateString('pt-BR', { weekday: 'long', day: '2-digit', month: 'long' }) }}</p>
                </div>
                <button class="w-7 h-7 rounded-lg flex items-center justify-center text-n-slate-9 hover:bg-ruby-3 hover:text-ruby-11 transition-colors" @click="removeHoliday(h)">
                  <span class="i-lucide-x text-sm" />
                </button>
              </div>
            </div>
            <p v-else class="text-xs text-n-slate-8 text-center py-2">Nenhum feriado cadastrado para esta filial.</p>
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
              <h3 class="text-base font-semibold text-n-slate-12">Excluir filial</h3>
              <p class="text-sm text-n-slate-10 mt-1">
                Tem certeza que deseja excluir <strong>{{ deleteTarget.name }}</strong>?
                Esta ação não pode ser desfeita.
              </p>
            </div>
          </div>
          <div class="flex items-center justify-end gap-3">
            <button class="h-9 px-4 rounded-lg border border-n-weak text-sm font-semibold text-n-slate-11 hover:bg-n-alpha-2 transition-colors" @click="deleteTarget = null">Cancelar</button>
            <button class="h-9 px-4 rounded-lg bg-ruby-9 text-white text-sm font-semibold hover:bg-ruby-10 transition-colors" @click="confirmDelete">Excluir</button>
          </div>
        </div>
      </div>
    </Teleport>

  </section>
</template>
