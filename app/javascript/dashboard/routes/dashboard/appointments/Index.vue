<script setup>
import { ref, computed, watch, onMounted, onUnmounted, nextTick } from 'vue';
import { useStore } from 'vuex';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import { availabilityAPI } from 'dashboard/api/professionals';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ReminderSettings from './ReminderSettings.vue';
import RetentionSettings from './RetentionSettings.vue';

const store         = useStore();
const router        = useRouter();
const { accountId } = useAccount();
const allAppts      = computed(() => store.getters['appointments/getList'] ?? []);
const services      = computed(() => store.getters['appointments/getServices'] ?? []);
const uiFlags       = computed(() => store.getters['appointments/getUIFlags'] ?? {});
const contacts      = computed(() => store.getters['contacts/getContacts'] ?? []);
const allAgents     = computed(() => store.getters['agents/getAgents'] ?? []);
const allProfs      = computed(() => store.getters['professionals/getProfessionals'] ?? []);
const branches      = computed(() => store.getters['professionals/getBranches'] ?? []);

// ── active branch ─────────────────────────────────────────────────────────────
const activeBranchId = ref(null); // null = show all active professionals

const visibleProfs = computed(() => {
  const active = allProfs.value.filter(p => p.active);
  if (!activeBranchId.value) return active;
  const branch = branches.value.find(b => b.id === activeBranchId.value);
  if (!branch) return active;
  const ids = new Set(branch.professional_ids || []);
  return active.filter(p => ids.has(p.id));
});

// build display objects merging professional + agent data
const profCols = computed(() =>
  visibleProfs.value.map((p, idx) => {
    const agent = allAgents.value.find(a => a.id === p.agent_id);
    return {
      profId: p.id,
      agentId: p.agent_id,
      name: agent?.name || p.name,
      thumbnail: agent?.thumbnail || p.thumbnail,
      specialty: p.specialty,
      color: p.color || null,
      idx,
    };
  })
);

// ── constants (matching barber-app) ──────────────────────────────────────────
const SLOT_H    = 28      // px per 10-min slot
const TIME_W    = 54      // time gutter width
const COL_MIN   = 150     // min column width
const START_MIN = 7 * 60  // 07:00
const END_MIN   = 22 * 60 // 22:00
const TOTAL_SLOTS = (END_MIN - START_MIN) / 10
const SLOTS_ARR   = Array.from({ length: TOTAL_SLOTS }, (_, i) => i)

function getBrandColor() {
  const rgb = getComputedStyle(document.documentElement).getPropertyValue('--n-brand').trim() || '66 65 255';
  return '#' + rgb.split(' ').map(n => parseInt(n).toString(16).padStart(2,'0')).join('');
}

const STATUS_CFG = {
  scheduled:   { label: 'Agendado',       color: '#D97706', dot: '#F59E0B' },
  in_progress: { label: 'Em andamento',   color: '#5B6CF5', dot: '#5B6CF5' },
  completed:   { label: 'Concluído',      color: '#64748B', dot: '#94A3B8' },
  cancelled:   { label: 'Cancelado',      color: '#EF4444', dot: '#EF4444' },
}
const STATUS_OPTS = Object.entries(STATUS_CFG).map(([value, cfg]) => ({ value, ...cfg }))

const TYPE_LABELS = { service: 'Serviço', meeting: 'Reunião', event: 'Evento', task: 'Tarefa' }
const LOC_LABELS  = { in_person: 'Presencial', online: 'Online' }

// ── module-level drag grab offset (same pattern as barber-app) ───────────────
let _grabOffsetY = 0

// ── date helpers ──────────────────────────────────────────────────────────────
function localDateStr(d = new Date()) {
  return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`
}
function todayStr() { return localDateStr() }
function addDays(str, n) {
  const [y, m, d] = str.split('-').map(Number)
  return localDateStr(new Date(y, m-1, d+n))
}
function fmtDateLong(str) {
  const [y, m, d] = str.split('-').map(Number)
  return new Date(y, m-1, d).toLocaleDateString('pt-BR', { weekday: 'long', day: '2-digit', month: 'long', year: 'numeric' })
}
function fmtTime(iso) { return new Date(iso).toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' }) }
function fmtTimeRange(iso, durMin) {
  const s = new Date(iso), e = new Date(s.getTime() + durMin * 60000)
  return `${fmtTime(s)} – ${fmtTime(e)}`
}
function fmtCardDate(iso) {
  const d = new Date(iso)
  const days = ['Dom','Seg','Ter','Qua','Qui','Sex','Sáb']
  return `${days[d.getDay()]} ${String(d.getDate()).padStart(2,'0')}, ${d.getFullYear()}`
}
function statusColor(appt) {
  return STATUS_CFG[appt.status]?.color || STATUS_CFG.scheduled.color
}
function badgeStyle(appt) {
  const c = statusColor(appt)
  return { background: `${c}22`, color: c, border: `1px solid ${c}44` }
}
function hexToRgba(hex, alpha) {
  const h = hex.replace('#','')
  const r = parseInt(h.slice(0,2), 16)
  const g = parseInt(h.slice(2,4), 16)
  const b = parseInt(h.slice(4,6), 16)
  return `rgba(${r},${g},${b},${alpha})`
}
function cardBg(appt)     { return hexToRgba(statusColor(appt), 0.13) }
function cardBorder(appt) { return hexToRgba(statusColor(appt), 0.45) }
function fmtPrice(v) {
  if (!v && v !== 0) return null
  return `R$ ${Number(v).toFixed(2).replace('.', ',').replace(/\B(?=(\d{3})+(?!\d))/g, '.')}`
}
function isoDateStr(iso) { return localDateStr(new Date(iso)) }
function minutesFromIso(iso) { const d = new Date(iso); return d.getHours()*60 + d.getMinutes() }
function toTop(iso) { return ((minutesFromIso(iso) - START_MIN) / 10) * SLOT_H }
function toHeight(durMin) { return Math.max(durMin / 10 * SLOT_H, SLOT_H) }
function slotLabel(idx) { const m = START_MIN + idx*10; return m % 60 === 0 ? `${String(m/60).padStart(2,'0')}:00` : null }

// ── state ─────────────────────────────────────────────────────────────────────
const selectedDate = ref(todayStr())
const isToday      = computed(() => selectedDate.value === todayStr())
const nowMinutes   = ref(new Date().getHours()*60 + new Date().getMinutes())
const dragId       = ref(null)
const gridRef      = ref(null)
const newlyCreatedId = ref(null)  // highlights the card just saved

// ── filters ───────────────────────────────────────────────────────────────────
const filterStatus    = ref('all')
const filterProfId    = ref(null)
const filterServiceId = ref(null)
const filterLocType   = ref('all')

const showStatusMenu  = ref(false)
const showProfMenu    = ref(false)
const showServiceMenu = ref(false)
const showLocMenu     = ref(false)
const showBranchMenu  = ref(false)

const hasActiveFilters = computed(() =>
  filterStatus.value !== 'all' || filterProfId.value !== null ||
  filterServiceId.value !== null || filterLocType.value !== 'all'
)
const hasAnyFilter = computed(() => hasActiveFilters.value || activeBranchId.value !== null)

function clearFilters() {
  filterStatus.value = 'all'; filterProfId.value = null
  filterServiceId.value = null; filterLocType.value = 'all'
  activeBranchId.value = null
}
function closeAllMenus() {
  showStatusMenu.value = false; showProfMenu.value = false
  showServiceMenu.value = false; showLocMenu.value = false
  showBranchMenu.value = false
}

// active filter labels
const activeStatusLabel  = computed(() => filterStatus.value === 'all' ? 'Status' : STATUS_CFG[filterStatus.value]?.label || filterStatus.value)
const activeProfLabel    = computed(() => filterProfId.value === null ? 'Profissional' : (profCols.value.find(c => c.profId === filterProfId.value)?.name || 'Profissional'))
const activeServiceLabel = computed(() => {
  if (filterServiceId.value === null) return 'Serviço'
  const prods = store.getters['products/getList'] ?? []
  return prods.find(p => p.id === filterServiceId.value)?.name || 'Serviço'
})
const activeLocLabel    = computed(() => filterLocType.value === 'all' ? 'Local' : LOC_LABELS[filterLocType.value] || filterLocType.value)
const activeBranchLabel = computed(() => {
  if (!activeBranchId.value) return 'Filial'
  return branches.value.find(b => b.id === activeBranchId.value)?.name || 'Filial'
})

let _nowInterval = null
onMounted(() => { _nowInterval = setInterval(() => { nowMinutes.value = new Date().getHours()*60 + new Date().getMinutes() }, 30000) })
onUnmounted(() => clearInterval(_nowInterval))

const nowTop = computed(() => ((nowMinutes.value - START_MIN) / 10) * SLOT_H)

// ── availability (schedules, breaks, blocked dates, holidays per professional) ─
const availability    = ref({})   // { [profId]: { is_blocked, is_holiday, is_working_day, start_time, end_time, breaks, blocked_slots } }
const branchSchedule  = ref(null) // { active, start_time, end_time }

async function fetchAvailability() {
  const ids = visibleProfs.value.map(p => p.id)
  if (!ids.length) { availability.value = {}; return }
  try {
    const { data } = await availabilityAPI.get(selectedDate.value, ids, activeBranchId.value || null)
    // Normalize keys to numbers so profAvail(numericId) works
    const profs = data.professionals || {}
    availability.value = Object.fromEntries(Object.entries(profs).map(([k, v]) => [Number(k), v]))
    branchSchedule.value = data.branch_schedule || null
  } catch { availability.value = {} }
}

function profAvail(profId) {
  return availability.value[profId] ?? {
    is_blocked: false, is_holiday: false, is_working_day: true,
    start_time: '07:00', end_time: '22:00', breaks: [], blocked_slots: [],
  }
}

function timeToSlot(time) {
  if (!time || typeof time !== 'string') return 0
  const parts = time.split(':')
  const h = Number(parts[0]), m = Number(parts[1] || 0)
  if (isNaN(h) || isNaN(m)) return 0
  return ((h * 60 + m) - START_MIN) / 10
}

// ── loading overlay ───────────────────────────────────────────────────────────
const showLoadingOverlay = ref(true)
let _loadStart = Date.now()
let _hideTimer = null
watch(() => uiFlags.value.isFetching, fetching => {
  if (fetching) {
    clearTimeout(_hideTimer)
    _loadStart = Date.now()
    showLoadingOverlay.value = true
  } else {
    const elapsed = Date.now() - _loadStart
    const wait = Math.max(0, 300 - elapsed)
    _hideTimer = setTimeout(() => { showLoadingOverlay.value = false }, wait)
  }
}, { immediate: true })

// ── fetch ─────────────────────────────────────────────────────────────────────
watch(selectedDate, fetchDay, { immediate: true })
watch([visibleProfs, selectedDate], fetchAvailability, { immediate: true })

function fetchDay() {
  const [y, m, d] = selectedDate.value.split('-').map(Number)
  const from = new Date(y, m-1, d).toISOString()
  const to   = new Date(y, m-1, d, 23, 59, 59).toISOString()
  store.dispatch('appointments/fetchAppointments', { from, to })
    .catch(e => console.error('[agenda] fetchAppointments:', e))
}

onMounted(async () => {
  try {
    await Promise.all([
      store.dispatch('appointments/fetchServices').catch(e => console.error('[agenda] fetchServices:', e)),
      store.dispatch('agents/get').catch(e => console.error('[agenda] agents/get:', e)),
      store.dispatch('contacts/get', { page: 1 }).catch(e => console.error('[agenda] contacts/get:', e)),
      store.dispatch('professionals/fetchProfessionals').catch(e => console.error('[agenda] fetchProfessionals:', e)),
      store.dispatch('professionals/fetchBranches').catch(e => console.error('[agenda] fetchBranches:', e)),
      store.dispatch('products/fetchList').catch(e => console.error('[agenda] products/fetchList:', e)),
    ])
  } catch(e) { console.error('[agenda] onMounted error:', e) }
})

// Scroll to current time on load
watch([() => uiFlags.value.isFetching, isToday], ([loading]) => {
  if (!loading && isToday.value && gridRef.value) {
    setTimeout(() => { if (gridRef.value) gridRef.value.scrollTop = Math.max(0, nowTop.value - 80) }, 50)
  }
})

// ── computed ──────────────────────────────────────────────────────────────────
const dayAppts = computed(() =>
  allAppts.value.filter(a => isoDateStr(a.scheduled_at) === selectedDate.value)
    .sort((a,b) => new Date(a.scheduled_at) - new Date(b.scheduled_at))
)

const filteredAppts = computed(() => {
  let list = dayAppts.value
  if (filterStatus.value !== 'all')    list = list.filter(a => a.status === filterStatus.value)
  if (filterProfId.value !== null)     list = list.filter(a => a.professional?.id === filterProfId.value)
  if (filterServiceId.value !== null)  list = list.filter(a => a.services?.some(s => s.id === filterServiceId.value))
  if (filterLocType.value !== 'all')   list = list.filter(a => a.location_type === filterLocType.value)
  return list
})

const apptsByProf = computed(() => {
  const map = {}
  for (const a of filteredAppts.value) {
    const pid = a.professional?.id ?? 'none'
    if (!map[pid]) map[pid] = []
    map[pid].push(a)
  }
  return map
})
const apptsByAgent = apptsByProf

const statusCount = computed(() => {
  const c = { scheduled: 0, in_progress: 0, completed: 0, cancelled: 0 }
  for (const a of filteredAppts.value) if (c[a.status] != null) c[a.status]++
  return c
})

const statusSummary = computed(() =>
  Object.entries(STATUS_CFG)
    .map(([s, cfg]) => ({ status: s, ...cfg, count: statusCount.value[s] || 0 }))
    .filter(s => s.count > 0)
)

const upcomingAppts = computed(() => {
  const now = new Date()
  return filteredAppts.value.filter(a => new Date(a.scheduled_at) >= now).slice(0, 5)
})

function profColor(idx) {
  const col = profCols.value[idx];
  return col?.color || getBrandColor();
}
function profColorById(profId) {
  const col = profCols.value.find(c => c.profId === profId);
  return col?.color || getBrandColor();
}
function agentLetters(name) { return (name||'?').split(' ').slice(0,2).map(w=>w[0]).join('').toUpperCase() }
function apptDur(appt) {
  // services array comes from the appointments serializer with duration_minutes already in minutes
  const dur = appt.services?.reduce((s, sv) => s + (sv.duration_minutes || 0), 0) || 0
  if (dur) return dur
  // fall back to end_time - scheduled_at
  if (appt.end_time && appt.scheduled_at) {
    return Math.max(10, Math.round((new Date(appt.end_time) - new Date(appt.scheduled_at)) / 60000))
  }
  return 30
}

// ── week pills ────────────────────────────────────────────────────────────────
const weekPills = computed(() =>
  Array.from({ length: 7 }, (_, i) => {
    const d   = addDays(todayStr(), i-3)
    const [y,m,dd] = d.split('-').map(Number)
    const dt  = new Date(y, m-1, dd)
    const dow = dt.toLocaleDateString('pt-BR', { weekday: 'short' }).replace('.','')
    return { date: d, dow, num: dt.getDate(), isToday: d === todayStr(), isSel: d === selectedDate.value }
  })
)

// ── mini calendar ─────────────────────────────────────────────────────────────
const calView = ref((() => { const [y,m] = selectedDate.value.split('-').map(Number); return { year: y, month: m-1 } })())
watch(selectedDate, () => { const [y,m] = selectedDate.value.split('-').map(Number); calView.value = { year: y, month: m-1 } })

const calMonthName = computed(() =>
  new Date(calView.value.year, calView.value.month, 1).toLocaleDateString('pt-BR', { month: 'long', year: 'numeric' })
)
const calCells = computed(() => {
  const { year: y, month: m } = calView.value
  const firstDay = new Date(y, m, 1).getDay()
  const daysInMonth = new Date(y, m+1, 0).getDate()
  const cells = []
  for (let i=0; i<firstDay; i++) cells.push(null)
  for (let d=1; d<=daysInMonth; d++) cells.push(d)
  return cells
})
function calDayStr(day) {
  const { year: y, month: m } = calView.value
  return `${y}-${String(m+1).padStart(2,'0')}-${String(day).padStart(2,'0')}`
}
function prevCalMonth() {
  const { year: y, month: m } = calView.value
  calView.value = m===0 ? { year: y-1, month: 11 } : { year: y, month: m-1 }
}
function nextCalMonth() {
  const { year: y, month: m } = calView.value
  calView.value = m===11 ? { year: y+1, month: 0 } : { year: y, month: m+1 }
}

// ── drag & drop ───────────────────────────────────────────────────────────────
function onCardDragStart(e, appt) {
  e.dataTransfer.effectAllowed = 'move'
  _grabOffsetY = e.clientY - e.currentTarget.getBoundingClientRect().top
  dragId.value = appt.id
}
function onColDragOver(e) { e.preventDefault() }
function onColDrop(e, agentId) {
  if (!dragId.value) return
  if (profAvail(agentId).is_blocked) { dragId.value = null; return }
  const rawY = e.clientY - e.currentTarget.getBoundingClientRect().top - _grabOffsetY
  const slot = Math.max(0, Math.min(TOTAL_SLOTS-1, Math.round(rawY / SLOT_H)))
  const newMin = START_MIN + slot*10
  moveAppt(dragId.value, agentId, newMin)
  dragId.value = null
}
async function moveAppt(apptId, newAgentId, newMinutes) {
  const appt = dayAppts.value.find(a => a.id === apptId)
  if (!appt) return
  const d = new Date(appt.scheduled_at)
  d.setHours(Math.floor(newMinutes/60), newMinutes%60, 0, 0)
  const newScheduledAt = d.toISOString()
  const sameAgent = (appt.professional?.id ?? null) === newAgentId
  const sameTime  = newScheduledAt === new Date(appt.scheduled_at).toISOString()
  if (sameAgent && sameTime) return
  try {
    await store.dispatch('appointments/updateAppointment', {
      id: apptId,
      professional_id: newAgentId,
      scheduled_at: newScheduledAt,
      status: appt.status,
      notes: appt.notes,
      contact_id: appt.contact?.id,
      service_ids: appt.services?.map(s=>s.id).filter(Boolean) || [],
      appointment_type: appt.appointment_type,
      location_type: appt.location_type,
    })
    fetchDay()
  } catch { useAlert('Erro ao mover agendamento.') }
}

// ── slot click → open create modal ───────────────────────────────────────────
function onSlotClick(agentId, slotIdx) {
  const totalMin = START_MIN + slotIdx*10
  const h = Math.floor(totalMin/60), m = totalMin%60
  const padH = n => String(n).padStart(2,'0')
  openCreate(agentId, `${padH(h)}:${padH(m)}`, `${padH(h+1)}:${padH(m)}`)
}

// ── modal ─────────────────────────────────────────────────────────────────────
const showModal  = ref(false)
const editTarget = ref(null)
const form       = ref(blankForm())

function blankForm(agentId='', start='09:00', end='10:00') {
  return {
    title: '', appointment_type: 'service', status: 'scheduled',
    professional_id: agentId ?? '', contact_id: '', service_ids: [],
    date: selectedDate.value, start_time: start, end_time: end,
    location_type: 'in_person', notes: '',
  }
}
function openCreate(agentId='', start='09:00', end='10:00') {
  editTarget.value = null
  form.value = blankForm(agentId, start, end)
  store.commit('appointments/SET_UI', { isSaving: false })
  showModal.value = true
}
function openEdit(appt) {
  editTarget.value = appt
  const s = new Date(appt.scheduled_at), e = appt.end_time ? new Date(appt.end_time) : null
  form.value = {
    title: appt.title||'', appointment_type: appt.appointment_type||'service',
    status: appt.status||'scheduled', professional_id: appt.professional?.id??'',
    contact_id: appt.contact?.id??'', service_ids: (appt.services||[]).map(sv=>sv.id),
    date: localDateStr(s), start_time: s.toTimeString().slice(0,5),
    end_time: e ? e.toTimeString().slice(0,5) : '', location_type: appt.location_type||'in_person',
    notes: appt.notes||'',
  }
  store.commit('appointments/SET_UI', { isSaving: false })
  showModal.value = true
}
function closeModal() {
  showModal.value = false
  editTarget.value = null
  store.commit('appointments/SET_UI', { isSaving: false })
}

const STATUS_CYCLE = ['scheduled', 'in_progress', 'completed', 'cancelled']
async function quickCycleStatus(appt) {
  const idx  = STATUS_CYCLE.indexOf(appt.status)
  const next = STATUS_CYCLE[(idx + 1) % STATUS_CYCLE.length]
  try {
    await store.dispatch('appointments/updateAppointment', { id: appt.id, status: next })
    fetchDay()
  } catch { useAlert('Erro ao atualizar status.') }
}

function goToContact(appt) {
  if (!appt.contact?.id) return
  router.push({ name: 'contacts_edit', params: { accountId: accountId.value, contactId: appt.contact.id } })
}

async function saveAppointment() {
  if (!form.value.date) { useAlert('Informe a data.'); return }
  const startT = form.value.start_time || '09:00'
  const toISO  = (d, t) => new Date(`${d}T${t}:00`).toISOString()
  const p = {
    title: form.value.title.trim()||null,
    appointment_type: form.value.appointment_type,
    status: form.value.status,
    professional_id: form.value.professional_id||null,
    contact_id: form.value.contact_id||null,
    service_ids: form.value.service_ids,
    scheduled_at: toISO(form.value.date, startT),
    end_time: form.value.end_time ? toISO(form.value.date, form.value.end_time) : null,
    location_type: form.value.location_type,
    notes: form.value.notes.trim()||null,
  }
  try {
    if (editTarget.value) {
      await store.dispatch('appointments/updateAppointment', { id: editTarget.value.id, ...p })
      useAlert('Salvo!')
    } else {
      const created = await store.dispatch('appointments/createAppointment', p)
      newlyCreatedId.value = created?.id ?? null
      useAlert('Agendamento criado!')
    }
    const savedDate  = form.value.date
    const savedStart = form.value.start_time || '09:00'
    closeModal()
    if (savedDate !== selectedDate.value) {
      selectedDate.value = savedDate
    } else {
      fetchDay()
    }
    nextTick(() => {
      const [h, m] = savedStart.split(':').map(Number)
      const scrollTop = Math.max(0, ((h * 60 + m - START_MIN) / 10) * SLOT_H - 80)
      if (gridRef.value) gridRef.value.scrollTop = scrollTop
      setTimeout(() => { newlyCreatedId.value = null }, 1500)
    })
  } catch(e) {
    console.error('[agenda] saveAppointment error:', e)
    useAlert('Erro ao salvar. Tente novamente.')
  }
}

// ── payment registration ──────────────────────────────────────────────────────
const selectedPaymentMethod = ref('');
const savingPayment = ref(false);

const PAYMENT_METHODS = [
  { key: 'dinheiro', label: 'Dinheiro' },
  { key: 'pix',      label: 'Pix' },
  { key: 'debito',   label: 'Débito' },
  { key: 'credito',  label: 'Crédito' },
];

async function registerPayment() {
  if (!selectedPaymentMethod.value) { useAlert('Selecione a forma de pagamento.'); return; }
  const appt = editTarget.value;
  if (!appt) return;
  savingPayment.value = true;
  try {
    const totalPrice = appt.total_price || appt.services?.reduce((s,sv)=>s+(parseFloat(sv.price)||0),0) || 0;
    await store.dispatch('cashTransactions/createTransaction', {
      transaction_type: 'income',
      payment_method:   selectedPaymentMethod.value,
      description:      appt.contact?.name ? `Atendimento – ${appt.contact.name}` : 'Atendimento',
      amount:           totalPrice,
      category:         'servico',
      date:             new Date(appt.scheduled_at).toISOString(),
      appointment_id:   appt.id,
      professional_id:  appt.professional?.id ?? null,
      branch_id:        appt.branch_id ?? null,
    });
    // refresh so editTarget.payment shows up
    await store.dispatch('appointments/fetchAppointments', { from: appt.scheduled_at, to: appt.scheduled_at });
    fetchDay();
    useAlert('Pagamento registrado!');
    selectedPaymentMethod.value = '';
    closeModal();
  } catch(e) {
    console.error('[agenda] registerPayment error:', e);
    useAlert('Erro ao registrar pagamento.');
  } finally {
    savingPayment.value = false;
  }
}

// duracao is stored in seconds in DB; duration_minutes (from serializer) is already in minutes
function prodDurMin(p) {
  if (p.duration_minutes != null) return p.duration_minutes       // from appointments serializer (already minutes)
  const raw = p.duracao || 0
  return raw > 480 ? Math.round(raw / 60) : raw                   // products list: seconds if > 480
}
function toggleService(id) {
  const i = form.value.service_ids.indexOf(id)
  i >= 0 ? form.value.service_ids.splice(i, 1) : form.value.service_ids.push(id)
  // auto-update end_time based on total selected duration
  if (form.value.start_time) {
    const totalMin = formProducts.value
      .filter(p => form.value.service_ids.includes(p.id))
      .reduce((s, p) => s + (prodDurMin(p) || 30), 0)
    if (totalMin > 0) {
      const [h, m] = form.value.start_time.split(':').map(Number)
      const endMin = Math.min(h * 60 + m + totalMin, END_MIN)
      form.value.end_time = `${String(Math.floor(endMin/60)).padStart(2,'0')}:${String(endMin%60).padStart(2,'0')}`
    }
  }
}

// delete
const deleteTarget = ref(null)
async function confirmDelete() {
  try { await store.dispatch('appointments/deleteAppointment', deleteTarget.value.id); useAlert('Removido.'); fetchDay() }
  catch { useAlert('Erro.') }
  deleteTarget.value = null
}

// hover card state
const hoveredCard = ref(null)

// reminder settings modal
const showReminderSettings = ref(false)

// retention settings modal
const showRetentionSettings = ref(false)

// products for appointment form (use products store, fallback to services)
const formProducts = computed(() => {
  const prods = store.getters['products/getList'] ?? [];
  if (prods.length) return prods.filter(p => p.active !== false);
  return services.value;
})
</script>

<template>
  <div class="ag-page" @click="closeAllMenus">

    <!-- ══ TOP BAR ════════════════════════════════════════════════════════════ -->
    <header class="ag-topbar" @click.stop="closeAllMenus">
      <!-- Date + count -->
      <div class="ag-topbar-title">
        <h2 class="ag-date-title">{{ fmtDateLong(selectedDate) }}</h2>
        <p v-if="!uiFlags.isFetching" class="ag-date-sub">
          {{ filteredAppts.length }} agendamento{{ filteredAppts.length !== 1 ? 's' : '' }}<template v-if="hasAnyFilter"> · filtrado</template>
          <template v-if="statusCount.scheduled > 0"> · {{ statusCount.scheduled }} pendente{{ statusCount.scheduled !== 1 ? 's' : '' }}</template>
        </p>
      </div>

      <!-- Nav arrows -->
      <div class="ag-nav-group">
        <button class="ag-nav-btn" @click.stop="selectedDate = addDays(selectedDate, -1)">
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M15 18l-6-6 6-6"/></svg>
        </button>
        <button v-if="!isToday" class="ag-nav-btn ag-nav-hoje" @click.stop="selectedDate = todayStr()">Hoje</button>
        <button class="ag-nav-btn" @click.stop="selectedDate = addDays(selectedDate, 1)">
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M9 18l6-6-6-6"/></svg>
        </button>
      </div>

      <!-- ── Filtros inline na topbar ── -->
      <div class="ag-topbar-filters" @click.stop>

        <!-- Filial (só se tiver mais de uma) -->
        <div v-if="branches.length > 0" class="ag-fb-item">
          <button
            class="ag-fb-btn"
            :class="{ 'ag-fb-btn--active': activeBranchId !== null }"
            @click.stop="showBranchMenu = !showBranchMenu; showStatusMenu = showProfMenu = showServiceMenu = showLocMenu = false"
          >
            <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/></svg>
            {{ activeBranchLabel }}
            <svg width="8" height="8" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M6 9l6 6 6-6"/></svg>
          </button>
          <div v-if="showBranchMenu" class="ag-fb-menu">
            <button class="ag-fb-opt" :class="{ 'ag-fb-opt--active': activeBranchId === null }" @click.stop="activeBranchId = null; showBranchMenu = false">
              Todas as filiais
              <svg v-if="activeBranchId === null" class="ag-fb-check" width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg>
            </button>
            <button
              v-for="b in branches" :key="b.id"
              class="ag-fb-opt"
              :class="{ 'ag-fb-opt--active': activeBranchId === b.id }"
              @click.stop="activeBranchId = b.id; showBranchMenu = false"
            >
              {{ b.name }}
              <svg v-if="activeBranchId === b.id" class="ag-fb-check" width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg>
            </button>
          </div>
        </div>

        <!-- Status -->
        <div class="ag-fb-item">
          <button
            class="ag-fb-btn"
            :class="{ 'ag-fb-btn--active': filterStatus !== 'all' }"
            @click.stop="showStatusMenu = !showStatusMenu; showBranchMenu = showProfMenu = showServiceMenu = showLocMenu = false"
          >
            <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="4"/></svg>
            {{ activeStatusLabel }}
            <svg width="8" height="8" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M6 9l6 6 6-6"/></svg>
          </button>
          <div v-if="showStatusMenu" class="ag-fb-menu">
            <button class="ag-fb-opt" :class="{ 'ag-fb-opt--active': filterStatus === 'all' }" @click.stop="filterStatus = 'all'; showStatusMenu = false">
              Todos
              <svg v-if="filterStatus === 'all'" class="ag-fb-check" width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg>
            </button>
            <button
              v-for="[k, cfg] in Object.entries(STATUS_CFG)" :key="k"
              class="ag-fb-opt"
              :class="{ 'ag-fb-opt--active': filterStatus === k }"
              @click.stop="filterStatus = k; showStatusMenu = false"
            >
              <span class="ag-fb-dot" :style="{ background: cfg.dot }" />
              {{ cfg.label }}
              <svg v-if="filterStatus === k" class="ag-fb-check" width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg>
            </button>
          </div>
        </div>

        <!-- Profissional -->
        <div class="ag-fb-item">
          <button
            class="ag-fb-btn"
            :class="{ 'ag-fb-btn--active': filterProfId !== null }"
            @click.stop="showProfMenu = !showProfMenu; showBranchMenu = showStatusMenu = showServiceMenu = showLocMenu = false"
          >
            <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
            {{ activeProfLabel }}
            <svg width="8" height="8" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M6 9l6 6 6-6"/></svg>
          </button>
          <div v-if="showProfMenu" class="ag-fb-menu">
            <button class="ag-fb-opt" :class="{ 'ag-fb-opt--active': filterProfId === null }" @click.stop="filterProfId = null; showProfMenu = false">
              Todos
              <svg v-if="filterProfId === null" class="ag-fb-check" width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg>
            </button>
            <button
              v-for="col in profCols" :key="col.profId"
              class="ag-fb-opt"
              :class="{ 'ag-fb-opt--active': filterProfId === col.profId }"
              @click.stop="filterProfId = col.profId; showProfMenu = false"
            >
              <div class="ag-fb-av" :style="{ background: `${profColor(col.idx)}22`, color: profColor(col.idx), border: `1.5px solid ${profColor(col.idx)}` }">{{ agentLetters(col.name) }}</div>
              {{ col.name }}
              <svg v-if="filterProfId === col.profId" class="ag-fb-check" width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg>
            </button>
          </div>
        </div>

        <!-- Serviço -->
        <div v-if="formProducts.length" class="ag-fb-item">
          <button
            class="ag-fb-btn"
            :class="{ 'ag-fb-btn--active': filterServiceId !== null }"
            @click.stop="showServiceMenu = !showServiceMenu; showBranchMenu = showStatusMenu = showProfMenu = showLocMenu = false"
          >
            <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/></svg>
            {{ activeServiceLabel }}
            <svg width="8" height="8" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M6 9l6 6 6-6"/></svg>
          </button>
          <div v-if="showServiceMenu" class="ag-fb-menu ag-fb-menu--scroll">
            <button class="ag-fb-opt" :class="{ 'ag-fb-opt--active': filterServiceId === null }" @click.stop="filterServiceId = null; showServiceMenu = false">
              Todos
              <svg v-if="filterServiceId === null" class="ag-fb-check" width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg>
            </button>
            <button
              v-for="svc in formProducts" :key="svc.id"
              class="ag-fb-opt"
              :class="{ 'ag-fb-opt--active': filterServiceId === svc.id }"
              @click.stop="filterServiceId = svc.id; showServiceMenu = false"
            >
              {{ svc.name }}
              <span v-if="prodDurMin(svc)" style="font-size:9px;opacity:.55;margin-left:auto;padding-right:4px">{{ prodDurMin(svc) }}min</span>
              <svg v-if="filterServiceId === svc.id" class="ag-fb-check" width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg>
            </button>
          </div>
        </div>

        <!-- Local -->
        <div class="ag-fb-item">
          <button
            class="ag-fb-btn"
            :class="{ 'ag-fb-btn--active': filterLocType !== 'all' }"
            @click.stop="showLocMenu = !showLocMenu; showBranchMenu = showStatusMenu = showProfMenu = showServiceMenu = false"
          >
            <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>
            {{ activeLocLabel }}
            <svg width="8" height="8" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M6 9l6 6 6-6"/></svg>
          </button>
          <div v-if="showLocMenu" class="ag-fb-menu">
            <button class="ag-fb-opt" :class="{ 'ag-fb-opt--active': filterLocType === 'all' }" @click.stop="filterLocType = 'all'; showLocMenu = false">
              Todos
              <svg v-if="filterLocType === 'all'" class="ag-fb-check" width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg>
            </button>
            <button v-for="[k, label] in Object.entries(LOC_LABELS)" :key="k" class="ag-fb-opt" :class="{ 'ag-fb-opt--active': filterLocType === k }" @click.stop="filterLocType = k; showLocMenu = false">
              {{ label }}
              <svg v-if="filterLocType === k" class="ag-fb-check" width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg>
            </button>
          </div>
        </div>

        <!-- Limpar filtros -->
        <button v-if="hasAnyFilter" class="ag-fb-clear ag-fb-clear--inline" @click.stop="clearFilters">
          <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M18 6L6 18M6 6l12 12"/></svg>
          Limpar
        </button>
      </div>

      <!-- Retenção button -->
      <button class="ag-reminder-btn" @click.stop="showRetentionSettings = true" title="Configurar retenção / fidelização">
        <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="flex-shrink:0"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/></svg>
      </button>

      <!-- Lembretes button -->
      <button class="ag-reminder-btn" @click.stop="showReminderSettings = true" title="Configurar lembretes automáticos">
        <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="flex-shrink:0"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/></svg>
      </button>

      <!-- New button -->
      <button class="ag-new-btn" @click.stop="openCreate()">
        <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" style="flex-shrink:0"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
        Novo
      </button>
    </header>

    <!-- Reminder settings modal -->
    <ReminderSettings v-if="showReminderSettings" @close="showReminderSettings = false" />

    <!-- Retention settings modal -->
    <RetentionSettings v-if="showRetentionSettings" @close="showRetentionSettings = false" />

    <!-- ══ BODY ═══════════════════════════════════════════════════════════════ -->
    <div class="ag-body">

      <!-- ── LEFT SIDEBAR ─────────────────────────────────────────────────── -->
      <aside class="ag-sidebar">

        <!-- Mini calendar -->
        <div class="ag-mini-cal">
          <div class="ag-mc-header">
            <button class="ag-mc-nav" @click="prevCalMonth">‹</button>
            <span class="ag-mc-month">{{ calMonthName }}</span>
            <button class="ag-mc-nav" @click="nextCalMonth">›</button>
          </div>
          <div class="ag-mc-dow-row">
            <div v-for="l in ['D','S','T','Q','Q','S','S']" :key="l" class="ag-mc-dow">{{ l }}</div>
          </div>
          <div class="ag-mc-grid">
            <template v-for="(day, i) in calCells" :key="i">
              <div v-if="!day" class="ag-mc-empty" />
              <button
                v-else
                class="ag-mc-day"
                :class="{
                  'ag-mc-day--sel': calDayStr(day) === selectedDate,
                  'ag-mc-day--today': calDayStr(day) === todayStr() && calDayStr(day) !== selectedDate,
                }"
                @click="selectedDate = calDayStr(day)"
              >{{ day }}</button>
            </template>
          </div>
        </div>

        <div class="ag-sidebar-divider" />

        <!-- Status summary -->
        <div v-if="statusSummary.length" class="ag-sidebar-section">
          <p class="ag-section-label">Resumo do dia</p>
          <div class="ag-status-list">
            <div
              v-for="s in statusSummary" :key="s.status"
              class="ag-status-row"
              :style="{ background: s.bg, border: `1px solid ${s.dot}22` }"
            >
              <div style="display:flex;align-items:center;gap:6px">
                <div class="ag-status-dot" :style="{ background: s.dot }" />
                <span class="ag-status-label">{{ s.label }}</span>
              </div>
              <span class="ag-status-count" :style="{ color: s.color }">{{ s.count }}</span>
            </div>
          </div>
        </div>

        <!-- Upcoming -->
        <div v-if="upcomingAppts.length" class="ag-sidebar-section">
          <p class="ag-section-label">Próximos</p>
          <div class="ag-upcoming-list">
            <div
              v-for="a in upcomingAppts" :key="a.id"
              class="ag-upcoming-card"
              :style="{ borderLeft: `3px solid ${profColorById(a.professional?.id)}` }"
              @click="openEdit(a)"
            >
              <div class="ag-up-time" :style="{ color: STATUS_CFG[a.status]?.color || '#FBD44A' }">
                {{ fmtTime(a.scheduled_at) }}
              </div>
              <div class="ag-up-name">{{ a.contact?.name || a.title || 'Agendamento' }}</div>
              <div class="ag-up-sub">
                {{ a.services?.map(s=>s.name).join(' + ') || TYPE_LABELS[a.appointment_type] || '' }}
                <template v-if="a.professional?.name"> · {{ a.professional.name }}</template>
              </div>
            </div>
          </div>
        </div>

        <!-- Empty -->
        <div v-if="!uiFlags.isFetching && dayAppts.length === 0" class="ag-sidebar-empty">
          <span class="i-lucide-calendar-days" style="font-size:30px;opacity:.25;color:#94a3b8" />
          <p style="font-size:12px;font-weight:600;color:#94a3b8;margin:0">Sem agendamentos</p>
          <p style="font-size:11px;color:#475569;margin:0">Nenhum para este dia.</p>
        </div>
      </aside>

      <!-- ── EMPTY STATE: no professionals in this branch ──────────────────── -->
      <div v-if="profCols.length === 0" class="ag-no-prof-wrap">
        <!-- faint horizontal lines suggesting a calendar grid -->
        <div class="ag-no-prof-bg-lines">
          <div v-for="n in 14" :key="n" class="ag-no-prof-bg-line" />
        </div>
        <div class="ag-no-prof-box">
          <div class="ag-no-prof-icon-wrap">
            <!-- calendar with clock: inline SVG to avoid icon availability issues -->
            <svg width="30" height="30" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
              <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/>
              <line x1="16" y1="2" x2="16" y2="6"/>
              <line x1="8" y1="2" x2="8" y2="6"/>
              <line x1="3" y1="10" x2="21" y2="10"/>
              <line x1="12" y1="14" x2="12" y2="17"/>
              <line x1="10.5" y1="17" x2="13.5" y2="17"/>
            </svg>
          </div>
          <div class="ag-no-prof-text">
            <p class="ag-no-prof-title">Nenhum profissional ativo</p>
            <p class="ag-no-prof-sub">Adicione profissionais para que eles apareçam na agenda e possam receber agendamentos.</p>
          </div>
          <div class="ag-no-prof-actions">
            <a href="../settings/professionals" class="ag-no-prof-btn">
              <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M4.22 4.22l2.12 2.12M17.66 17.66l2.12 2.12M2 12h3M19 12h3M4.22 19.78l2.12-2.12M17.66 6.34l2.12-2.12"/></svg>
              Gerenciar Profissionais
            </a>
            <a href="../settings/agents" class="ag-no-prof-btn-sec">
              <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><line x1="19" y1="8" x2="19" y2="14"/><line x1="22" y1="11" x2="16" y2="11"/></svg>
              Adicionar Agente
            </a>
          </div>
        </div>
      </div>

      <!-- ── CALENDAR GRID ─────────────────────────────────────────────────── -->
      <div v-else ref="gridRef" class="ag-grid-wrap" style="position:relative" @dragend="dragId = null">

        <!-- Loading spinner -->
        <Transition name="ag-fade">
          <div v-if="showLoadingOverlay" style="position:absolute;inset:0;z-index:30;display:flex;align-items:center;justify-content:center;background:rgb(var(--background-color));">
            <Spinner class="text-n-brand" :size="28" />
          </div>
        </Transition>

          <!-- Professional headers (sticky top) -->
          <div class="ag-prof-headers">
            <div class="ag-gutter-corner" />
            <div
              v-for="col in profCols" :key="col.profId"
              class="ag-prof-head"
              :style="{ borderTop: `3px solid ${profColor(col.idx)}` }"
            >
              <div
                class="ag-prof-av"
                :style="{ background: `${profColor(col.idx)}1a`, border: `2px solid ${profColor(col.idx)}`, color: profColor(col.idx) }"
              >
                <img v-if="col.thumbnail" :src="col.thumbnail" style="width:100%;height:100%;object-fit:cover;border-radius:50%" />
                <template v-else>{{ agentLetters(col.name) }}</template>
              </div>
              <div class="ag-prof-info">
                <div class="ag-prof-name">{{ col.name }}</div>
                <div class="ag-prof-role" :style="{ color: profColor(col.idx) }">{{ col.specialty || 'Profissional' }}</div>
              </div>
              <span
                v-if="(apptsByProf[col.profId]||[]).length"
                class="ag-prof-badge"
                :style="{ background: `${profColor(col.idx)}1a`, border: `1px solid ${profColor(col.idx)}40`, color: profColor(col.idx) }"
              >{{ (apptsByProf[col.profId]||[]).length }}</span>
            </div>
          </div>

          <!-- Grid body -->
          <div class="ag-grid-body">

            <!-- Time column (sticky left) -->
            <div class="ag-time-col">
              <div
                v-for="(_, i) in SLOTS_ARR" :key="i"
                class="ag-time-slot"
                :style="{ height: `${SLOT_H}px`, borderBottomColor: slotLabel(i) ? 'var(--ag-line)' : 'var(--ag-line-soft)' }"
              >
                <span v-if="slotLabel(i)" class="ag-time-label">{{ slotLabel(i) }}</span>
              </div>
            </div>

            <!-- Professional columns -->
            <div
              v-for="col in profCols" :key="col.profId"
              class="ag-col"
              :style="{ height: `${TOTAL_SLOTS * SLOT_H}px` }"
              @dragover.prevent="onColDragOver"
              @drop="onColDrop($event, col.profId)"
            >
              <!-- Slot cells -->
              <div
                v-for="(_, i) in SLOTS_ARR" :key="i"
                class="ag-slot"
                :style="{
                  height: `${SLOT_H}px`,
                  borderBottomColor: (START_MIN + i*10) % 60 === 0 ? 'var(--ag-line)' : (START_MIN + i*10) % 30 === 0 ? 'var(--ag-line-mid)' : 'var(--ag-line-soft)',
                }"
                @click="!profAvail(col.profId).is_blocked && onSlotClick(col.profId, i)"
                @mouseenter="e => !profAvail(col.profId).is_blocked && (e.currentTarget.style.background = `${profColor(col.idx)}09`)"
                @mouseleave="e => e.currentTarget.style.background = 'transparent'"
              />

              <!-- ── AVAILABILITY OVERLAYS ─────────────────────────────────────── -->
              <template v-if="availability[col.profId]">

                <!-- Full-day block: holiday or personal block -->
                <div
                  v-if="profAvail(col.profId).is_blocked"
                  :class="['ag-avail-full', profAvail(col.profId).is_holiday ? 'ag-avail-full--holiday' : 'ag-avail-full--blocked']"
                >
                  <div class="ag-avail-full-inner">
                    <span :class="profAvail(col.profId).is_holiday ? 'i-lucide-sun' : 'i-lucide-lock'" class="ag-avail-full-icon" />
                    <span class="ag-avail-full-label">
                      {{ profAvail(col.profId).is_holiday ? 'Feriado' : (profAvail(col.profId).blocked_reason || 'Indisponível') }}
                    </span>
                  </div>
                </div>

                <template v-else-if="profAvail(col.profId).is_working_day">
                  <!-- Before work hours -->
                  <div
                    v-if="timeToSlot(profAvail(col.profId).start_time) > 0"
                    class="ag-avail-hatch"
                    :style="{ top: 0, height: `${timeToSlot(profAvail(col.profId).start_time) * SLOT_H}px` }"
                  />
                  <!-- After work hours -->
                  <div
                    v-if="timeToSlot(profAvail(col.profId).end_time) < TOTAL_SLOTS"
                    class="ag-avail-hatch"
                    :style="{ top: `${timeToSlot(profAvail(col.profId).end_time) * SLOT_H}px`, bottom: 0, height: 'auto' }"
                  />
                  <!-- Breaks -->
                  <div
                    v-for="(brk, bi) in profAvail(col.profId).breaks" :key="`brk-${bi}`"
                    class="ag-avail-break"
                    :style="{
                      top:    `${timeToSlot(brk.start_time) * SLOT_H}px`,
                      height: `${(timeToSlot(brk.end_time) - timeToSlot(brk.start_time)) * SLOT_H}px`,
                    }"
                  >
                    <div class="ag-avail-break-pill">
                      <span class="i-lucide-coffee" style="font-size:9px" />
                      <span>{{ brk.label || 'Pausa' }} · {{ brk.start_time }}–{{ brk.end_time }}</span>
                    </div>
                  </div>
                  <!-- Specific blocked slots -->
                  <div
                    v-for="(bs, bsi) in profAvail(col.profId).blocked_slots" :key="`bs-${bsi}`"
                    class="ag-avail-slot-block"
                    :style="{
                      top:    `${timeToSlot(bs.start_time) * SLOT_H}px`,
                      height: `${(timeToSlot(bs.end_time) - timeToSlot(bs.start_time)) * SLOT_H}px`,
                    }"
                  >
                    <div class="ag-avail-block-pill">
                      <span class="i-lucide-lock" style="font-size:9px" />
                      <span>{{ bs.reason || 'Bloqueado' }} · {{ bs.start_time }}–{{ bs.end_time }}</span>
                    </div>
                  </div>
                </template>

                <!-- Non-working day (folga) -->
                <div v-else class="ag-avail-hatch ag-avail-hatch--full">
                  <div class="ag-avail-offday-label">
                    <span class="i-lucide-moon" style="font-size:12px;opacity:.4" />
                    <span>Folga</span>
                  </div>
                </div>
              </template>

              <!-- Appointment cards — kanban style -->
              <div
                v-for="appt in (apptsByProf[col.profId]||[])" :key="appt.id"
                class="ag-card"
                :class="{ 'ag-card--new': newlyCreatedId === appt.id, 'ag-card--hovered': hoveredCard === appt.id }"
                :style="{
                  top:        `${toTop(appt.scheduled_at) + 1}px`,
                  height:     `${toHeight(apptDur(appt)) - 2}px`,
                  background: cardBg(appt),
                  border:     `1px solid ${cardBorder(appt)}`,
                  borderLeft: `3px solid ${profColor(col.idx)}`,
                  opacity:    dragId === appt.id ? 0.3 : 1,
                  zIndex:     hoveredCard === appt.id ? 10 : 2,
                }"
                draggable="true"
                @dragstart="onCardDragStart($event, appt)"
                @mouseenter="hoveredCard = appt.id"
                @mouseleave="hoveredCard = null"
                @dblclick="openEdit(appt)"
              >
                <!-- ── Compact ≤20min: uma linha ── -->
                <template v-if="apptDur(appt) <= 20">
                  <div class="ag-bc">
                    <span class="ag-bt" :style="{ color: statusColor(appt) }">{{ fmtTimeRange(appt.scheduled_at, apptDur(appt)) }}</span>
                    <span class="ag-bn">{{ appt.contact?.name || appt.title || 'Agendamento' }}</span>
                  </div>
                </template>

                <!-- ── Normal >20min ── -->
                <template v-else>
                  <div class="ag-bt" :style="{ color: statusColor(appt) }">{{ fmtTimeRange(appt.scheduled_at, apptDur(appt)) }}</div>
                  <div class="ag-bn">{{ appt.contact?.name || appt.title || 'Agendamento' }}</div>
                  <div v-if="appt.services?.length" class="ag-bs">
                    {{ appt.services.map(s => s.name).join(' + ') }}
                  </div>
                  <div v-if="apptDur(appt) > 60 && (appt.contact?.phone_number || fmtPrice(appt.total_price))" class="ag-bm">
                    <span v-if="appt.contact?.phone_number">{{ appt.contact.phone_number }}</span>
                    <span v-if="fmtPrice(appt.total_price)" class="ag-bprice">{{ fmtPrice(appt.total_price) }}</span>
                  </div>
                  <!-- footer: agente -->
                  <div v-if="apptDur(appt) > 40" class="ag-bf">
                    <div
                      class="ag-bf-av"
                      :title="appt.professional?.name || 'Sem profissional'"
                      :style="appt.professional
                        ? { background: `${profColor(col.idx)}22`, color: profColor(col.idx), borderColor: `${profColor(col.idx)}55` }
                        : {}"
                    >
                      <template v-if="appt.professional">
                        <img v-if="appt.professional.thumbnail" :src="appt.professional.thumbnail" style="width:100%;height:100%;object-fit:cover;border-radius:50%" />
                        <template v-else>{{ agentLetters(appt.professional.name) }}</template>
                      </template>
                      <svg v-else width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
                    </div>
                    <span class="ag-bf-name">{{ appt.professional?.name || 'Sem profissional' }}</span>
                  </div>
                </template>

                <!-- ── Hover: botões de ação (absolutos, top-right) ── -->
                <div v-if="hoveredCard === appt.id" class="ag-hover-acts">
                  <button v-if="appt.contact?.id" class="ag-ha-btn" title="Abrir contato" @click.stop="goToContact(appt)">
                    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
                  </button>
                  <button class="ag-ha-btn" :title="`→ ${STATUS_CFG[STATUS_CYCLE[(STATUS_CYCLE.indexOf(appt.status)+1)%4]]?.label}`" @click.stop="quickCycleStatus(appt)">
                    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="17 1 21 5 17 9"/><path d="M3 11V9a4 4 0 0 1 4-4h14"/><polyline points="7 23 3 19 7 15"/><path d="M21 13v2a4 4 0 0 1-4 4H3"/></svg>
                  </button>
                  <button class="ag-ha-btn" title="Editar" @click.stop="openEdit(appt)">
                    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>
                  </button>
                  <button class="ag-ha-btn ag-ha-btn--del" title="Excluir" @click.stop="deleteTarget = appt">
                    <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
                  </button>
                </div>
              </div>
            </div>


            <!-- Current time line (absolute inside body) -->
            <div
              v-if="isToday && nowTop >= 0 && nowTop <= TOTAL_SLOTS * SLOT_H"
              class="ag-now-line"
              :style="{ top: `${nowTop}px`, left: `${TIME_W}px` }"
            >
              <div class="ag-now-dot" />
              <div class="ag-now-bar" />
            </div>

          </div>
      </div>
    </div>

    <!-- ══ MODAL: create / edit ═══════════════════════════════════════════════ -->
    <Teleport to="body">
      <Transition name="mo">
        <div v-if="showModal" class="mo-overlay" @click.self="closeModal">
          <div class="mo-box">
            <div class="mo-head">
              <span class="mo-head-title">{{ editTarget ? 'Editar agendamento' : 'Novo agendamento' }}</span>
              <button class="mo-x" @click="closeModal"><span class="i-lucide-x" style="font-size:15px" /></button>
            </div>
            <form class="mo-form" @submit.prevent="saveAppointment">
              <div class="mo-grid2">
                <div class="mo-field">
                  <label class="mo-lbl">Cliente</label>
                  <select v-model="form.contact_id" class="mo-inp">
                    <option value="">Selecionar...</option>
                    <option v-for="c in contacts" :key="c.id" :value="c.id">{{ c.name }}</option>
                  </select>
                </div>
                <div class="mo-field">
                  <label class="mo-lbl">Profissional</label>
                  <select v-model="form.professional_id" class="mo-inp">
                    <option value="">Selecionar...</option>
                    <option v-for="col in profCols" :key="col.profId" :value="col.profId">{{ col.name }}</option>
                  </select>
                </div>
              </div>

              <div class="mo-field" v-if="formProducts.length">
                <label class="mo-lbl">Serviços / Produtos</label>
                <div class="mo-services">
                  <button
                    v-for="svc in formProducts" :key="svc.id"
                    type="button"
                    class="mo-svc-btn"
                    :class="{ 'mo-svc-btn--on': form.service_ids.includes(svc.id) }"
                    @click="toggleService(svc.id)"
                  >
                    <span style="font-weight:700">{{ svc.name }}</span>
                    <span style="font-size:9px;opacity:.7;display:block;margin-top:2px">
                      <template v-if="prodDurMin(svc)">{{ prodDurMin(svc) }}min</template>
                      <template v-if="svc.price && Number(svc.price)"> · R${{ Number(svc.price).toFixed(2).replace('.',',') }}</template>
                    </span>
                  </button>
                </div>
                <div v-if="form.service_ids.length" style="font-size:10px;color:#475569;margin-top:5px">
                  Total:
                  {{ formProducts.filter(p=>form.service_ids.includes(p.id)).reduce((s,p)=>s+prodDurMin(p),0) }}min
                  <template v-if="formProducts.filter(p=>form.service_ids.includes(p.id)).some(p=>p.price && Number(p.price))">
                    · R${{ formProducts.filter(p=>form.service_ids.includes(p.id)).reduce((s,p)=>s+Number(p.price||0),0).toFixed(2).replace('.',',') }}
                  </template>
                </div>
              </div>

              <div class="mo-grid3">
                <div class="mo-field">
                  <label class="mo-lbl">Data *</label>
                  <input v-model="form.date" type="date" class="mo-inp" required />
                </div>
                <div class="mo-field">
                  <label class="mo-lbl">Início</label>
                  <input v-model="form.start_time" type="time" class="mo-inp" />
                </div>
                <div class="mo-field">
                  <label class="mo-lbl">Fim</label>
                  <input v-model="form.end_time" type="time" class="mo-inp" />
                </div>
              </div>

              <div class="mo-field">
                <label class="mo-lbl">Status</label>
                <select v-model="form.status" class="mo-inp">
                  <option v-for="s in STATUS_OPTS" :key="s.value" :value="s.value">{{ s.label }}</option>
                </select>
              </div>

              <div class="mo-field">
                <label class="mo-lbl">Observações</label>
                <textarea v-model="form.notes" class="mo-inp" rows="2" style="height:auto;padding:8px 10px;resize:none" placeholder="Observações..." />
              </div>

              <!-- ── pagamento ── mostrar só em edição de concluído ──────── -->
              <div v-if="editTarget && form.status === 'completed'" class="mo-payment-box">
                <p class="mo-lbl" style="margin-bottom:8px">Pagamento</p>

                <!-- já pago -->
                <div v-if="editTarget.payment" class="mo-paid-badge">
                  <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M20 6L9 17l-5-5"/></svg>
                  Pago via {{ { dinheiro:'Dinheiro', pix:'Pix', debito:'Débito', credito:'Crédito' }[editTarget.payment.payment_method] ?? editTarget.payment.payment_method }}
                  · R$ {{ Number(editTarget.payment.amount).toFixed(2).replace('.',',') }}
                </div>

                <!-- ainda não pago -->
                <template v-else>
                  <div class="mo-pay-methods">
                    <button
                      v-for="m in PAYMENT_METHODS" :key="m.key"
                      :class="['mo-pay-btn', { active: selectedPaymentMethod === m.key }]"
                      type="button"
                      @click="selectedPaymentMethod = m.key"
                    >{{ m.label }}</button>
                  </div>
                  <button
                    class="mo-register-pay-btn"
                    type="button"
                    :disabled="!selectedPaymentMethod || savingPayment"
                    @click="registerPayment"
                  >
                    {{ savingPayment ? 'Registrando…' : 'Registrar pagamento' }}
                  </button>
                </template>
              </div>

              <div class="mo-foot">
                <button type="button" class="mo-btn-cancel" @click="closeModal">Cancelar</button>
                <button type="submit" class="mo-btn-save" :disabled="uiFlags.isSaving">
                  {{ uiFlags.isSaving ? 'Salvando...' : editTarget ? 'Salvar' : 'Agendar' }}
                </button>
              </div>
            </form>
          </div>
        </div>
      </Transition>
    </Teleport>

    <!-- ══ MODAL: delete ══════════════════════════════════════════════════════ -->
    <Teleport to="body">
      <div v-if="deleteTarget" class="mo-overlay" @click.self="deleteTarget = null">
        <div class="mo-box" style="max-width:360px">
          <div class="mo-head">
            <span class="mo-head-title">Remover agendamento</span>
            <button class="mo-x" @click="deleteTarget = null"><span class="i-lucide-x" style="font-size:15px" /></button>
          </div>
          <div style="padding:16px 20px;font-size:13px;color:#94a3b8">
            Esta ação não pode ser desfeita.
          </div>
          <div class="mo-foot" style="border-top:1px solid rgb(var(--border-weak))">
            <button class="mo-btn-cancel" @click="deleteTarget = null">Cancelar</button>
            <button class="mo-btn-del" @click="confirmDelete">Remover</button>
          </div>
        </div>
      </div>
    </Teleport>

  </div>
</template>

<style scoped>
/* ── CSS vars scoped to this component ────────────────────────────────────── */
.ag-page {
  --ag-line:      rgb(var(--slate-12) / 0.07);
  --ag-line-mid:  rgb(var(--slate-12) / 0.04);
  --ag-line-soft: rgb(var(--slate-12) / 0.025);
  --ag-hover:     rgb(var(--slate-12) / 0.05);
}

/* ── root ────────────────────────────────────────────────────────────────── */
.ag-page { display:flex; flex-direction:column; width:100%; height:100%; overflow:hidden; background:rgb(var(--background-color)); color:rgb(var(--slate-12)); font-family:inherit; }

/* ── top bar ─────────────────────────────────────────────────────────────── */
.ag-topbar { display:flex; align-items:center; gap:8px; flex-wrap:nowrap; padding:10px 16px; border-bottom:1px solid rgb(var(--border-weak)); background:rgb(var(--background-color)); flex-shrink:0; overflow:visible; }
.ag-topbar-title { flex:1; min-width:0; }
.ag-topbar-filters { display:flex; align-items:center; gap:4px; flex-shrink:0; overflow:visible; flex-wrap:nowrap; margin-left:auto; }
.ag-date-title { font-size:16px; font-weight:800; color:rgb(var(--slate-12)); margin:0; letter-spacing:-.3px; text-transform:capitalize; }
.ag-date-sub { font-size:11px; color:rgb(var(--slate-8)); margin:1px 0 0; }

/* nav arrows */
.ag-nav-group { display:flex; align-items:center; gap:5px; }
.ag-nav-btn { display:flex; align-items:center; justify-content:center; padding:5px 9px; border-radius:9999px; border:1px solid rgb(var(--border-strong)); background:transparent; color:rgb(var(--slate-11)); font-size:12px; font-weight:600; cursor:pointer; transition:all .12s; white-space:nowrap; }
.ag-nav-btn:hover { background:var(--ag-hover); border-color:rgb(var(--n-brand,66 65 255)); }
.ag-nav-hoje { padding:5px 14px; }

/* ── filter bar ──────────────────────────────────────────────────────────── */
/* ag-filterbar removed — filters now live in ag-topbar-filters */

/* dropdown container */
.ag-fb-item { position:relative; }

/* filter button */
.ag-fb-btn { display:flex; align-items:center; gap:5px; padding:4px 10px; border-radius:8px; border:1px solid rgb(var(--border-strong)); background:rgb(var(--background-color)); color:rgb(var(--slate-10)); font-size:11px; font-weight:600; cursor:pointer; transition:all .12s; font-family:inherit; white-space:nowrap; }
.ag-fb-btn:hover { border-color:rgba(91,108,245,.4); color:rgb(var(--slate-12)); }
.ag-fb-btn--active { background:rgba(91,108,245,.1); border-color:rgba(91,108,245,.4); color:rgb(var(--n-brand,66 65 255)); }

/* dropdown menu */
.ag-fb-menu { position:absolute; left:0; top:calc(100% + 4px); min-width:180px; background:rgb(var(--surface-1)); border:1px solid rgb(var(--border-strong)); border-radius:10px; box-shadow:0 8px 24px rgba(0,0,0,.25); z-index:200; padding:4px; }
.ag-fb-menu--scroll { max-height:220px; overflow-y:auto; }
.ag-fb-opt { display:flex; align-items:center; gap:7px; width:100%; padding:6px 10px; border-radius:7px; border:none; background:transparent; color:rgb(var(--slate-11)); font-size:11px; font-weight:500; cursor:pointer; text-align:left; transition:background .1s; font-family:inherit; }
.ag-fb-opt:hover { background:var(--ag-hover); color:rgb(var(--slate-12)); }
.ag-fb-opt--active { color:rgb(var(--n-brand,66 65 255)); font-weight:600; }
.ag-fb-dot { width:8px; height:8px; border-radius:50%; flex-shrink:0; }
.ag-fb-check { margin-left:auto; flex-shrink:0; color:rgb(var(--n-brand,66 65 255)); }
.ag-fb-av { width:18px; height:18px; border-radius:50%; flex-shrink:0; display:flex; align-items:center; justify-content:center; font-size:8px; font-weight:800; }

/* active chips */
.ag-fb-active { display:flex; align-items:center; gap:5px; flex-wrap:wrap; margin-left:4px; }
.ag-fb-chip { display:flex; align-items:center; gap:4px; padding:3px 8px; border-radius:9999px; background:rgba(91,108,245,.12); border:1px solid rgba(91,108,245,.3); color:rgb(var(--n-brand,66 65 255)); font-size:10px; font-weight:600; }
.ag-fb-chip-x { background:none; border:none; cursor:pointer; color:currentColor; opacity:.7; padding:0; display:flex; font-size:9px; }
.ag-fb-chip-x:hover { opacity:1; }
.ag-fb-clear { display:flex; align-items:center; gap:4px; padding:3px 8px; border-radius:9999px; background:none; border:none; color:rgb(var(--ruby-9,229 70 102)); font-size:10px; font-weight:600; cursor:pointer; transition:opacity .12s; }
.ag-fb-clear:hover { opacity:.8; }
.ag-fb-clear--inline { flex-shrink:0; }

/* new button – sem brilho */
.ag-new-btn { display:flex; align-items:center; gap:6px; padding:7px 16px; border-radius:9999px; background:rgb(var(--n-brand,66 65 255)); color:#fff; font-size:12px; font-weight:700; border:none; cursor:pointer; flex-shrink:0; transition:opacity .15s; }
.ag-new-btn:hover { opacity:.88; }

/* branch pills */
.ag-branch-btns { display:flex; align-items:center; gap:2px; padding:3px; border-radius:9999px; border:1px solid rgb(var(--border-weak)); background:var(--ag-hover); flex-shrink:0; }
.ag-branch-btn { display:flex; align-items:center; gap:5px; padding:4px 11px; border-radius:9999px; border:none; background:transparent; color:rgb(var(--slate-9)); font-size:11px; font-weight:600; cursor:pointer; transition:all .12s; white-space:nowrap; font-family:inherit; }
.ag-branch-btn:hover { color:rgb(var(--slate-11)); background:rgb(var(--slate-12) / 0.06); }
.ag-branch-btn--active { background:rgba(91,108,245,.18); color:#a5b4fc; }

/* ── body ────────────────────────────────────────────────────────────────── */
.ag-body { flex:1; display:flex; overflow:hidden; }

/* ── sidebar ─────────────────────────────────────────────────────────────── */
.ag-sidebar { width:240px; flex-shrink:0; border-right:1px solid rgb(var(--border-weak)); background:rgb(var(--surface-1)); overflow-y:auto; overflow-x:hidden; display:flex; flex-direction:column; }
.ag-sidebar-divider { height:1px; background:rgb(var(--border-weak)); margin:2px 14px 0; }
.ag-sidebar-section { padding:14px 14px 0; }
.ag-section-label { font-size:9px; font-weight:700; text-transform:uppercase; letter-spacing:.1em; color:rgb(var(--slate-8)); margin:0 0 8px; }

/* mini calendar */
.ag-mini-cal { padding:14px 12px 10px; }
.ag-mc-header { display:flex; align-items:center; justify-content:space-between; margin-bottom:8px; }
.ag-mc-nav { background:none; border:1px solid rgb(var(--border-weak)); border-radius:6px; width:22px; height:22px; cursor:pointer; color:rgb(var(--slate-10)); display:flex; align-items:center; justify-content:center; font-size:14px; line-height:1; flex-shrink:0; }
.ag-mc-nav:hover { background:var(--ag-hover); }
.ag-mc-month { font-size:11px; font-weight:700; color:rgb(var(--slate-12)); text-transform:capitalize; text-align:center; }
.ag-mc-dow-row { display:grid; grid-template-columns:repeat(7,1fr); margin-bottom:2px; }
.ag-mc-dow { text-align:center; font-size:8px; font-weight:700; color:rgb(var(--slate-8)); padding:2px 0; }
.ag-mc-grid { display:grid; grid-template-columns:repeat(7,1fr); gap:1px; }
.ag-mc-empty { height:24px; }
.ag-mc-day { width:100%; height:24px; border:none; border-radius:5px; background:transparent; color:rgb(var(--slate-10)); font-size:11px; cursor:pointer; display:flex; align-items:center; justify-content:center; transition:background .12s; padding:0; }
.ag-mc-day:hover:not(.ag-mc-day--sel) { background:var(--ag-hover); }
.ag-mc-day--sel { background:rgb(var(--n-brand,66 65 255)); color:#fff; font-weight:700; }
.ag-mc-day--today { color:rgb(var(--n-brand,66 65 255)); font-weight:700; }

/* status */
.ag-status-list { display:flex; flex-direction:column; gap:4px; }
.ag-status-row { display:flex; align-items:center; justify-content:space-between; padding:5px 8px; border-radius:7px; }
.ag-status-dot { width:6px; height:6px; border-radius:50%; flex-shrink:0; }
.ag-status-label { font-size:11px; color:rgb(var(--slate-10)); }
.ag-status-count { font-size:12px; font-weight:700; }

/* upcoming */
.ag-upcoming-list { display:flex; flex-direction:column; gap:5px; padding-bottom:14px; }
.ag-upcoming-card { padding:6px 8px; border-radius:7px; background:rgb(var(--background-color)); border:1px solid rgb(var(--border-weak)); cursor:pointer; transition:opacity .12s; }
.ag-upcoming-card:hover { opacity:.8; }
.ag-up-time { font-size:10px; font-weight:700; font-family:'JetBrains Mono',ui-monospace,monospace; }
.ag-up-name { font-size:11px; font-weight:700; color:rgb(var(--slate-12)); overflow:hidden; text-overflow:ellipsis; white-space:nowrap; margin-top:1px; }
.ag-up-sub  { font-size:10px; color:rgb(var(--slate-8)); overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }

/* empty */
.ag-sidebar-empty { padding:20px 14px; text-align:center; display:flex; flex-direction:column; align-items:center; gap:6px; }

/* ── calendar grid ───────────────────────────────────────────────────────── */
.ag-grid-wrap { flex:1; overflow:auto; display:flex; flex-direction:column; min-width:0; position:relative; }
.ag-prof-headers { position:sticky; top:0; z-index:20; display:flex; flex-shrink:0; background:rgb(var(--background-color)); border-bottom:2px solid rgb(var(--border-weak)); }
.ag-gutter-corner { width:54px; flex-shrink:0; border-right:1px solid rgb(var(--border-weak)); background:rgb(var(--surface-1)); }
.ag-prof-head { flex:1; min-width:150px; border-right:1px solid rgb(var(--border-weak)); background:rgb(var(--surface-1)); padding:10px 12px; display:flex; align-items:center; gap:9px; overflow:hidden; }
.ag-prof-av { width:38px; height:38px; border-radius:50%; flex-shrink:0; display:flex; align-items:center; justify-content:center; font-weight:900; font-size:14px; letter-spacing:-.5px; overflow:hidden; }
.ag-prof-info { flex:1; min-width:0; }
.ag-prof-name { font-weight:700; font-size:12px; color:rgb(var(--slate-12)); overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
.ag-prof-role { font-size:10px; margin-top:1px; font-weight:600; }
.ag-prof-badge { flex-shrink:0; border-radius:20px; padding:1px 7px; font-size:10px; font-weight:700; }

.ag-grid-body { display:flex; flex:1; position:relative; }
.ag-time-col { width:54px; flex-shrink:0; position:sticky; left:0; z-index:10; background:rgb(var(--background-color)); align-self:flex-start; }
.ag-time-slot { display:flex; align-items:flex-start; justify-content:flex-end; padding-right:7px; padding-top:2px; border-right:1px solid rgb(var(--border-weak)); border-bottom:1px solid; width:54px; }
.ag-time-label { font-size:9px; color:rgb(var(--slate-7)); font-family:'JetBrains Mono',ui-monospace,monospace; font-weight:600; line-height:1; }

.ag-col { flex:1; min-width:150px; position:relative; border-right:1px solid rgb(var(--border-weak)); }
.ag-slot { border-bottom:1px solid; cursor:cell; transition:background .08s; width:100%; }

/* availability overlays */
/* ── availability overlays ───────────────────────────────────────────────── */

/* full-day block */
.ag-avail-full { position:absolute; inset:0; z-index:5; pointer-events:all; cursor:not-allowed; display:flex; align-items:center; justify-content:center; }
.ag-avail-full--blocked {
  background-color: #111213;
  background-image: repeating-linear-gradient(
    -45deg,
    transparent                 0px, transparent                 8px,
    rgb(var(--slate-12) / 0.09) 8px, rgb(var(--slate-12) / 0.09) 9px
  );
}
.ag-avail-full--holiday {
  background-color: rgba(251,191,36,0.06);
  background-image: repeating-linear-gradient(
    -45deg,
    transparent             0px, transparent             8px,
    rgba(251,191,36,0.12)   8px, rgba(251,191,36,0.12)   9px
  );
}
.ag-avail-full-inner { display:flex; flex-direction:column; align-items:center; gap:5px; padding:10px; }
.ag-avail-full-icon { font-size:18px; color:rgb(var(--slate-9)); opacity:.5; }
.ag-avail-full--holiday .ag-avail-full-icon { color:rgb(var(--amber-9)); opacity:.7; }
.ag-avail-full-label { font-size:10px; font-weight:600; color:rgb(var(--slate-9)); letter-spacing:.03em; text-align:center; }
.ag-avail-full--holiday .ag-avail-full-label { color:rgb(var(--amber-11)); }

/* before/after work hours hatch + non-working day */
.ag-avail-hatch { position:absolute; left:0; right:0; z-index:3; pointer-events:all; cursor:not-allowed;
  background-color: #111213;
  background-image: repeating-linear-gradient(
    -45deg,
    transparent                      0px,
    transparent                      8px,
    rgb(var(--slate-12) / 0.09)      8px,
    rgb(var(--slate-12) / 0.09)      9px
  );
}
.ag-avail-hatch--full { top:0; bottom:0; height:100%; display:flex; align-items:center; justify-content:center; }
.ag-avail-offday-label { display:flex; align-items:center; gap:5px; font-size:10px; font-weight:600; color:rgb(var(--slate-8)); letter-spacing:.03em; }

/* breaks */
.ag-avail-break { position:absolute; left:0; right:0; z-index:4; pointer-events:none; overflow:hidden;
  background-color: #111213;
  background-image: repeating-linear-gradient(
    -45deg,
    transparent                  0px, transparent                  8px,
    rgb(var(--slate-12) / 0.12)  8px, rgb(var(--slate-12) / 0.12)  9px
  );
  border-top: 1px solid rgb(var(--border-strong));
  border-bottom: 1px solid rgb(var(--border-strong));
  display:flex; align-items:flex-start; padding:3px 6px;
}
.ag-avail-break-pill { display:inline-flex; align-items:center; gap:4px; padding:2px 7px; border-radius:99px; background:rgb(var(--surface-1)); border:1px solid rgb(var(--border-strong)); font-size:9px; font-weight:600; color:rgb(var(--slate-9)); white-space:nowrap; box-shadow:0 1px 2px rgba(0,0,0,.06); }

/* specific blocked slots */
.ag-avail-slot-block { position:absolute; left:0; right:0; z-index:4; pointer-events:all; cursor:not-allowed; overflow:hidden;
  background-color: rgb(var(--ruby-9) / 0.05);
  background-image: repeating-linear-gradient(-45deg, rgb(var(--ruby-9) / 0.04) 0px, rgb(var(--ruby-9) / 0.04) 1px, transparent 1px, transparent 6px);
  border-top: 1px solid rgb(var(--ruby-9) / 0.2);
  border-bottom: 1px solid rgb(var(--ruby-9) / 0.2);
  display:flex; align-items:flex-start; padding:3px 6px;
}
.ag-avail-block-pill { display:inline-flex; align-items:center; gap:4px; padding:2px 7px; border-radius:99px; background:rgb(var(--surface-1)); border:1px solid rgb(var(--ruby-9) / 0.25); font-size:9px; font-weight:600; color:rgb(var(--ruby-11)); white-space:nowrap; box-shadow:0 1px 2px rgba(0,0,0,.06); }

/* ── empty state: no professionals ─────────────────────────────────────── */
.ag-no-prof-wrap { flex:1; display:flex; align-items:center; justify-content:center; position:relative; overflow:hidden; background:rgb(var(--background-color)); }

/* faint horizontal lines suggesting calendar grid */
.ag-no-prof-bg-lines { position:absolute; inset:0; display:flex; flex-direction:column; pointer-events:none; }
.ag-no-prof-bg-line { flex:1; border-bottom:1px solid rgb(var(--slate-12) / 0.05); }

/* card */
.ag-no-prof-box { position:relative; z-index:1; display:flex; flex-direction:column; align-items:center; gap:16px; padding:36px 32px; border-radius:20px; background:rgb(var(--surface-1)); border:1px solid rgb(var(--border-strong)); box-shadow:0 20px 60px rgba(0,0,0,.15), 0 0 0 1px rgb(var(--border-weak)); text-align:center; max-width:340px; width:90%; }

/* icon */
.ag-no-prof-icon-wrap { width:64px; height:64px; border-radius:16px; background:rgb(var(--n-brand) / 0.12); border:1.5px solid rgb(var(--n-brand) / 0.25); display:flex; align-items:center; justify-content:center; color:rgb(var(--n-brand)); }

/* text block */
.ag-no-prof-text { display:flex; flex-direction:column; gap:6px; }
.ag-no-prof-title { font-size:16px; font-weight:700; color:rgb(var(--slate-12)); letter-spacing:-.01em; }
.ag-no-prof-sub { font-size:12px; color:rgb(var(--slate-9)); line-height:1.55; max-width:260px; }

/* actions */
.ag-no-prof-actions { display:flex; flex-direction:column; gap:8px; width:100%; margin-top:4px; }
.ag-no-prof-btn { display:flex; align-items:center; justify-content:center; gap:6px; padding:9px 16px; border-radius:10px; background:rgb(var(--n-brand)); color:#fff; font-size:13px; font-weight:600; text-decoration:none; transition:opacity .12s, transform .1s; }
.ag-no-prof-btn:hover { opacity:.88; transform:translateY(-1px); }
.ag-no-prof-btn-sec { display:flex; align-items:center; justify-content:center; gap:6px; padding:8px 16px; border-radius:10px; background:transparent; border:1px solid rgb(var(--border-strong)); color:rgb(var(--slate-10)); font-size:12px; font-weight:600; text-decoration:none; transition:background .12s, color .12s; }
.ag-no-prof-btn-sec:hover { background:rgb(var(--surface-2)); color:rgb(var(--slate-12)); }

/* ═══════════════════════════════════════════════════════════════
   APPOINTMENT CARDS  — barber-app style
   ═══════════════════════════════════════════════════════════════ */

.ag-card {
  position:absolute; left:3px; right:3px;
  border-radius:12px; overflow:hidden;
  cursor:grab; user-select:none;
  display:flex; flex-direction:column;
  padding:6px 10px;
  box-shadow:0 1px 3px rgba(0,0,0,.06);
  transition:box-shadow .2s, opacity .12s;
}
.ag-card--hovered { box-shadow:0 4px 16px rgba(0,0,0,.12); }
.ag-card--new { animation:agNewCard 1.2s ease-out; }
@keyframes agNewCard { 0%,40%{ box-shadow:0 0 0 2px rgb(var(--n-brand)/.6);} 100%{box-shadow:none;} }

/* ── compact ≤20min: single flex row ── */
.ag-bc { display:flex; align-items:center; gap:5px; height:100%; overflow:hidden; }

/* ── text elements ── */
.ag-bt {
  font-size:9px; font-weight:800;
  font-family:'JetBrains Mono',ui-monospace,monospace;
  white-space:nowrap; flex-shrink:0; line-height:1.2;
}
.ag-bn {
  font-size:12px; font-weight:700;
  color:rgb(var(--slate-12));
  overflow:hidden; text-overflow:ellipsis; white-space:nowrap;
  line-height:1.3;
}
.ag-bs {
  font-size:10px; font-weight:500; color:rgb(var(--slate-10));
  overflow:hidden; text-overflow:ellipsis; white-space:nowrap;
  line-height:1.2; margin-top:1px;
}
.ag-bm {
  display:flex; align-items:center; gap:6px;
  font-size:9px; font-weight:500; color:rgb(var(--slate-9));
  overflow:hidden; margin-top:1px;
}
.ag-bprice { font-weight:700; }
.ag-bnotes {
  font-size:9px; color:rgb(var(--slate-8));
  overflow:hidden; text-overflow:ellipsis; white-space:nowrap;
  margin-top:1px; line-height:1.3;
}

/* ── agent footer ── */
.ag-bf {
  display:flex; align-items:center; gap:5px;
  margin-top:auto; padding-top:4px;
  overflow:hidden;
}
.ag-bf-av {
  width:20px; height:20px; border-radius:50%; flex-shrink:0;
  display:flex; align-items:center; justify-content:center;
  font-size:7px; font-weight:800; overflow:hidden;
  background:rgb(var(--slate-12)/0.06);
  border:1px dashed rgb(var(--border-weak));
  color:rgb(var(--slate-9));
}
.ag-bf-name { font-size:9px; font-weight:600; color:rgb(var(--slate-9)); overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }

/* ── hover action buttons (absolute overlay, top-right) ── */
.ag-hover-acts {
  position:absolute; top:3px; right:3px;
  display:flex; align-items:center; gap:2px;
  z-index:5;
}
.ag-ha-btn {
  width:32px; height:32px;
  display:flex; align-items:center; justify-content:center;
  border-radius:8px; cursor:pointer;
  background:rgb(var(--slate-3));
  border:1px solid rgb(var(--border-strong));
  color:rgb(var(--slate-11));
  transition:background .1s, color .1s, border-color .1s;
}
.ag-ha-btn:hover { background:rgb(var(--slate-4)); color:rgb(var(--slate-12)); border-color:rgb(var(--slate-7)); }
.ag-ha-btn--del { background:rgb(var(--slate-3)); color:rgb(var(--slate-11)); }
.ag-ha-btn--del:hover { background:rgb(var(--ruby-9) / 0.15); color:rgb(var(--ruby-9)); border-color:rgb(var(--ruby-9) / 0.4); }

/* status badge (kept for any remaining use) */
.ag-badge { display:inline-flex; align-items:center; padding:2px 6px; border-radius:99px; font-size:9px; font-weight:700; letter-spacing:.04em; text-transform:uppercase; white-space:nowrap; flex-shrink:0; }

/* now line */
.ag-now-line { position:absolute; right:0; z-index:15; pointer-events:none; }
.ag-now-dot { position:absolute; left:-6px; top:-4px; width:10px; height:10px; border-radius:50%; background:rgb(var(--n-brand,66 65 255)); box-shadow:0 0 6px rgba(91,108,245,.6); }
.ag-now-bar { height:2px; background:rgb(var(--n-brand,66 65 255)); opacity:.85; }

/* loading overlay transition */
.ag-fade-enter-active { transition: opacity .1s ease; }
.ag-fade-leave-active { transition: opacity .4s ease; }
.ag-fade-enter-from, .ag-fade-leave-to { opacity: 0; }

/* loading */
.ag-loading-overlay { position:absolute; inset:0; z-index:5; display:flex; pointer-events:none; background:rgb(var(--background-color) / 0.85); }
.ag-loading-col { flex:1; padding:10px; display:flex; flex-direction:column; gap:10px; border-right:1px solid rgb(var(--border-weak)); }
.ag-skeleton { border-radius:8px; background:rgb(var(--slate-12) / 0.06); animation:agSkel 1.5s ease-in-out infinite; }
@keyframes agSkel { 0%,100%{opacity:.6} 50%{opacity:1} }

/* ── modal ───────────────────────────────────────────────────────────────── */
.mo-overlay { position:fixed; inset:0; z-index:9999; display:flex; align-items:center; justify-content:center; padding:16px; background:rgba(0,0,0,.65); backdrop-filter:blur(8px); }
.mo-box { position:relative; width:100%; max-width:440px; max-height:90vh; background:rgb(var(--surface-1)); border:1px solid rgb(var(--border-strong)); border-radius:14px; box-shadow:0 24px 64px rgba(0,0,0,.4); display:flex; flex-direction:column; overflow:hidden; }
.mo-head { display:flex; align-items:center; justify-content:space-between; padding:16px 20px; border-bottom:1px solid rgb(var(--border-weak)); flex-shrink:0; }
.mo-head-title { font-size:15px; font-weight:700; color:rgb(var(--slate-12)); }
.mo-x { background:none; border:none; cursor:pointer; color:rgb(var(--slate-8)); display:flex; transition:color .12s; }
.mo-x:hover { color:rgb(var(--slate-12)); }
.mo-form { flex:1; overflow-y:auto; padding:16px 20px; display:flex; flex-direction:column; gap:14px; }
.mo-grid2 { display:grid; grid-template-columns:1fr 1fr; gap:14px; }
.mo-grid3 { display:grid; grid-template-columns:1.2fr 1fr 1fr; gap:10px; }
.mo-field { display:flex; flex-direction:column; gap:5px; }
.mo-lbl { font-size:10px; font-weight:700; text-transform:uppercase; letter-spacing:.1em; color:rgb(var(--slate-8)); }
.mo-inp { width:100%; height:34px; padding:0 10px; border-radius:8px; border:1px solid rgb(var(--border-strong)); background:rgb(var(--background-color)); color:rgb(var(--slate-12)); font-size:12px; font-family:inherit; outline:none; transition:border-color .15s; }
.mo-inp:focus { border-color:rgb(var(--n-brand,66 65 255)); }
textarea.mo-inp { height:auto; }
.mo-services { display:flex; flex-wrap:wrap; gap:6px; }
.mo-svc-btn { padding:5px 10px; border-radius:20px; cursor:pointer; font-size:11px; font-weight:600; background:rgb(var(--background-color)); border:1px solid rgb(var(--border-weak)); color:rgb(var(--slate-10)); transition:all .12s; }
.mo-svc-btn:hover { color:rgb(var(--slate-12)); border-color:rgb(var(--border-strong)); }
.mo-svc-btn--on { background:rgba(91,108,245,.2); border-color:rgba(91,108,245,.6); color:#fff; }
.mo-foot { display:flex; align-items:center; justify-content:flex-end; gap:8px; padding:14px 20px; border-top:1px solid rgb(var(--border-weak)); }
.mo-btn-cancel { height:32px; padding:0 14px; border-radius:8px; border:1px solid rgb(var(--border-strong)); background:transparent; color:rgb(var(--slate-10)); font-size:12px; font-weight:600; cursor:pointer; transition:background .12s; }
.mo-btn-cancel:hover { background:var(--ag-hover); }
.mo-btn-save { height:32px; padding:0 16px; border-radius:8px; background:rgb(var(--n-brand,66 65 255)); color:#fff; font-size:12px; font-weight:700; border:none; cursor:pointer; transition:opacity .15s; }
.mo-btn-save:hover:not(:disabled) { opacity:.88; }
.mo-btn-save:disabled { opacity:.5; cursor:not-allowed; }
.mo-btn-del { height:32px; padding:0 16px; border-radius:8px; background:#ef4444; color:#fff; font-size:12px; font-weight:700; border:none; cursor:pointer; }

/* transitions */
.mo-enter-active, .mo-leave-active { transition:opacity .15s ease; }
.mo-enter-from, .mo-leave-to { opacity:0; }

/* reminder button (beside Novo) */
.ag-reminder-btn { height:30px; width:32px; display:inline-flex; align-items:center; justify-content:center; border-radius:8px; border:1px solid rgb(var(--border-strong)); background:rgb(var(--background-color)); color:rgb(var(--slate-8)); cursor:pointer; transition:all .15s; flex-shrink:0; }
.ag-reminder-btn:hover { background:rgb(var(--surface-2)); color:rgb(var(--slate-12)); border-color:rgb(var(--border-strong)); }

/* ── payment box inside modal ─────────────────────────────────────────────── */
.mo-payment-box { background:rgb(var(--surface-2)); border:1px solid rgb(var(--border-weak)); border-radius:10px; padding:12px 14px; }
.mo-paid-badge { display:inline-flex; align-items:center; gap:6px; font-size:12px; font-weight:700; color:#22c55e; background:#dcfce7; border-radius:8px; padding:6px 12px; }
.mo-pay-methods { display:grid; grid-template-columns:repeat(4,1fr); gap:6px; margin-bottom:10px; }
.mo-pay-btn { height:30px; border-radius:8px; border:1px solid rgb(var(--border-strong)); background:transparent; color:rgb(var(--slate-10)); font-size:11px; font-weight:600; cursor:pointer; transition:all .12s; }
.mo-pay-btn:hover { background:rgb(var(--surface-1)); color:rgb(var(--slate-12)); }
.mo-pay-btn.active { background:rgb(var(--n-brand,66 65 255)); color:#fff; border-color:rgb(var(--n-brand,66 65 255)); }
.mo-register-pay-btn { width:100%; height:32px; border-radius:8px; background:rgb(var(--n-brand,66 65 255)); color:#fff; font-size:12px; font-weight:700; border:none; cursor:pointer; transition:opacity .15s; }
.mo-register-pay-btn:hover:not(:disabled) { opacity:.88; }
.mo-register-pay-btn:disabled { opacity:.4; cursor:not-allowed; }
</style>
