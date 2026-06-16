<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { servicesAPI } from 'dashboard/api/appointments';

const store = useStore();
const emit  = defineEmits(['close']);

const products = computed(() => store.getters['products/getList'] ?? []);
const uiFlags  = computed(() => store.getters['products/getUIFlags'] ?? {});

onMounted(() => {
  store.dispatch('products/fetchList');
});

// ── search ─────────────────────────────────────────────────────────────────
const search = ref('');
const filtered = computed(() => {
  const q = search.value.toLowerCase();
  return q ? products.value.filter(p => p.name?.toLowerCase().includes(q)) : products.value;
});

// ── CRUD ───────────────────────────────────────────────────────────────────
const modal = ref(null);
const form  = ref({});

function openNew() {
  form.value = { name: '', description: '', price: '', duration_minutes: 30, active: true };
  modal.value = {};
}
function openEdit(p) {
  form.value = { name: p.name, description: p.description || '', price: p.price || '', duration_minutes: p.duration_minutes || 30, active: p.active !== false };
  modal.value = p;
}
async function save() {
  if (!form.value.name?.trim()) { useAlert('Nome é obrigatório.'); return; }
  try {
    if (modal.value?.id) {
      await store.dispatch('products/updateProduct', { id: modal.value.id, ...form.value });
    } else {
      await store.dispatch('products/createProduct', form.value);
    }
    useAlert('Salvo!'); modal.value = null;
  } catch { useAlert('Erro ao salvar.'); }
}
async function del(p) {
  if (!confirm(`Remover "${p.name}"?`)) return;
  try { await store.dispatch('products/deleteProduct', p.id); useAlert('Removido.'); }
  catch { useAlert('Erro.'); }
}
</script>

<template>
  <div class="cfg-backdrop" @click="emit('close')" />

  <div class="cfg-drawer">
    <!-- Header -->
    <div class="cfg-header">
      <div class="cfg-header-title">
        <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/></svg>
        Serviços / Produtos
      </div>
      <div style="display:flex;gap:8px;align-items:center">
        <button class="cfg-btn-primary" @click="openNew">
          <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
          Novo
        </button>
        <button class="cfg-close" @click="emit('close')">
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
        </button>
      </div>
    </div>

    <!-- Body -->
    <div class="cfg-body">
      <p class="cfg-note">Produtos e serviços disponíveis para selecionar ao criar um agendamento. Os mesmos itens da aba Produtos em Configurações.</p>

      <div class="cfg-search-wrap">
        <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="flex-shrink:0;color:#475569"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/></svg>
        <input v-model="search" class="cfg-search-inp" placeholder="Buscar..." />
      </div>

      <div v-if="uiFlags.isFetching && !products.length" style="color:#475569;font-size:13px;padding:20px 0;text-align:center">Carregando...</div>

      <div v-else-if="filtered.length === 0" class="cfg-empty">
        <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" opacity=".3"><path d="M6 2 3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z"/><line x1="3" y1="6" x2="21" y2="6"/><path d="M16 10a4 4 0 0 1-8 0"/></svg>
        <p>{{ search ? 'Nenhum resultado.' : 'Nenhum produto/serviço cadastrado.' }}</p>
      </div>

      <div v-else class="cfg-list">
        <div v-for="p in filtered" :key="p.id" class="cfg-card">
          <div class="cfg-svc-icon">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/></svg>
          </div>
          <div class="cfg-card-info">
            <div class="cfg-card-name">{{ p.name }}</div>
            <div class="cfg-card-sub">
              <template v-if="p.duration_minutes">{{ p.duration_minutes }}min</template>
              <template v-if="p.price"> · R$ {{ Number(p.price).toFixed(2).replace('.', ',') }}</template>
            </div>
          </div>
          <div class="cfg-badge" :style="{ background: p.active !== false ? 'rgba(34,197,94,.12)' : 'rgba(148,163,184,.1)', color: p.active !== false ? '#22c55e' : '#64748b' }">
            {{ p.active !== false ? 'Ativo' : 'Inativo' }}
          </div>
          <div class="cfg-actions">
            <button class="cfg-icon-btn" @click="openEdit(p)">
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.12 2.12 0 0 1 3 3L12 15l-4 1 1-4Z"/></svg>
            </button>
            <button class="cfg-icon-btn cfg-icon-btn--danger" @click="del(p)">
              <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/></svg>
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>

  <!-- MODAL -->
  <Teleport to="body">
    <div v-if="modal !== null" class="cfg-mo-overlay" @click.self="modal = null">
      <div class="cfg-mo-box">
        <div class="cfg-mo-head">
          <span>{{ modal?.id ? 'Editar' : 'Novo' }} serviço/produto</span>
          <button class="cfg-close" @click="modal = null">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
          </button>
        </div>
        <form class="cfg-mo-form" @submit.prevent="save">
          <div class="cfg-field"><label class="cfg-lbl">Nome *</label><input v-model="form.name" class="cfg-inp" required /></div>
          <div class="cfg-field"><label class="cfg-lbl">Descrição</label><textarea v-model="form.description" class="cfg-inp cfg-ta" rows="2" /></div>
          <div class="cfg-grid2">
            <div class="cfg-field"><label class="cfg-lbl">Duração (min)</label><input v-model.number="form.duration_minutes" type="number" min="5" step="5" class="cfg-inp" /></div>
            <div class="cfg-field"><label class="cfg-lbl">Preço (R$)</label><input v-model="form.price" type="number" step="0.01" min="0" class="cfg-inp" placeholder="0,00" /></div>
          </div>
          <div class="cfg-toggle-row">
            <span class="cfg-lbl" style="margin:0">Ativo</span>
            <button type="button" class="cfg-toggle" :class="{ 'cfg-toggle--on': form.active }" @click="form.active = !form.active"><span class="cfg-toggle-knob" /></button>
          </div>
          <div class="cfg-mo-foot">
            <button type="button" class="cfg-btn-cancel" @click="modal = null">Cancelar</button>
            <button type="submit" class="cfg-btn-primary">Salvar</button>
          </div>
        </form>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.cfg-backdrop { position:fixed; inset:0; z-index:200; background:rgba(0,0,0,.5); backdrop-filter:blur(4px); }
.cfg-drawer   { position:fixed; top:0; right:0; bottom:0; z-index:201; width:480px; max-width:100vw; background:#18191b; border-left:1px solid rgba(255,255,255,.08); display:flex; flex-direction:column; box-shadow:-20px 0 48px rgba(0,0,0,.5); }

.cfg-header { display:flex; align-items:center; justify-content:space-between; padding:16px 20px; border-bottom:1px solid rgba(255,255,255,.07); flex-shrink:0; }
.cfg-header-title { display:flex; align-items:center; gap:8px; font-size:14px; font-weight:700; color:#f1f5f9; }
.cfg-close { background:none; border:none; cursor:pointer; color:#64748b; display:flex; transition:color .12s; }
.cfg-close:hover { color:#f1f5f9; }

.cfg-body { flex:1; overflow-y:auto; padding:16px; display:flex; flex-direction:column; gap:10px; }
.cfg-note { font-size:11px; color:#475569; line-height:1.5; padding:8px 10px; border-radius:7px; background:rgba(255,255,255,.03); border:1px solid rgba(255,255,255,.05); }

.cfg-search-wrap { display:flex; align-items:center; gap:8px; padding:6px 10px; border-radius:8px; background:#111213; border:1px solid rgba(255,255,255,.09); }
.cfg-search-inp  { flex:1; background:none; border:none; outline:none; color:#f1f5f9; font-size:12px; }

.cfg-list { display:flex; flex-direction:column; gap:5px; }
.cfg-card { display:flex; align-items:center; gap:10px; padding:10px 12px; border-radius:10px; background:#111213; border:1px solid rgba(255,255,255,.07); transition:border-color .12s; }
.cfg-card:hover { border-color:rgba(255,255,255,.14); }
.cfg-svc-icon { width:34px; height:34px; border-radius:8px; background:rgba(91,108,245,.1); border:1px solid rgba(91,108,245,.2); flex-shrink:0; display:flex; align-items:center; justify-content:center; color:rgba(91,108,245,.8); }
.cfg-card-info { flex:1; min-width:0; }
.cfg-card-name { font-size:13px; font-weight:700; color:#f1f5f9; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
.cfg-card-sub  { font-size:11px; color:#475569; }
.cfg-badge { flex-shrink:0; padding:2px 8px; border-radius:20px; font-size:10px; font-weight:700; }
.cfg-actions { display:flex; gap:3px; }
.cfg-icon-btn { width:27px; height:27px; border-radius:7px; border:1px solid rgba(255,255,255,.08); background:rgba(255,255,255,.04); color:#64748b; cursor:pointer; display:flex; align-items:center; justify-content:center; transition:all .12s; }
.cfg-icon-btn:hover { color:#f1f5f9; background:rgba(255,255,255,.09); }
.cfg-icon-btn--danger:hover { color:#f87171; border-color:rgba(248,113,113,.3); background:rgba(248,113,113,.07); }

.cfg-empty { display:flex; flex-direction:column; align-items:center; gap:8px; color:#334155; font-size:13px; padding:40px 0; }

.cfg-btn-primary { display:flex; align-items:center; gap:5px; padding:7px 14px; border-radius:9999px; background:rgb(var(--n-brand,66 65 255)); color:#fff; font-size:12px; font-weight:700; border:none; cursor:pointer; white-space:nowrap; }
.cfg-btn-primary:hover { opacity:.88; }
.cfg-btn-cancel  { padding:7px 14px; border-radius:9999px; border:1px solid rgba(255,255,255,.12); background:transparent; color:#94a3b8; font-size:12px; font-weight:600; cursor:pointer; }
.cfg-btn-cancel:hover { color:#f1f5f9; }

.cfg-mo-overlay { position:fixed; inset:0; z-index:300; display:flex; align-items:center; justify-content:center; padding:16px; background:rgba(0,0,0,.6); backdrop-filter:blur(8px); }
.cfg-mo-box { width:100%; max-width:420px; background:#18191b; border:1px solid rgba(255,255,255,.1); border-radius:14px; box-shadow:0 20px 60px rgba(0,0,0,.6); display:flex; flex-direction:column; overflow:hidden; }
.cfg-mo-head { display:flex; align-items:center; justify-content:space-between; padding:14px 18px; border-bottom:1px solid rgba(255,255,255,.07); font-size:13px; font-weight:700; color:#f1f5f9; }
.cfg-mo-form { padding:16px 18px; display:flex; flex-direction:column; gap:14px; }
.cfg-mo-foot { display:flex; justify-content:flex-end; gap:8px; padding-top:4px; }

.cfg-field { display:flex; flex-direction:column; gap:5px; }
.cfg-lbl   { font-size:10px; font-weight:700; text-transform:uppercase; letter-spacing:.08em; color:#475569; }
.cfg-inp   { width:100%; height:34px; padding:0 10px; border-radius:8px; border:1px solid rgba(255,255,255,.1); background:#111213; color:#f1f5f9; font-size:12px; font-family:inherit; outline:none; box-sizing:border-box; transition:border-color .15s; }
.cfg-inp:focus { border-color:rgb(var(--n-brand,66 65 255)); }
.cfg-ta { height:auto; padding:8px 10px; resize:none; }
.cfg-grid2 { display:grid; grid-template-columns:1fr 1fr; gap:12px; }

.cfg-toggle-row { display:flex; align-items:center; justify-content:space-between; padding:6px 0; }
.cfg-toggle { width:36px; height:20px; border-radius:9999px; border:none; background:rgba(255,255,255,.1); cursor:pointer; position:relative; transition:background .15s; flex-shrink:0; }
.cfg-toggle--on { background:rgb(var(--n-brand,66 65 255)); }
.cfg-toggle-knob { position:absolute; top:3px; left:3px; width:14px; height:14px; border-radius:50%; background:#fff; transition:transform .15s; display:block; }
.cfg-toggle--on .cfg-toggle-knob { transform:translateX(16px); }
</style>
