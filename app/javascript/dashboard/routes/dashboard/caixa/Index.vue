<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useStore } from 'vuex';

const store = useStore();

const now = new Date();
const todayISO = now.toISOString().slice(0, 10);
const curMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
const selectedPeriod = ref(curMonth);
const activeTab = ref('overview');

function prevMonth() {
  const [y, m] = selectedPeriod.value.split('-').map(Number);
  const d = new Date(y, m - 2, 1);
  selectedPeriod.value = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
}
function nextMonth() {
  const [y, m] = selectedPeriod.value.split('-').map(Number);
  const d = new Date(y, m, 1);
  selectedPeriod.value = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
}
const isCurrentMonth = computed(() => selectedPeriod.value === curMonth);

const transactions      = computed(() => store.getters['cashTransactions/getTransactions'] ?? []);
const commissions       = computed(() => store.getters['cashTransactions/getCommissions'] ?? []);
const commissionSummary = computed(() => store.getters['cashTransactions/getCommissionSummary']);
const uiFlags           = computed(() => store.getters['cashTransactions/getUIFlags'] ?? {});

function loadCaixa() {
  const [y, m] = selectedPeriod.value.split('-');
  const from = `${y}-${m}-01`;
  const lastDay = new Date(Number(y), Number(m), 0).getDate();
  store.dispatch('cashTransactions/fetchTransactions', { from, to: `${y}-${m}-${String(lastDay).padStart(2,'0')}` });
}
function loadCommissions() {
  store.dispatch('cashTransactions/fetchCommissionSummary', { period: selectedPeriod.value });
  store.dispatch('cashTransactions/fetchCommissions', { period: selectedPeriod.value });
}
onMounted(() => { loadCaixa(); loadCommissions(); });
watch(selectedPeriod, () => { loadCaixa(); loadCommissions(); });

function fmt(n) {
  return 'R$ ' + Number(n || 0).toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}
function fmtK(n) {
  const v = Number(n || 0);
  if (v >= 1000) return 'R$' + (v / 1000).toLocaleString('pt-BR', { maximumFractionDigits: 1 }) + 'k';
  return 'R$' + v.toFixed(0);
}
function fmtDate(iso) {
  return new Date(iso).toLocaleDateString('pt-BR', { day: '2-digit', month: 'short' });
}

const periodLabel = computed(() => {
  const [y, m] = selectedPeriod.value.split('-').map(Number);
  const s = new Date(y, m - 1, 1).toLocaleDateString('pt-BR', { month: 'long', year: 'numeric' });
  return s.charAt(0).toUpperCase() + s.slice(1);
});
const periodRange = computed(() => {
  const [y, m] = selectedPeriod.value.split('-').map(Number);
  const d1 = new Date(y, m - 1, 1);
  const d2 = new Date(y, m, 0);
  return `${d1.toLocaleDateString('pt-BR',{day:'2-digit',month:'short',year:'numeric'})} — ${d2.toLocaleDateString('pt-BR',{day:'2-digit',month:'short',year:'numeric'})}`;
});
const periodStart = computed(() => periodRange.value.split('—')[0].trim());
const periodEnd   = computed(() => periodRange.value.split('—')[1]?.trim());

const allItems   = computed(() => transactions.value);
const income     = computed(() => allItems.value.filter(t => t.transaction_type === 'income').reduce((s,t) => s + +t.amount, 0));
const expense    = computed(() => allItems.value.filter(t => t.transaction_type === 'expense').reduce((s,t) => s + +t.amount, 0));
const balance    = computed(() => income.value - expense.value);
const unpaidComm = computed(() => commissionSummary.value ? +commissionSummary.value.unpaid_amount || 0 : 0);

// smooth SVG line chart
const chart = computed(() => {
  const [y, m] = selectedPeriod.value.split('-').map(Number);
  const days = new Date(y, m, 0).getDate();
  const b = Array.from({ length: days }, () => ({ i: 0, e: 0 }));
  for (const t of allItems.value) {
    const d = new Date(t.date).getDate() - 1;
    if (d >= 0 && d < days) b[d][t.transaction_type === 'income' ? 'i' : 'e'] += +t.amount;
  }
  let ci = 0, ce = 0;
  const pts = b.map((x, idx) => { ci += x.i; ce += x.e; return { n: idx+1, i: ci, e: ce }; });

  const W = 560, H = 160, px = 8, py = 14;
  const maxY = Math.max(...pts.map(p => Math.max(p.i, p.e)), 1);
  const xf = i => px + (i / (pts.length - 1 || 1)) * (W - px * 2);
  const yf = v => H - py - (v / maxY) * (H - py * 2);

  function smoothPath(key) {
    if (!pts.length) return '';
    const p = pts.map((pt, i) => [xf(i), yf(pt[key])]);
    let d = `M${p[0][0].toFixed(1)},${p[0][1].toFixed(1)}`;
    for (let i = 1; i < p.length; i++) {
      const cp1x = (p[i-1][0] + p[i][0]) / 2;
      const cp2x = (p[i-1][0] + p[i][0]) / 2;
      d += ` C${cp1x.toFixed(1)},${p[i-1][1].toFixed(1)} ${cp2x.toFixed(1)},${p[i][1].toFixed(1)} ${p[i][0].toFixed(1)},${p[i][1].toFixed(1)}`;
    }
    return d;
  }
  const hasData = allItems.value.length > 0;
  if (!hasData) return null;
  const iD = smoothPath('i');
  const eD = smoothPath('e');
  const iArea = iD + ` L${xf(pts.length-1).toFixed(1)},${H} L${xf(0).toFixed(1)},${H} Z`;
  const grid  = [0, 0.33, 0.67, 1].map(f => ({ y: yf(maxY*f), l: fmtK(maxY*f) }));
  return { iD, eD, iArea, grid, W, H };
});

const cats = computed(() => {
  const m = {};
  for (const t of allItems.value) {
    const c = t.category || 'Outros';
    if (!m[c]) m[c] = { name: c, v: 0, isIncome: false };
    m[c].v += +t.amount;
    if (t.transaction_type === 'income') m[c].isIncome = true;
  }
  return Object.values(m).sort((a,b) => b.v - a.v).slice(0, 7);
});
const catsTotal = computed(() => cats.value.reduce((s,c) => s+c.v, 0));
const CAT_COLORS = ['#6366f1','#8b5cf6','#06b6d4','#10b981','#f59e0b','#f43f5e','#ec4899'];

const METHODS = [
  { key: 'dinheiro', label: 'Dinheiro',  color: '#6366f1' },
  { key: 'pix',      label: 'Pix',       color: '#22d3ee' },
  { key: 'debito',   label: 'Débito',    color: '#f59e0b' },
  { key: 'credito',  label: 'Crédito',   color: '#10b981' },
];
const byMethod = computed(() => {
  const r = {};
  for (const m of METHODS)
    r[m.key] = allItems.value.filter(t => t.transaction_type==='income' && t.payment_method===m.key).reduce((s,t) => s + +t.amount, 0);
  return r;
});

const recentTx = computed(() => [...allItems.value].sort((a,b) => new Date(b.date)-new Date(a.date)).slice(0,7));

const donutSegs = computed(() => {
  if (!commissionSummary.value) return [];
  const byP = commissionSummary.value.by_professional || [];
  if (!byP.length) return [];
  const total = byP.reduce((s,p) => s + +p.total_amount, 0);
  if (!total) return [];
  const COLORS = ['#6366f1','#22d3ee','#f59e0b','#10b981','#f43f5e','#8b5cf6'];
  const R = 38, CIRC = 2 * Math.PI * R;
  let offset = 0;
  return byP.slice(0,5).map((p, i) => {
    const pct = +p.total_amount / total;
    const dash = pct * CIRC;
    const seg = { ...p, color: COLORS[i], dash, offset, pct: (pct*100).toFixed(0) };
    offset += dash;
    return seg;
  });
});

const showModal = ref(false);
const mForm = ref({ type: 'expense', desc: '', amount: '', cat: '', date: todayISO });
const saving = ref(false);
const mErr = ref('');
const CATS_IN  = ['Serviços','Produtos','Assinatura','Outro'];
const CATS_OUT = ['Aluguel','Insumos','Salário','Comissão','Equipamento','Utilidades','Outro'];
const mCats = computed(() => mForm.value.type === 'income' ? CATS_IN : CATS_OUT);

function openModal() { mForm.value = { type:'expense', desc:'', amount:'', cat:'', date:todayISO }; mErr.value=''; showModal.value=true; }
async function submitModal() {
  if (!mForm.value.desc || !mForm.value.amount) { mErr.value='Preencha os campos obrigatórios.'; return; }
  saving.value=true; mErr.value='';
  try {
    await store.dispatch('cashTransactions/createTransaction', { transaction_type:mForm.value.type, description:mForm.value.desc, amount:mForm.value.amount, category:mForm.value.cat, date:mForm.value.date+'T12:00:00' });
    showModal.value=false; loadCaixa();
  } catch { mErr.value='Erro ao salvar.'; } finally { saving.value=false; }
}

const delItem = ref(null);
const deleting = ref(false);
async function confirmDel() {
  deleting.value=true;
  try { await store.dispatch('cashTransactions/deleteTransaction', delItem.value.id); delItem.value=null; loadCaixa(); }
  finally { deleting.value=false; }
}

const savingComm = ref(null);
async function markPaid(c) {
  savingComm.value=c.id;
  try { await store.dispatch('cashTransactions/updateCommission', { id:c.id, paid:true }); loadCommissions(); }
  finally { savingComm.value=null; }
}

const txFilter = ref('all');
const txSearch = ref('');
const filteredTx = computed(() => allItems.value.filter(t => {
  if (txFilter.value==='income'  && t.transaction_type!=='income')  return false;
  if (txFilter.value==='expense' && t.transaction_type!=='expense') return false;
  if (txSearch.value && !(t.description||'').toLowerCase().includes(txSearch.value.toLowerCase())) return false;
  return true;
}).sort((a,b) => new Date(b.date)-new Date(a.date)));
</script>

<template>
  <div class="fi-root">

    <!-- ── TOPBAR ── -->
    <div class="fi-bar">
      <div class="fi-bar-l">
        <span class="fi-title">Visão Geral</span>
        <div class="fi-tabs">
          <button :class="['fi-tab', activeTab==='overview'     && 'fi-tab-on']" @click="activeTab='overview'">Resumo</button>
          <button :class="['fi-tab', activeTab==='transactions' && 'fi-tab-on']" @click="activeTab='transactions'">Transações</button>
          <button :class="['fi-tab', activeTab==='comissoes'    && 'fi-tab-on']" @click="activeTab='comissoes'">Comissões</button>
        </div>
      </div>
      <div class="fi-bar-r">
        <div class="fi-mnav">
          <button @click="prevMonth">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="15 18 9 12 15 6"/></svg>
          </button>
          <span>{{ periodLabel }}</span>
          <button :disabled="isCurrentMonth" @click="nextMonth">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="9 18 15 12 9 6"/></svg>
          </button>
        </div>
        <button class="fi-btn-new" @click="openModal">
          <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
          Novo lançamento
        </button>
      </div>
    </div>

    <!-- ── OVERVIEW ── -->
    <div v-if="activeTab==='overview'" class="fi-body">

      <!-- 4 KPI cards -->
      <div class="fi-kpi-row">

        <!-- hero card -->
        <div class="fi-card fi-kpi-hero">
          <p class="fi-kpi-label">Saldo do período</p>
          <div class="fi-kpi-hero-val">
            <span :class="['fi-kpi-num', balance<0&&'fi-red']">{{ fmt(balance) }}</span>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" class="fi-muted-icon"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
          </div>
          <div class="fi-kpi-foot">
            <span :class="['fi-badge', balance>=0?'fi-badge-up':'fi-badge-dn']">
              <svg width="8" height="8" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><polyline v-if="balance>=0" points="18 15 12 9 6 15"/><polyline v-else points="6 9 12 15 18 9"/></svg>
              {{ income>0 ? Math.abs((balance/income)*100).toFixed(2):0 }}%
            </span>
            <span class="fi-kpi-compare">comparado ao período</span>
          </div>
        </div>

        <!-- entradas -->
        <div class="fi-card fi-kpi-sm">
          <div class="fi-kpi-flag" style="background:rgba(99,102,241,.12);">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#6366f1" stroke-width="2.5"><polyline points="18 15 12 9 6 15"/></svg>
          </div>
          <p class="fi-kpi-label" style="margin-top:10px;">Entradas</p>
          <p class="fi-kpi-num fi-sm-num">{{ fmt(income) }}</p>
          <p class="fi-kpi-sub">{{ fmt(income) }} / {{ income+expense>0?((income/(income+expense))*100).toFixed(1):0 }}%</p>
          <div class="fi-kpi-foot" style="margin-top:10px;">
            <span class="fi-badge fi-badge-up">
              <svg width="8" height="8" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><polyline points="18 15 12 9 6 15"/></svg>
              {{ allItems.filter(t=>t.transaction_type==='income').length }} lanç.
            </span>
            <span class="fi-kpi-compare">do total</span>
          </div>
        </div>

        <!-- saídas -->
        <div class="fi-card fi-kpi-sm">
          <div class="fi-kpi-flag" style="background:rgba(220,38,38,.1);">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#dc2626" stroke-width="2.5"><polyline points="6 9 12 15 18 9"/></svg>
          </div>
          <p class="fi-kpi-label" style="margin-top:10px;">Saídas</p>
          <p class="fi-kpi-num fi-sm-num">{{ fmt(expense) }}</p>
          <p class="fi-kpi-sub">{{ fmt(expense) }} / {{ income+expense>0?((expense/(income+expense))*100).toFixed(1):0 }}%</p>
          <div class="fi-kpi-foot" style="margin-top:10px;">
            <span class="fi-badge fi-badge-dn">
              <svg width="8" height="8" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><polyline points="6 9 12 15 18 9"/></svg>
              {{ allItems.filter(t=>t.transaction_type==='expense').length }} lanç.
            </span>
            <span class="fi-kpi-compare">do total</span>
          </div>
        </div>

        <!-- comissões -->
        <div class="fi-card fi-kpi-sm">
          <div class="fi-kpi-flag" style="background:rgba(217,119,6,.1);">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#d97706" stroke-width="2"><circle cx="12" cy="8" r="4"/><path d="M4 20c0-4 3.6-7 8-7s8 3 8 7"/></svg>
          </div>
          <p class="fi-kpi-label" style="margin-top:10px;">Comissões a pagar</p>
          <p :class="['fi-kpi-num','fi-sm-num', unpaidComm>0?'fi-amber':'fi-green']">{{ fmt(unpaidComm) }}</p>
          <p class="fi-kpi-sub">{{ commissions.filter(c=>!c.paid).length }} pendentes</p>
          <div class="fi-kpi-foot" style="margin-top:10px;">
            <span :class="['fi-badge', unpaidComm>0?'fi-badge-dn':'fi-badge-up']">
              <svg width="8" height="8" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><polyline v-if="unpaidComm>0" points="6 9 12 15 18 9"/><polyline v-else points="18 15 12 9 6 15"/></svg>
              {{ commissions.filter(c=>!c.paid).length }} pend.
            </span>
            <span class="fi-kpi-compare">este mês</span>
          </div>
        </div>

      </div>

      <!-- chart + top assets -->
      <div class="fi-mid">

        <div class="fi-card fi-chart-card">
          <div class="fi-card-hd">
            <p class="fi-card-title">Movimentação do Período</p>
            <div class="fi-legend">
              <span class="fi-leg-dot" style="background:#6366f1;"></span><span class="fi-leg-lbl">Entradas</span>
              <span class="fi-leg-dot" style="background:rgb(var(--slate-7));opacity:.6;"></span><span class="fi-leg-lbl">Saídas</span>
            </div>
          </div>
          <div v-if="uiFlags.isFetching" class="fi-sk" style="height:160px;"/>
          <div v-else-if="!chart" class="fi-empty" style="padding:48px 0;">Sem dados neste período.</div>
          <template v-else>
            <div style="display:flex;gap:0;align-items:stretch;">
              <div class="fi-yl-col">
                <span v-for="g in [...chart.grid].reverse()" :key="g.l" class="fi-yl">{{ g.l }}</span>
              </div>
              <div style="flex:1;">
                <svg :viewBox="`0 0 ${chart.W} ${chart.H}`" style="width:100%;height:180px;" preserveAspectRatio="none">
                  <line v-for="g in chart.grid" :key="g.l" x1="0" :x2="chart.W" :y1="g.y" :y2="g.y" stroke="rgb(var(--border-weak))" stroke-width="0.8"/>
                  <path :d="chart.iArea" fill="rgba(99,102,241,.06)"/>
                  <path :d="chart.eD" fill="none" stroke="rgb(var(--slate-7))" stroke-width="1.5" stroke-dasharray="4 3" stroke-linejoin="round" stroke-linecap="round" opacity="0.6"/>
                  <path :d="chart.iD" fill="none" stroke="#6366f1" stroke-width="2.2" stroke-linejoin="round" stroke-linecap="round"/>
                </svg>
              </div>
            </div>
            <div class="fi-chart-ft">
              <span>{{ periodStart }}</span>
              <span>{{ periodEnd }}</span>
            </div>
          </template>
        </div>

        <!-- top assets -->
        <div class="fi-card fi-cats-card">
          <div class="fi-card-hd">
            <p class="fi-card-title">Por Categoria</p>
            <span class="fi-see-all" @click="activeTab='transactions'">Ver tudo</span>
          </div>
          <div class="fi-cats-hdr">
            <span>Nome</span><span>Valor</span><span>%</span>
          </div>
          <p v-if="!cats.length" class="fi-empty" style="padding:24px 0;">Sem dados.</p>
          <div v-for="(c,i) in cats" :key="c.name" class="fi-cat-row">
            <div class="fi-cat-info">
              <span class="fi-cat-dot" :style="{background:CAT_COLORS[i]}"></span>
              <div style="overflow:hidden;">
                <p class="fi-cat-name">{{ c.name }}</p>
                <p class="fi-cat-sub">{{ c.isIncome ? 'Receita' : 'Despesa' }}</p>
              </div>
            </div>
            <span class="fi-cat-val">{{ fmt(c.v) }}</span>
            <span :class="['fi-cat-ret', c.isIncome?'fi-ret-up':'fi-ret-dn']">
              {{ catsTotal>0 ? ((c.v/catsTotal)*100).toFixed(1):0 }}%
              <svg width="8" height="8" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><polyline v-if="c.isIncome" points="18 15 12 9 6 15"/><polyline v-else points="6 9 12 15 18 9"/></svg>
            </span>
          </div>
        </div>

      </div>

      <!-- bottom row -->
      <div class="fi-bot">

        <!-- transactions -->
        <div class="fi-card" style="padding:0;overflow:hidden;">
          <div class="fi-card-hd" style="padding:18px 20px 14px;">
            <p class="fi-card-title">Transações</p>
            <span class="fi-see-all" @click="activeTab='transactions'">Ver todas</span>
          </div>
          <div class="fi-tx-hdr">
            <span>Descrição</span>
            <span style="text-align:center;">Tipo</span>
            <span style="text-align:right;">Valor</span>
          </div>
          <p v-if="!recentTx.length" class="fi-empty" style="padding:32px 20px;">Nenhum lançamento ainda.</p>
          <div v-for="t in recentTx" :key="t.id" class="fi-tx-row">
            <div class="fi-tx-prov">
              <div class="fi-tx-ico" :style="{background: t.transaction_type==='income'?'rgba(99,102,241,.1)':'rgba(220,38,38,.08)'}">
                <span :style="{color: t.transaction_type==='income'?'#6366f1':'#dc2626', fontSize:'11px', fontWeight:'700'}">{{ (t.description||'?').charAt(0).toUpperCase() }}</span>
              </div>
              <div style="overflow:hidden;">
                <p class="fi-tx-name">{{ t.description }}</p>
                <p class="fi-tx-sub">{{ fmtDate(t.date) }}</p>
              </div>
            </div>
            <div style="display:flex;justify-content:center;">
              <span :class="['fi-chip', t.transaction_type==='income'?'fi-chip-buy':'fi-chip-sell']">
                {{ t.transaction_type==='income' ? 'Entrada' : 'Saída' }}
              </span>
            </div>
            <span :class="['fi-tx-amt', t.transaction_type==='income'?'fi-green':'fi-red']">
              {{ t.transaction_type==='income'?'+':'−' }}{{ fmt(t.amount) }}
            </span>
          </div>
        </div>

        <!-- types -->
        <div class="fi-card" style="display:flex;flex-direction:column;">
          <div class="fi-card-hd">
            <p class="fi-card-title">Métodos de Pgto</p>
            <span class="fi-see-all" @click="activeTab='transactions'">Ver tudo</span>
          </div>
          <div class="fi-seg-bar">
            <template v-if="income > 0">
              <div v-for="m in METHODS" :key="m.key" class="fi-seg"
                :style="{flex: byMethod[m.key]||0.001, background: m.color}"/>
            </template>
            <div v-else class="fi-seg" style="flex:1;background:rgb(var(--surface-2));"/>
          </div>
          <div class="fi-method-list">
            <div v-for="m in METHODS" :key="m.key" class="fi-method-row">
              <div style="display:flex;align-items:center;gap:8px;">
                <span class="fi-method-dot" :style="{background:m.color}"></span>
                <span class="fi-method-name">{{ m.label }}</span>
              </div>
              <div style="display:flex;align-items:center;gap:6px;">
                <span class="fi-method-val">{{ fmt(byMethod[m.key]??0) }}</span>
                <span class="fi-method-pct">({{ income>0?((byMethod[m.key]/income)*100).toFixed(1):'0.0' }}%)</span>
              </div>
            </div>
          </div>
        </div>

        <!-- members / commissions donut -->
        <div class="fi-card" style="display:flex;flex-direction:column;">
          <div class="fi-card-hd">
            <p class="fi-card-title">Comissões</p>
            <span class="fi-see-all" @click="activeTab='comissoes'">Ver todas</span>
          </div>
          <div v-if="!donutSegs.length" class="fi-empty" style="padding:24px 0;">Sem dados.</div>
          <template v-else>
            <div class="fi-donut-wrap">
              <svg viewBox="0 0 100 100" style="width:100%;height:100%;">
                <circle cx="50" cy="50" r="38" fill="none" stroke="rgb(var(--surface-2))" stroke-width="12"/>
                <circle v-for="seg in donutSegs" :key="seg.professional_id"
                  cx="50" cy="50" r="38" fill="none"
                  :stroke="seg.color" stroke-width="12"
                  :stroke-dasharray="`${seg.dash} ${238.76 - seg.dash}`"
                  :stroke-dashoffset="-seg.offset"
                  transform="rotate(-90 50 50)"/>
              </svg>
              <div class="fi-donut-center">
                <p class="fi-donut-pct">{{ commissionSummary?.total_amount>0 ? ((commissionSummary.paid_amount/commissionSummary.total_amount)*100).toFixed(0):0 }}%</p>
                <p class="fi-donut-sub">pago</p>
              </div>
            </div>
            <div class="fi-comm-list">
              <div v-for="seg in donutSegs" :key="seg.professional_id" class="fi-comm-row">
                <div class="fi-comm-ico" :style="{background: seg.color+'1a', color: seg.color}">
                  {{ (seg.professional_name||'?').charAt(0).toUpperCase() }}
                </div>
                <div style="flex:1;min-width:0;">
                  <p class="fi-tx-name">{{ seg.professional_name||'—' }}</p>
                  <p class="fi-tx-sub">{{ fmt(seg.unpaid_amount) }} pendente</p>
                </div>
                <span style="font-size:12px;font-weight:700;flex-shrink:0;" :style="{color: seg.color}">{{ seg.pct }}%</span>
              </div>
            </div>
          </template>
        </div>

      </div>
    </div>

    <!-- ── TRANSACTIONS TAB ── -->
    <div v-if="activeTab==='transactions'" class="fi-body">
      <div class="fi-card" style="padding:0;overflow:hidden;">
        <div style="display:flex;align-items:center;justify-content:space-between;gap:16px;padding:18px 20px 14px;">
          <div>
            <p class="fi-card-title" style="margin:0;">Todas as Transações</p>
            <p class="fi-tx-sub" style="margin:3px 0 0;">{{ periodRange }}</p>
          </div>
          <div style="display:flex;gap:8px;align-items:center;">
            <div class="fi-ftabs">
              <button v-for="[v,l] in [['all','Todos'],['income','Entradas'],['expense','Saídas']]" :key="v"
                :class="['fi-ftab', txFilter===v&&'fi-ftab-on']" @click="txFilter=v">{{ l }}</button>
            </div>
            <div style="position:relative;">
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="fi-search-ico"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
              <input v-model="txSearch" placeholder="Buscar…" class="fi-search"/>
            </div>
          </div>
        </div>
        <table class="fi-tbl">
          <thead><tr>
            <th class="fi-th">Descrição</th><th class="fi-th">Data</th><th class="fi-th">Categoria</th>
            <th class="fi-th">Método</th><th class="fi-th">Tipo</th><th class="fi-th fi-th-r">Valor</th><th class="fi-th"></th>
          </tr></thead>
          <tbody>
            <tr v-if="!filteredTx.length"><td colspan="7" class="fi-td fi-empty" style="padding:40px;">Nenhum resultado.</td></tr>
            <tr v-for="t in filteredTx" :key="t.id" class="fi-tr">
              <td class="fi-td">
                <div style="display:flex;align-items:center;gap:10px;">
                  <div class="fi-tx-ico" :style="{background:t.transaction_type==='income'?'rgba(99,102,241,.1)':'rgba(220,38,38,.08)'}">
                    <span :style="{color:t.transaction_type==='income'?'#6366f1':'#dc2626',fontSize:'11px',fontWeight:'700'}">{{ (t.description||'?').charAt(0).toUpperCase() }}</span>
                  </div>
                  <span class="fi-tx-name">{{ t.description }}</span>
                </div>
              </td>
              <td class="fi-td" style="color:rgb(var(--slate-7));font-size:12px;">{{ fmtDate(t.date) }}</td>
              <td class="fi-td"><span v-if="t.category" class="fi-cat-tag">{{ t.category }}</span><span v-else style="color:rgb(var(--slate-7));font-size:12px;">—</span></td>
              <td class="fi-td" style="color:rgb(var(--slate-7));font-size:12px;">{{ t.payment_method?{dinheiro:'Dinheiro',pix:'Pix',debito:'Débito',credito:'Crédito'}[t.payment_method]:'—' }}</td>
              <td class="fi-td"><span :class="['fi-chip',t.transaction_type==='income'?'fi-chip-buy':'fi-chip-sell']">{{ t.transaction_type==='income'?'Entrada':'Saída' }}</span></td>
              <td class="fi-td fi-th-r"><span :class="['fi-tx-amt',t.transaction_type==='income'?'fi-green':'fi-red']">{{ t.transaction_type==='income'?'+':'−' }}{{ fmt(t.amount) }}</span></td>
              <td class="fi-td fi-th-r"><button class="fi-del" @click="delItem=t"><svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/><path d="M10 11v6M14 11v6"/></svg></button></td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- ── COMMISSIONS TAB ── -->
    <div v-if="activeTab==='comissoes'" class="fi-body">
      <div v-if="commissionSummary" class="fi-kpi-row">
        <div class="fi-card fi-kpi-hero">
          <p class="fi-kpi-label">Total de comissões</p>
          <p class="fi-kpi-num" style="margin-top:8px;">{{ fmt(commissionSummary.total_amount) }}</p>
          <p class="fi-tx-sub" style="margin-top:6px;">{{ commissions.length }} comissões — {{ selectedPeriod }}</p>
        </div>
        <div class="fi-card fi-kpi-sm"><p class="fi-kpi-label">Pagas</p><p class="fi-kpi-num fi-sm-num fi-green" style="margin-top:8px;">{{ fmt(commissionSummary.paid_amount) }}</p><p class="fi-kpi-sub">{{ commissions.filter(c=>c.paid).length }} pagas</p></div>
        <div class="fi-card fi-kpi-sm"><p class="fi-kpi-label">A pagar</p><p :class="['fi-kpi-num','fi-sm-num',+commissionSummary.unpaid_amount>0?'fi-amber':'fi-green']" style="margin-top:8px;">{{ fmt(commissionSummary.unpaid_amount) }}</p><p class="fi-kpi-sub">{{ commissions.filter(c=>!c.paid).length }} pendentes</p></div>
        <div class="fi-card fi-kpi-sm" style="text-align:center;display:flex;flex-direction:column;justify-content:center;align-items:center;"><p class="fi-kpi-label">Taxa paga</p><p class="fi-kpi-num" style="margin-top:8px;font-size:26px;">{{ commissionSummary.total_amount>0?((commissionSummary.paid_amount/commissionSummary.total_amount)*100).toFixed(0):0 }}%</p></div>
      </div>
      <div class="fi-card" style="padding:0;overflow:hidden;">
        <div style="padding:18px 20px 14px;"><p class="fi-card-title" style="margin:0;">Comissões individuais</p></div>
        <p v-if="!commissions.length" class="fi-empty" style="padding:40px 0;">Nenhuma comissão neste período.</p>
        <table v-else class="fi-tbl">
          <thead><tr><th class="fi-th">Profissional</th><th class="fi-th">Período</th><th class="fi-th fi-th-r">%</th><th class="fi-th fi-th-r">Valor</th><th class="fi-th">Status</th><th class="fi-th"></th></tr></thead>
          <tbody>
            <tr v-for="c in commissions" :key="c.id" class="fi-tr">
              <td class="fi-td">
                <div style="display:flex;align-items:center;gap:10px;">
                  <div class="fi-tx-ico" style="background:rgba(99,102,241,.1);"><span style="color:#6366f1;font-size:11px;font-weight:700;">{{ (c.professional?.name||'?').charAt(0).toUpperCase() }}</span></div>
                  <span class="fi-tx-name">{{ c.professional?.name??'—' }}</span>
                </div>
              </td>
              <td class="fi-td" style="color:rgb(var(--slate-7));font-size:12px;">{{ c.period }}</td>
              <td class="fi-td fi-th-r" style="color:rgb(var(--slate-7));font-size:12px;">{{ c.percentage }}%</td>
              <td class="fi-td fi-th-r" style="font-weight:700;">{{ fmt(c.amount) }}</td>
              <td class="fi-td">
                <span v-if="c.paid" class="fi-chip fi-chip-buy" style="display:inline-flex;align-items:center;gap:4px;"><svg width="8" height="8" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><path d="M20 6L9 17l-5-5"/></svg>Pago</span>
                <span v-else style="color:#d97706;font-size:11px;font-weight:600;">Pendente</span>
              </td>
              <td class="fi-td fi-th-r"><button v-if="!c.paid" class="fi-pay-btn" :disabled="savingComm===c.id" @click="markPaid(c)">{{ savingComm===c.id?'…':'Marcar pago' }}</button></td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- ── MODAL NEW ── -->
    <Teleport to="body">
      <div v-if="showModal" class="fi-overlay" @click.self="showModal=false">
        <div class="fi-modal">
          <div class="fi-modal-hd">
            <div><p class="fi-modal-title">Novo lançamento</p><p class="fi-tx-sub">{{ periodRange }}</p></div>
            <button class="fi-modal-x" @click="showModal=false"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg></button>
          </div>
          <div class="fi-modal-bd">
            <div v-if="mErr" style="padding:8px 12px;background:rgba(220,38,38,.08);color:#dc2626;font-size:12px;border-radius:6px;">{{ mErr }}</div>
            <div class="fi-type-row">
              <button v-for="[v,l] in [['income','↑ Entrada'],['expense','↓ Saída']]" :key="v"
                :class="['fi-type-btn', mForm.type===v&&(v==='income'?'fi-type-in':'fi-type-out')]"
                type="button" @click="mForm.type=v;mForm.cat=''">{{ l }}</button>
            </div>
            <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
              <div style="grid-column:1/-1;" class="fi-field"><label class="fi-lbl">Descrição *</label><input v-model="mForm.desc" class="fi-inp" placeholder="Ex: Corte João Silva"/></div>
              <div class="fi-field"><label class="fi-lbl">Valor (R$) *</label><input v-model="mForm.amount" type="number" step="0.01" min="0" class="fi-inp" placeholder="0,00"/></div>
              <div class="fi-field"><label class="fi-lbl">Data</label><input v-model="mForm.date" type="date" class="fi-inp"/></div>
              <div style="grid-column:1/-1;" class="fi-field"><label class="fi-lbl">Categoria</label><select v-model="mForm.cat" class="fi-inp"><option value="">Selecionar…</option><option v-for="c in mCats" :key="c" :value="c">{{ c }}</option></select></div>
            </div>
          </div>
          <div class="fi-modal-ft">
            <button class="fi-btn-sec" @click="showModal=false">Cancelar</button>
            <button class="fi-btn-pri" :disabled="saving" @click="submitModal">{{ saving?'Salvando…':'Salvar' }}</button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- ── MODAL DELETE ── -->
    <Teleport to="body">
      <div v-if="delItem" class="fi-overlay" @click.self="delItem=null">
        <div class="fi-modal" style="max-width:320px;">
          <div style="padding:28px 22px;text-align:center;">
            <div class="fi-del-ico"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="color:rgb(var(--slate-7))"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/><path d="M10 11v6M14 11v6"/></svg></div>
            <p style="margin:0 0 6px;font-size:15px;font-weight:700;">Remover lançamento?</p>
            <p class="fi-tx-sub" style="margin:0;">Esta ação não pode ser desfeita.</p>
            <div style="display:flex;gap:10px;margin-top:18px;">
              <button class="fi-btn-sec" style="flex:1;" @click="delItem=null">Cancelar</button>
              <button class="fi-btn-pri" style="flex:1;" :disabled="deleting" @click="confirmDel">{{ deleting?'…':'Remover' }}</button>
            </div>
          </div>
        </div>
      </div>
    </Teleport>

  </div>
</template>

<style scoped>
.fi-root {
  display: flex; flex-direction: column;
  width: 100%; height: 100%; min-height: 0; overflow-y: auto;
  background: rgb(var(--background-color));
  color: rgb(var(--slate-12));
  font-family: inherit;
}

/* TOPBAR */
.fi-bar   { display:flex; align-items:center; justify-content:space-between; gap:16px; padding:20px 28px 0; flex-shrink:0; }
.fi-bar-l { display:flex; align-items:center; gap:18px; }
.fi-bar-r { display:flex; align-items:center; gap:10px; flex-shrink:0; }
.fi-title { font-size:20px; font-weight:700; letter-spacing:-.4px; }

.fi-tabs { display:flex; background:rgb(var(--surface-2)); border-radius:8px; padding:3px; gap:2px; border:1px solid rgb(var(--border-weak)); }
.fi-tab  { padding:5px 14px; border-radius:6px; border:none; background:transparent; font-size:12px; font-weight:500; color:rgb(var(--slate-8)); cursor:pointer; font-family:inherit; transition:all .12s; }
.fi-tab:hover { color:rgb(var(--slate-12)); }
.fi-tab-on { background:rgb(var(--surface-1)); color:rgb(var(--slate-12)); font-weight:600; box-shadow:0 1px 3px rgba(0,0,0,.1); }

.fi-mnav { display:flex; align-items:center; background:rgb(var(--surface-1)); border:1px solid rgb(var(--border-strong)); border-radius:8px; overflow:hidden; }
.fi-mnav button { display:flex; align-items:center; justify-content:center; width:30px; height:32px; border:none; background:transparent; cursor:pointer; color:rgb(var(--slate-8)); transition:background .1s; }
.fi-mnav button:hover:not(:disabled) { background:rgb(var(--surface-2)); color:rgb(var(--slate-12)); }
.fi-mnav button:disabled { opacity:.3; cursor:not-allowed; }
.fi-mnav span { padding:0 14px; font-size:12px; font-weight:600; color:rgb(var(--slate-12)); border-left:1px solid rgb(var(--border-weak)); border-right:1px solid rgb(var(--border-weak)); min-width:132px; text-align:center; line-height:32px; }

.fi-btn-new { display:inline-flex; align-items:center; gap:6px; height:32px; padding:0 14px; border-radius:8px; background:rgb(var(--slate-12)); color:rgb(var(--background-color)); font-size:12px; font-weight:600; border:none; cursor:pointer; font-family:inherit; transition:opacity .15s; }
.fi-btn-new:hover { opacity:.82; }

/* BODY */
.fi-body { padding:18px 28px 40px; display:flex; flex-direction:column; gap:14px; }

/* CARD */
.fi-card { background:rgb(var(--surface-1)); border:1px solid rgb(var(--border-weak)); border-radius:14px; padding:22px 24px; box-shadow:0 1px 3px rgba(0,0,0,.06), 0 2px 10px rgba(0,0,0,.04); }
.fi-card-hd { display:flex; align-items:center; justify-content:space-between; margin-bottom:14px; }
.fi-card-title { margin:0; font-size:14px; font-weight:700; }
.fi-see-all { font-size:12px; font-weight:600; color:#6366f1; cursor:pointer; }
.fi-see-all:hover { text-decoration:underline; }

/* KPI */
.fi-kpi-row { display:grid; grid-template-columns:repeat(4,1fr); gap:12px; }
.fi-kpi-hero { display:flex; flex-direction:column; }
.fi-kpi-sm   { display:flex; flex-direction:column; }
.fi-kpi-flag { width:36px; height:36px; border-radius:10px; display:flex; align-items:center; justify-content:center; flex-shrink:0; }
.fi-kpi-label   { margin:0; font-size:12px; color:rgb(var(--slate-8)); font-weight:500; }
.fi-kpi-num     { margin:0; font-size:30px; font-weight:700; letter-spacing:-.8px; font-variant-numeric:tabular-nums; line-height:1.1; }
.fi-sm-num      { font-size:22px; margin-top:8px; }
.fi-kpi-sub     { margin:3px 0 0; font-size:11px; color:rgb(var(--slate-7)); }
.fi-kpi-compare { margin:0; font-size:11px; color:rgb(var(--slate-7)); }
.fi-kpi-hero-val { display:flex; align-items:center; gap:10px; margin-top:8px; }
.fi-kpi-foot { display:flex; align-items:center; gap:6px; margin-top:12px; }
.fi-muted-icon { color:rgb(var(--slate-7)); }

.fi-badge { display:inline-flex; align-items:center; gap:3px; padding:3px 8px; border-radius:99px; font-size:11px; font-weight:700; }
.fi-badge-up { background:rgba(22,163,74,.1); color:#16a34a; }
.fi-badge-dn { background:rgba(220,38,38,.08); color:#dc2626; }

.fi-green { color:#16a34a !important; }
.fi-red   { color:#dc2626 !important; }
.fi-amber { color:#d97706 !important; }

/* CHART ROW */
.fi-mid { display:grid; grid-template-columns:1fr 300px; gap:14px; }
.fi-chart-card { display:flex; flex-direction:column; }
.fi-legend { display:flex; align-items:center; gap:12px; }
.fi-leg-dot { width:8px; height:8px; border-radius:50%; flex-shrink:0; }
.fi-leg-lbl { font-size:11px; color:rgb(var(--slate-7)); margin-left:3px; }
.fi-yl-col { display:flex; flex-direction:column; justify-content:space-between; padding:4px 8px 4px 0; min-width:36px; }
.fi-yl { font-size:9px; color:rgb(var(--slate-7)); text-align:right; white-space:nowrap; line-height:1; }
.fi-chart-ft { display:flex; justify-content:space-between; margin-top:8px; font-size:11px; color:rgb(var(--slate-7)); }

/* TOP ASSETS style */
.fi-cats-card { display:flex; flex-direction:column; }
.fi-cats-hdr  { display:grid; grid-template-columns:1fr 88px 42px; gap:8px; padding-bottom:8px; border-bottom:1px solid rgb(var(--border-weak)); font-size:10px; font-weight:700; text-transform:uppercase; letter-spacing:.07em; color:rgb(var(--slate-7)); }
.fi-cat-row   { display:grid; grid-template-columns:1fr 88px 42px; gap:8px; align-items:center; padding:8px 0; border-bottom:1px solid rgb(var(--border-weak) / .3); }
.fi-cat-row:last-child { border-bottom:none; }
.fi-cat-info  { display:flex; align-items:center; gap:8px; overflow:hidden; }
.fi-cat-dot   { width:7px; height:7px; border-radius:50%; flex-shrink:0; }
.fi-cat-name  { margin:0; font-size:12px; font-weight:600; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
.fi-cat-sub   { margin:1px 0 0; font-size:10px; color:rgb(var(--slate-7)); }
.fi-cat-val   { font-size:12px; font-weight:600; color:rgb(var(--slate-10)); text-align:right; font-variant-numeric:tabular-nums; white-space:nowrap; }
.fi-cat-ret   { font-size:11px; font-weight:700; display:flex; align-items:center; justify-content:flex-end; gap:2px; white-space:nowrap; }
.fi-ret-up    { color:#16a34a; }
.fi-ret-dn    { color:#dc2626; }

/* BOTTOM ROW */
.fi-bot { display:grid; grid-template-columns:1fr 228px 218px; gap:14px; }

/* transaction list */
.fi-tx-hdr  { display:grid; grid-template-columns:1fr 90px 110px; gap:8px; padding:6px 20px 8px; font-size:10px; font-weight:700; text-transform:uppercase; letter-spacing:.07em; color:rgb(var(--slate-7)); border-bottom:1px solid rgb(var(--border-weak)); }
.fi-tx-row  { display:grid; grid-template-columns:1fr 90px 110px; gap:8px; align-items:center; padding:10px 20px; border-bottom:1px solid rgb(var(--border-weak) / .4); transition:background .1s; }
.fi-tx-row:last-child { border-bottom:none; }
.fi-tx-row:hover { background:rgb(var(--slate-12) / .025); }
.fi-tx-prov { display:flex; align-items:center; gap:10px; overflow:hidden; }
.fi-tx-ico  { width:30px; height:30px; border-radius:8px; display:flex; align-items:center; justify-content:center; flex-shrink:0; }
.fi-tx-name { margin:0; font-size:12px; font-weight:600; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; max-width:180px; }
.fi-tx-sub  { margin:0; font-size:10px; color:rgb(var(--slate-7)); }
.fi-tx-amt  { font-size:12px; font-weight:700; font-variant-numeric:tabular-nums; text-align:right; white-space:nowrap; }
.fi-chip    { display:inline-block; padding:3px 10px; border-radius:5px; font-size:11px; font-weight:700; white-space:nowrap; }
.fi-chip-buy  { background:rgba(99,102,241,.1); color:#6366f1; }
.fi-chip-sell { background:rgba(220,38,38,.08); color:#dc2626; }

/* methods */
.fi-seg-bar    { height:7px; border-radius:99px; overflow:hidden; display:flex; gap:2px; margin-bottom:16px; }
.fi-seg        { height:100%; min-width:3px; border-radius:3px; }
.fi-method-list { display:flex; flex-direction:column; gap:11px; }
.fi-method-row  { display:flex; align-items:center; justify-content:space-between; }
.fi-method-dot  { width:7px; height:7px; border-radius:50%; flex-shrink:0; }
.fi-method-name { font-size:12px; color:rgb(var(--slate-10)); font-weight:500; }
.fi-method-val  { font-size:12px; font-weight:700; font-variant-numeric:tabular-nums; }
.fi-method-pct  { font-size:11px; color:rgb(var(--slate-7)); min-width:40px; text-align:right; }

/* donut */
.fi-donut-wrap   { position:relative; width:88px; height:88px; margin:0 auto 14px; }
.fi-donut-center { position:absolute; inset:0; display:flex; flex-direction:column; align-items:center; justify-content:center; }
.fi-donut-pct    { margin:0; font-size:16px; font-weight:700; }
.fi-donut-sub    { margin:0; font-size:10px; color:rgb(var(--slate-7)); }
.fi-comm-list    { display:flex; flex-direction:column; gap:10px; }
.fi-comm-row     { display:flex; align-items:center; gap:10px; }
.fi-comm-ico     { width:28px; height:28px; border-radius:7px; display:flex; align-items:center; justify-content:center; font-size:11px; font-weight:700; flex-shrink:0; }

/* table */
.fi-tbl { width:100%; border-collapse:collapse; }
.fi-th  { padding:10px 14px; text-align:left; font-size:10px; font-weight:700; text-transform:uppercase; letter-spacing:.07em; color:rgb(var(--slate-7)); background:rgb(var(--surface-2)); border-bottom:1px solid rgb(var(--border-weak)); white-space:nowrap; }
.fi-th-r { text-align:right; }
.fi-tr  { border-bottom:1px solid rgb(var(--border-weak) / .4); transition:background .1s; }
.fi-tr:last-child { border-bottom:none; }
.fi-tr:hover { background:rgb(var(--slate-12) / .025); }
.fi-td  { padding:11px 14px; font-size:12px; color:rgb(var(--slate-10)); vertical-align:middle; }
.fi-empty  { text-align:center; color:rgb(var(--slate-7)); font-size:12px; }
.fi-cat-tag { font-size:11px; color:rgb(var(--slate-8)); background:rgb(var(--surface-2)); border:1px solid rgb(var(--border-weak)); padding:2px 8px; border-radius:4px; white-space:nowrap; }
.fi-del { background:none; border:none; cursor:pointer; padding:4px; color:rgb(var(--slate-6)); border-radius:5px; display:flex; transition:all .1s; }
.fi-del:hover { color:rgb(var(--slate-9)); background:rgb(var(--surface-2)); }
.fi-pay-btn { height:25px; padding:0 10px; border-radius:5px; border:1px solid rgb(var(--border-strong)); color:rgb(var(--slate-10)); background:transparent; font-size:11px; font-weight:600; cursor:pointer; font-family:inherit; white-space:nowrap; transition:background .1s; }
.fi-pay-btn:hover:not(:disabled) { background:rgb(var(--surface-2)); }
.fi-pay-btn:disabled { opacity:.4; cursor:not-allowed; }

/* filter tabs + search */
.fi-ftabs { display:flex; background:rgb(var(--surface-2)); border-radius:7px; padding:3px; gap:1px; border:1px solid rgb(var(--border-weak)); }
.fi-ftab  { padding:4px 11px; border-radius:5px; border:none; cursor:pointer; font-size:11px; font-weight:500; font-family:inherit; background:transparent; color:rgb(var(--slate-8)); transition:all .12s; }
.fi-ftab:hover { color:rgb(var(--slate-12)); }
.fi-ftab-on { background:rgb(var(--surface-1)); color:rgb(var(--slate-12)); font-weight:700; box-shadow:0 1px 2px rgba(0,0,0,.07); }
.fi-search-ico { position:absolute; left:9px; top:50%; transform:translateY(-50%); pointer-events:none; color:rgb(var(--slate-7)); }
.fi-search { height:30px; padding:0 10px 0 28px; border-radius:7px; font-size:12px; border:1px solid rgb(var(--border-strong)); background:rgb(var(--surface-1)); color:rgb(var(--slate-12)); outline:none; font-family:inherit; width:160px; }
.fi-search:focus { border-color:#6366f1; }

/* skeleton */
.fi-sk { background:rgb(var(--surface-2)); animation:fi-pulse 1.5s ease infinite; border-radius:8px; }
@keyframes fi-pulse { 0%,100%{opacity:1} 50%{opacity:.4} }

/* modals */
.fi-overlay  { position:fixed; inset:0; z-index:9999; display:flex; align-items:center; justify-content:center; padding:16px; background:rgba(0,0,0,.45); backdrop-filter:blur(4px); }
.fi-modal    { width:100%; max-width:430px; max-height:90vh; background:rgb(var(--surface-1)); border:1px solid rgb(var(--border-strong)); border-radius:14px; box-shadow:0 24px 60px rgba(0,0,0,.22); display:flex; flex-direction:column; overflow:hidden; }
.fi-modal-hd { display:flex; align-items:flex-start; justify-content:space-between; padding:18px 20px 14px; border-bottom:1px solid rgb(var(--border-weak)); }
.fi-modal-title { margin:0; font-size:15px; font-weight:700; }
.fi-modal-x  { background:none; border:none; cursor:pointer; color:rgb(var(--slate-7)); display:flex; padding:3px; border-radius:5px; }
.fi-modal-x:hover { background:rgb(var(--surface-2)); }
.fi-modal-bd { flex:1; overflow-y:auto; padding:16px 20px; display:flex; flex-direction:column; gap:14px; }
.fi-modal-ft { display:flex; justify-content:flex-end; gap:8px; padding:12px 20px; border-top:1px solid rgb(var(--border-weak)); }
.fi-type-row { display:grid; grid-template-columns:1fr 1fr; gap:8px; }
.fi-type-btn { padding:10px; border-radius:8px; border:1.5px solid rgb(var(--border-strong)); background:rgb(var(--surface-2)); color:rgb(var(--slate-9)); font-size:13px; font-weight:600; font-family:inherit; cursor:pointer; transition:all .12s; }
.fi-type-in  { border-color:#6366f1; background:rgba(99,102,241,.1); color:#6366f1; }
.fi-type-out { border-color:#dc2626; background:rgba(220,38,38,.08); color:#dc2626; }
.fi-field    { display:flex; flex-direction:column; gap:5px; }
.fi-lbl      { font-size:10px; font-weight:700; text-transform:uppercase; letter-spacing:.07em; color:rgb(var(--slate-7)); }
.fi-inp      { height:34px; padding:0 10px; border-radius:7px; font-size:13px; font-family:inherit; border:1px solid rgb(var(--border-strong)); background:rgb(var(--background-color)); color:rgb(var(--slate-12)); outline:none; width:100%; box-sizing:border-box; }
.fi-inp:focus { border-color:#6366f1; box-shadow:0 0 0 3px rgba(99,102,241,.1); }
.fi-btn-sec  { height:33px; padding:0 16px; border-radius:7px; font-size:12px; font-weight:600; border:1px solid rgb(var(--border-strong)); background:transparent; color:rgb(var(--slate-10)); cursor:pointer; font-family:inherit; transition:background .1s; }
.fi-btn-sec:hover { background:rgb(var(--surface-2)); }
.fi-btn-pri  { height:33px; padding:0 18px; border-radius:7px; font-size:12px; font-weight:700; background:rgb(var(--slate-12)); color:rgb(var(--background-color)); border:none; cursor:pointer; font-family:inherit; transition:opacity .15s; }
.fi-btn-pri:hover:not(:disabled) { opacity:.82; }
.fi-btn-pri:disabled { opacity:.4; cursor:not-allowed; }
.fi-del-ico  { width:40px; height:40px; border-radius:10px; background:rgb(var(--surface-2)); border:1px solid rgb(var(--border-weak)); display:flex; align-items:center; justify-content:center; margin:0 auto 12px; }
</style>
