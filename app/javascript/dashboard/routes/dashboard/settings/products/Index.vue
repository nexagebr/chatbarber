<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import CardLayout from 'dashboard/components-next/CardLayout.vue';
import Input from 'dashboard/components-next/input/Input.vue';

const store    = useStore();
const allItems = computed(() => store.getters['products/getList']);
const uiFlags  = computed(() => store.getters['products/getUIFlags']);

onMounted(() => store.dispatch('products/fetchList'));

// ── tabs ──────────────────────────────────────────────────────────────────────
const activeTab = ref('products');
const tabs = [
  { key: 'products', label: 'Produtos', icon: 'i-lucide-package' },
  { key: 'settings', label: 'Configurações', icon: 'i-lucide-settings' },
];

// ── search + category filter ──────────────────────────────────────────────────
const search           = ref('');
const selectedCategory = ref(null);

const allCategories = computed(() => {
  const cats = new Set();
  allItems.value.forEach(p => { if (p.category) cats.add(p.category); });
  return Array.from(cats).sort((a, b) => a.localeCompare(b));
});

const filtered = computed(() => {
  const q = search.value.trim().toLowerCase();
  return allItems.value.filter(p => {
    if (selectedCategory.value && p.category !== selectedCategory.value) return false;
    if (!q) return true;
    return (
      (p.name        || '').toLowerCase().includes(q) ||
      (p.description || '').toLowerCase().includes(q) ||
      (p.category    || '').toLowerCase().includes(q) ||
      (p.sku         || '').toLowerCase().includes(q) ||
      String(p.id).includes(q)
    );
  });
});

const selectCategory = cat => {
  selectedCategory.value = selectedCategory.value === cat ? null : cat;
};

// ── tipos disponíveis ─────────────────────────────────────────────────────────
const TIPO_SUGGESTIONS = ['Produto', 'Serviço', 'Assinatura', 'Pacote'];

const allTipos = computed(() => {
  const set = new Set(TIPO_SUGGESTIONS);
  allItems.value.forEach(p => { if (p.tipo) set.add(p.tipo); });
  return Array.from(set);
});

const isService = computed(() => {
  const t = (form.value.tipo || '').toLowerCase();
  return t.includes('servi') || t.includes('service');
});

// ── modal ─────────────────────────────────────────────────────────────────────
const showModal  = ref(false);
const editTarget = ref(null);
const form       = ref({ name: '', description: '', price: '', cost: '', stock: '', category: '', sku: '', external_id: '', tipo: '', duracao: '', active: true });

const openCreate = () => {
  editTarget.value = null;
  form.value = { name: '', description: '', price: '', cost: '', stock: '', category: selectedCategory.value || '', sku: '', external_id: '', tipo: '', duracao: '', active: true };
  showModal.value = true;
};

const openEdit = product => {
  editTarget.value = product;
  form.value = {
    name:        product.name        || '',
    description: product.description || '',
    price:       product.price       ?? '',
    cost:        product.cost        ?? '',
    stock:       product.stock       ?? '',
    category:    product.category    || '',
    sku:         product.sku         || '',
    external_id: product.external_id || '',
    tipo:        product.tipo        || '',
    duracao:     product.duracao != null ? Math.round(product.duracao / 60) : '',
    active:      product.active !== false,
  };
  showModal.value = true;
};

const closeModal = () => { showModal.value = false; editTarget.value = null; };

const saveProduct = async () => {
  if (!form.value.name.trim()) { useAlert('O nome é obrigatório.'); return; }
  const payload = {
    name:        form.value.name.trim(),
    description: form.value.description.trim(),
    price:       form.value.price  !== '' ? parseFloat(form.value.price)  : null,
    cost:        form.value.cost   !== '' ? parseFloat(form.value.cost)   : null,
    stock:       form.value.stock  !== '' ? parseInt(form.value.stock, 10) : null,
    category:    form.value.category.trim(),
    sku:         form.value.sku.trim(),
    external_id: form.value.external_id.trim(),
    tipo:        form.value.tipo.trim(),
    duracao:     isService.value && form.value.duracao !== '' ? Math.round(Number(form.value.duracao) * 60) : null,
    active:      form.value.active,
  };
  try {
    if (editTarget.value) {
      await store.dispatch('products/updateProduct', { id: editTarget.value.id, ...payload });
      useAlert('Produto atualizado.');
    } else {
      await store.dispatch('products/createProduct', payload);
      useAlert('Produto criado.');
    }
    closeModal();
  } catch {
    useAlert('Erro ao salvar produto.');
  }
};

// ── delete ────────────────────────────────────────────────────────────────────
const deleteTarget = ref(null);

const confirmDelete = async () => {
  try {
    await store.dispatch('products/deleteProduct', deleteTarget.value.id);
    useAlert('Produto removido.');
  } catch {
    useAlert('Erro ao remover produto.');
  }
  deleteTarget.value = null;
};

// ── helpers ───────────────────────────────────────────────────────────────────
const formatPrice = price => {
  if (price == null || price === '' || Number(price) === 0) return null;
  return Number(price).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
};

const copyId = async id => {
  try {
    await navigator.clipboard.writeText(String(id));
    useAlert(`ID #${id} copiado`);
  } catch {}
};

// ── settings tab — tipo management ────────────────────────────────────────────
const newTipoInput = ref('');
const customTipos  = ref([...TIPO_SUGGESTIONS]);

const addCustomTipo = () => {
  const v = newTipoInput.value.trim();
  if (v && !customTipos.value.includes(v)) customTipos.value.push(v);
  newTipoInput.value = '';
};
const removeCustomTipo = tipo => {
  customTipos.value = customTipos.value.filter(t => t !== tipo);
};
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">

    <!-- Header -->
    <header class="sticky top-0 z-10 px-6">
      <div class="w-full max-w-[60rem] mx-auto">
        <div class="flex items-start lg:items-center justify-between w-full py-6 lg:py-0 lg:h-20 gap-4 lg:gap-2 flex-col lg:flex-row">
          <span class="text-xl font-medium text-n-slate-12">Produtos</span>
          <Button
            v-if="activeTab === 'products'"
            label="Novo Produto"
            icon="i-lucide-plus"
            size="sm"
            @click="openCreate"
          />
        </div>

        <!-- Tab bar -->
        <div class="flex items-center gap-0 overflow-x-auto border-b border-n-weak">
          <button
            v-for="tab in tabs"
            :key="tab.key"
            class="inline-flex items-center gap-2 px-4 py-3 text-sm font-medium whitespace-nowrap transition-colors border-b-2 -mb-px"
            :class="activeTab === tab.key ? 'text-n-brand border-n-brand' : 'text-n-slate-9 border-transparent hover:text-n-slate-12'"
            @click="activeTab = tab.key"
          >
            <span :class="tab.icon" class="text-sm" />
            {{ tab.label }}
          </button>
        </div>
      </div>
    </header>

    <!-- Tab content -->
    <main class="flex-1 px-6 overflow-y-auto">
      <div class="w-full max-w-[60rem] mx-auto py-6">

        <!-- ── PRODUTOS TAB ──────────────────────────────────────────────── -->
        <template v-if="activeTab === 'products'">
          <div class="flex items-center justify-between gap-3 mb-4">
            <Input v-model="search" placeholder="Buscar produtos..." class="w-64" size="sm" type="search" />
          </div>

          <!-- Category chips -->
          <div v-if="allCategories.length > 0" class="flex items-center gap-2 flex-wrap mb-4">
            <button
              class="inline-flex items-center h-7 px-3 rounded-full text-xs font-medium transition-colors border"
              :class="!selectedCategory ? 'bg-n-brand text-white border-n-brand' : 'bg-n-solid-2 text-n-slate-11 border-n-weak hover:border-n-brand/50 hover:text-n-slate-12'"
              @click="selectedCategory = null"
            >
              Todos <span class="ml-1.5 text-[10px] opacity-70">{{ allItems.length }}</span>
            </button>
            <button
              v-for="cat in allCategories"
              :key="cat"
              class="inline-flex items-center h-7 px-3 rounded-full text-xs font-medium transition-colors border"
              :class="selectedCategory === cat ? 'bg-n-brand text-white border-n-brand' : 'bg-n-solid-2 text-n-slate-11 border-n-weak hover:border-n-brand/50 hover:text-n-slate-12'"
              @click="selectCategory(cat)"
            >
              {{ cat }} <span class="ml-1.5 text-[10px] opacity-70">{{ allItems.filter(p => p.category === cat).length }}</span>
            </button>
          </div>

          <!-- Loading -->
          <div v-if="uiFlags.isFetching && allItems.length === 0" class="flex items-center justify-center py-10">
            <Spinner />
          </div>

          <!-- Empty state -->
          <div v-else-if="allItems.length === 0" class="flex flex-col items-center justify-center py-16 gap-4">
            <div class="w-16 h-16 rounded-2xl bg-n-alpha-black2 flex items-center justify-center">
              <span class="i-lucide-package text-3xl text-n-slate-8" />
            </div>
            <div class="text-center">
              <p class="text-base font-medium text-n-slate-12">Nenhum produto cadastrado</p>
              <p class="text-sm text-n-slate-9 mt-1">Adicione produtos para que sua IA possa consultá-los.</p>
            </div>
            <Button label="Criar primeiro produto" icon="i-lucide-plus" size="sm" @click="openCreate" />
          </div>

          <!-- No results -->
          <p v-else-if="filtered.length === 0" class="text-sm text-n-slate-9 text-center py-10">
            Nenhum resultado encontrado.
          </p>

          <!-- Product list -->
          <div v-else class="flex flex-col gap-3">
            <div
              v-for="product in filtered"
              :key="product.id"
              class="group relative bg-n-surface-2 border border-n-weak rounded-xl overflow-hidden hover:border-n-slate-6 transition-colors"
            >
              <!-- Color accent strip based on active status -->
              <div class="absolute left-0 top-0 bottom-0 w-0.5 rounded-l-xl" :class="product.active ? 'bg-n-brand' : 'bg-n-slate-6'" />

              <div class="flex items-start gap-4 px-5 py-4 pl-6">

                <!-- Icon -->
                <div class="w-10 h-10 rounded-xl bg-n-alpha-black2 flex items-center justify-center flex-shrink-0 mt-0.5 border border-n-weak">
                  <span class="i-lucide-package text-n-slate-7 text-base" />
                </div>

                <!-- Content -->
                <div class="flex-1 min-w-0">

                  <!-- Row 1: name + badges + id + actions -->
                  <div class="flex items-start justify-between gap-2">
                    <div class="flex items-center gap-2 flex-wrap min-w-0">
                      <span class="text-sm font-semibold text-n-slate-12 truncate">{{ product.name }}</span>
                      <span v-if="product.tipo" class="inline-flex items-center h-5 px-2 rounded-full text-[10px] font-semibold bg-n-brand/10 text-n-brand border border-n-brand/20">
                        {{ product.tipo }}
                      </span>
                      <span v-if="!product.active" class="inline-flex items-center h-5 px-2 rounded-full text-[10px] font-medium bg-n-alpha-black2 text-n-slate-9 border border-n-weak">
                        Inativo
                      </span>
                    </div>

                    <!-- Right side: ID + actions -->
                    <div class="flex items-center gap-1.5 flex-shrink-0">
                      <button
                        class="inline-flex items-center h-6 px-2 rounded-md text-[10px] font-mono font-medium text-n-slate-8 bg-n-alpha-1 border border-n-weak hover:border-n-slate-6 hover:text-n-slate-11 transition-colors gap-1"
                        title="Clique para copiar ID"
                        @click.stop="copyId(product.id)"
                      >
                        <span class="i-lucide-hash" style="font-size:9px" />{{ product.id }}
                      </button>
                      <button
                        class="w-7 h-7 rounded-lg flex items-center justify-center text-n-slate-8 hover:text-n-slate-12 hover:bg-n-alpha-2 transition-colors opacity-0 group-hover:opacity-100"
                        @click="openEdit(product)"
                      >
                        <span class="i-lucide-pencil text-sm" />
                      </button>
                      <button
                        class="w-7 h-7 rounded-lg flex items-center justify-center text-ruby-9 hover:bg-ruby-3 transition-colors opacity-0 group-hover:opacity-100"
                        @click="deleteTarget = product"
                      >
                        <span class="i-lucide-trash-2 text-sm" />
                      </button>
                    </div>
                  </div>

                  <!-- Row 2: description -->
                  <p v-if="product.description" class="text-xs text-n-slate-9 mt-1 line-clamp-1">{{ product.description }}</p>

                  <!-- Row 3: metadata chips -->
                  <div class="flex items-center gap-x-4 gap-y-1 mt-2.5 flex-wrap">
                    <span v-if="product.category" class="inline-flex items-center gap-1 text-xs text-n-slate-9">
                      <span class="i-lucide-folder text-[10px] text-n-slate-7" />{{ product.category }}
                    </span>
                    <span v-if="product.external_id" class="inline-flex items-center gap-1 text-xs text-n-slate-9 font-mono">
                      <span class="i-lucide-fingerprint text-[10px] text-n-slate-7" />{{ product.external_id }}
                    </span>
                    <span v-if="product.sku" class="inline-flex items-center gap-1 text-xs text-n-slate-9 font-mono">
                      <span class="i-lucide-barcode text-[10px] text-n-slate-7" />{{ product.sku }}
                    </span>
                    <span v-if="product.duracao" class="inline-flex items-center gap-1 text-xs text-n-slate-9">
                      <span class="i-lucide-clock text-[10px] text-n-slate-7" />{{ Math.round(product.duracao / 60) }} min
                    </span>
                    <span v-if="product.stock != null && product.stock > 0" class="inline-flex items-center gap-1 text-xs text-n-slate-9">
                      <span class="i-lucide-archive text-[10px] text-n-slate-7" />{{ product.stock }} un.
                    </span>
                    <!-- Price -->
                    <span v-if="formatPrice(product.price)" class="inline-flex items-center gap-1 text-xs font-semibold text-n-slate-11">
                      <span class="i-lucide-tag text-[10px] text-n-slate-7" />{{ formatPrice(product.price) }}
                    </span>
                    <!-- Cost -->
                    <span v-if="formatPrice(product.cost)" class="inline-flex items-center gap-1 text-xs text-n-slate-8">
                      <span class="i-lucide-coins text-[10px] text-n-slate-7" />custo {{ formatPrice(product.cost) }}
                    </span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </template>

        <!-- ── CONFIGURAÇÕES TAB ─────────────────────────────────────────── -->
        <template v-else-if="activeTab === 'settings'">
          <div class="flex flex-col gap-6 pb-8 max-w-2xl">

            <!-- Header da seção -->
            <div class="flex flex-col gap-1 pb-4 border-b border-n-weak">
              <h5 class="text-base font-semibold text-n-slate-12">Configurações de Produtos</h5>
              <p class="text-sm text-n-slate-9">Personalize como os produtos são organizados e utilizados.</p>
            </div>

            <!-- Tipos de produto -->
            <div class="flex flex-col gap-4 p-5 rounded-xl border border-n-weak bg-n-surface-2">
              <div class="flex items-start justify-between gap-2">
                <div>
                  <p class="text-sm font-semibold text-n-slate-12">Tipos de produto</p>
                  <p class="text-xs text-n-slate-9 mt-0.5">Sugestões exibidas ao criar ou editar um produto.</p>
                </div>
                <span class="i-lucide-layers text-n-slate-7 text-base flex-shrink-0 mt-0.5" />
              </div>

              <div class="flex flex-wrap gap-2">
                <span
                  v-for="tipo in customTipos"
                  :key="tipo"
                  class="inline-flex items-center gap-1.5 h-7 pl-3 pr-1.5 rounded-full text-xs font-medium bg-n-alpha-1 border border-n-weak text-n-slate-11"
                >
                  {{ tipo }}
                  <button
                    class="w-4 h-4 rounded-full flex items-center justify-center hover:bg-n-alpha-2 transition-colors text-n-slate-8 hover:text-ruby-9"
                    @click="removeCustomTipo(tipo)"
                  >
                    <span class="i-lucide-x" style="font-size:10px" />
                  </button>
                </span>
              </div>

              <div class="flex items-center gap-2">
                <input
                  v-model="newTipoInput"
                  type="text"
                  placeholder="Novo tipo..."
                  class="flex-1 h-9 px-3 rounded-lg border border-n-weak bg-n-solid-2 text-sm text-n-slate-12 placeholder:text-n-slate-8 focus:outline-none focus:ring-2 focus:ring-n-brand/30"
                  @keydown.enter="addCustomTipo"
                />
                <button
                  class="h-9 px-4 rounded-lg bg-n-brand text-white text-sm font-semibold hover:brightness-110 transition-all disabled:opacity-40"
                  :disabled="!newTipoInput.trim()"
                  @click="addCustomTipo"
                >
                  Adicionar
                </button>
              </div>
            </div>

            <!-- Campos do produto -->
            <div class="flex flex-col gap-4 p-5 rounded-xl border border-n-weak bg-n-surface-2">
              <div class="flex items-start justify-between gap-2">
                <div>
                  <p class="text-sm font-semibold text-n-slate-12">Campos disponíveis</p>
                  <p class="text-xs text-n-slate-9 mt-0.5">Todos os campos que podem ser preenchidos em cada produto.</p>
                </div>
                <span class="i-lucide-list text-n-slate-7 text-base flex-shrink-0 mt-0.5" />
              </div>

              <div class="grid grid-cols-2 gap-2">
                <div
                  v-for="field in [
                    { icon: 'i-lucide-hash',         label: 'ID do sistema',   desc: 'Gerado automaticamente, copiável'   },
                    { icon: 'i-lucide-type',          label: 'Nome',            desc: 'Obrigatório'                        },
                    { icon: 'i-lucide-align-left',    label: 'Descrição',       desc: 'Texto livre'                        },
                    { icon: 'i-lucide-layers',        label: 'Tipo',            desc: 'Ex: Produto, Serviço'               },
                    { icon: 'i-lucide-folder',        label: 'Categoria',       desc: 'Agrupamento dos cards'              },
                    { icon: 'i-lucide-barcode',       label: 'SKU / Código',    desc: 'Código externo'                     },
                    { icon: 'i-lucide-tag',           label: 'Preço de venda',  desc: 'Exibido no card'                    },
                    { icon: 'i-lucide-coins',         label: 'Custo',           desc: 'Controle interno'                   },
                    { icon: 'i-lucide-archive',       label: 'Estoque',         desc: 'Quantidade em unidades'             },
                    { icon: 'i-lucide-clock',         label: 'Duração',         desc: 'Apenas para Serviços'               },
                  ]"
                  :key="field.label"
                  class="flex items-start gap-2.5 p-3 rounded-lg bg-n-alpha-1 border border-n-weak/50"
                >
                  <span :class="field.icon" class="text-n-slate-7 text-sm flex-shrink-0 mt-0.5" />
                  <div class="min-w-0">
                    <p class="text-xs font-medium text-n-slate-11 leading-tight">{{ field.label }}</p>
                    <p class="text-[10px] text-n-slate-8 mt-0.5 leading-tight">{{ field.desc }}</p>
                  </div>
                </div>
              </div>
            </div>

            <!-- Integração com IA -->
            <div class="flex flex-col gap-3 p-5 rounded-xl border border-n-weak bg-n-surface-2">
              <div class="flex items-start justify-between gap-2">
                <div>
                  <p class="text-sm font-semibold text-n-slate-12">Integração com IA</p>
                  <p class="text-xs text-n-slate-9 mt-0.5">Produtos ativos são enviados automaticamente como contexto para o assistente.</p>
                </div>
                <span class="i-lucide-bot text-n-slate-7 text-base flex-shrink-0 mt-0.5" />
              </div>

              <div class="flex items-center gap-3 p-3 rounded-lg bg-n-alpha-1 border border-n-weak/50">
                <div class="w-8 h-8 rounded-lg bg-n-brand/10 flex items-center justify-center flex-shrink-0">
                  <span class="i-lucide-package-check text-n-brand text-sm" />
                </div>
                <div class="min-w-0">
                  <p class="text-xs font-medium text-n-slate-11">
                    <span class="text-n-brand font-bold">{{ allItems.filter(p => p.active !== false).length }}</span>
                    produto{{ allItems.filter(p => p.active !== false).length !== 1 ? 's' : '' }} ativo{{ allItems.filter(p => p.active !== false).length !== 1 ? 's' : '' }} disponíveis para a IA
                  </p>
                  <p class="text-[10px] text-n-slate-8 mt-0.5">Produtos inativos são ignorados pelo assistente.</p>
                </div>
              </div>
            </div>

            <!-- Estatísticas -->
            <div class="grid grid-cols-3 gap-3">
              <div class="p-4 rounded-xl border border-n-weak bg-n-surface-2 flex flex-col gap-1">
                <span class="i-lucide-package text-n-slate-7 text-base" />
                <p class="text-xl font-bold text-n-slate-12 mt-1">{{ allItems.length }}</p>
                <p class="text-xs text-n-slate-9">Total</p>
              </div>
              <div class="p-4 rounded-xl border border-n-weak bg-n-surface-2 flex flex-col gap-1">
                <span class="i-lucide-folder text-n-slate-7 text-base" />
                <p class="text-xl font-bold text-n-slate-12 mt-1">{{ allCategories.length }}</p>
                <p class="text-xs text-n-slate-9">Categorias</p>
              </div>
              <div class="p-4 rounded-xl border border-n-weak bg-n-surface-2 flex flex-col gap-1">
                <span class="i-lucide-check-circle text-n-brand text-base" />
                <p class="text-xl font-bold text-n-brand mt-1">{{ allItems.filter(p => p.active !== false).length }}</p>
                <p class="text-xs text-n-slate-9">Ativos</p>
              </div>
            </div>

          </div>
        </template>

      </div>
    </main>

    <!-- CREATE/EDIT MODAL -->
    <Teleport to="body">
      <div v-if="showModal" class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div class="absolute inset-0 bg-black/50" @click="closeModal" />
        <div class="relative w-full max-w-lg bg-n-solid-1 rounded-2xl shadow-2xl border border-n-weak flex flex-col max-h-[90vh]">

          <div class="flex items-center justify-between px-6 py-4 border-b border-n-weak flex-shrink-0">
            <div class="flex items-center gap-2">
              <span class="i-lucide-package text-n-brand text-lg" />
              <h3 class="text-base font-semibold text-n-slate-12">{{ editTarget ? 'Editar Produto' : 'Novo Produto' }}</h3>
              <span v-if="editTarget" class="text-xs font-mono text-n-slate-8 bg-n-alpha-1 border border-n-weak px-2 py-0.5 rounded-md">#{{ editTarget.id }}</span>
            </div>
            <button class="w-8 h-8 rounded-lg flex items-center justify-center text-n-slate-9 hover:bg-n-alpha-2 transition-colors" @click="closeModal">
              <span class="i-lucide-x text-base" />
            </button>
          </div>

          <div class="flex-1 overflow-y-auto px-6 py-5 flex flex-col gap-4">

            <!-- Nome -->
            <div class="flex flex-col gap-1.5">
              <label class="text-xs font-semibold text-n-slate-10">Nome <span class="text-ruby-9">*</span></label>
              <input v-model="form.name" type="text" placeholder="ex: Camiseta Azul M" class="h-10 px-3 rounded-lg border border-n-weak bg-n-solid-2 text-sm text-n-slate-12 placeholder:text-n-slate-8 focus:outline-none focus:ring-2 focus:ring-n-brand/30" />
            </div>

            <!-- ID externo + SKU -->
            <div class="grid grid-cols-2 gap-4">
              <div class="flex flex-col gap-1.5">
                <label class="text-xs font-semibold text-n-slate-10">ID externo <span class="font-normal text-n-slate-8">(do seu sistema)</span></label>
                <input v-model="form.external_id" type="text" placeholder="ex: 1042, PROD-001..." class="h-10 px-3 rounded-lg border border-n-weak bg-n-solid-2 text-sm text-n-slate-12 placeholder:text-n-slate-8 focus:outline-none focus:ring-2 focus:ring-n-brand/30" />
              </div>
              <div class="flex flex-col gap-1.5">
                <label class="text-xs font-semibold text-n-slate-10">SKU / Código <span class="font-normal text-n-slate-8">(opcional)</span></label>
                <input v-model="form.sku" type="text" placeholder="ex: CAM-AZ-M" class="h-10 px-3 rounded-lg border border-n-weak bg-n-solid-2 text-sm text-n-slate-12 placeholder:text-n-slate-8 focus:outline-none focus:ring-2 focus:ring-n-brand/30" />
              </div>
            </div>

            <!-- Preço + Custo -->
            <div class="grid grid-cols-2 gap-4">
              <div class="flex flex-col gap-1.5">
                <label class="text-xs font-semibold text-n-slate-10">Preço de venda <span class="font-normal text-n-slate-8">(opcional)</span></label>
                <div class="flex h-10 rounded-lg border border-n-weak bg-n-solid-2 overflow-hidden focus-within:ring-2 focus-within:ring-n-brand/30">
                  <span class="flex items-center px-3 text-xs text-n-slate-8 border-r border-n-weak bg-n-alpha-1 flex-shrink-0 select-none">R$</span>
                  <input v-model="form.price" type="text" inputmode="decimal" placeholder="0,00" class="flex-1 px-3 bg-transparent text-sm text-n-slate-12 placeholder:text-n-slate-8 focus:outline-none min-w-0" />
                </div>
              </div>
              <div class="flex flex-col gap-1.5">
                <label class="text-xs font-semibold text-n-slate-10">Custo <span class="font-normal text-n-slate-8">(opcional)</span></label>
                <div class="flex h-10 rounded-lg border border-n-weak bg-n-solid-2 overflow-hidden focus-within:ring-2 focus-within:ring-n-brand/30">
                  <span class="flex items-center px-3 text-xs text-n-slate-8 border-r border-n-weak bg-n-alpha-1 flex-shrink-0 select-none">R$</span>
                  <input v-model="form.cost" type="text" inputmode="decimal" placeholder="0,00" class="flex-1 px-3 bg-transparent text-sm text-n-slate-12 placeholder:text-n-slate-8 focus:outline-none min-w-0" />
                </div>
              </div>
            </div>

            <!-- Estoque -->
            <div class="flex flex-col gap-1.5">
              <label class="text-xs font-semibold text-n-slate-10">Estoque <span class="font-normal text-n-slate-8">(unidades, opcional)</span></label>
              <input v-model="form.stock" type="number" min="0" step="1" placeholder="0" class="h-10 px-3 rounded-lg border border-n-weak bg-n-solid-2 text-sm text-n-slate-12 placeholder:text-n-slate-8 focus:outline-none focus:ring-2 focus:ring-n-brand/30 w-full" />
            </div>

            <!-- Tipo -->
            <div class="flex flex-col gap-1.5">
              <label class="text-xs font-semibold text-n-slate-10">Tipo <span class="font-normal text-n-slate-8">(opcional)</span></label>
              <input v-model="form.tipo" type="text" placeholder="ex: Produto, Serviço, Assinatura..." class="h-10 px-3 rounded-lg border border-n-weak bg-n-solid-2 text-sm text-n-slate-12 placeholder:text-n-slate-8 focus:outline-none focus:ring-2 focus:ring-n-brand/30" />
              <div class="flex flex-wrap gap-1.5 mt-0.5">
                <button
                  v-for="t in allTipos"
                  :key="t"
                  type="button"
                  class="inline-flex items-center h-6 px-2 rounded-full text-xs border transition-colors"
                  :class="form.tipo === t ? 'bg-n-brand text-white border-n-brand' : 'bg-n-solid-2 text-n-slate-10 border-n-weak hover:border-n-brand/50'"
                  @click="form.tipo = form.tipo === t ? '' : t"
                >{{ t }}</button>
              </div>
            </div>

            <!-- Duração — só para serviços -->
            <div v-if="isService" class="flex flex-col gap-1.5">
              <label class="text-xs font-semibold text-n-slate-10">Duração <span class="font-normal text-n-slate-8">(min)</span></label>
              <div class="relative">
                <input v-model="form.duracao" type="number" min="1" step="1" placeholder="ex: 60" class="h-10 px-3 pr-12 rounded-lg border border-n-weak bg-n-solid-2 text-sm text-n-slate-12 placeholder:text-n-slate-8 focus:outline-none focus:ring-2 focus:ring-n-brand/30 w-full" />
                <span class="absolute right-3 top-1/2 -translate-y-1/2 text-xs text-n-slate-9 pointer-events-none">min</span>
              </div>
            </div>

            <!-- Categoria -->
            <div class="flex flex-col gap-1.5">
              <label class="text-xs font-semibold text-n-slate-10">Categoria <span class="font-normal text-n-slate-8">(opcional)</span></label>
              <input v-model="form.category" type="text" placeholder="ex: Roupas, Eletrônicos..." class="h-10 px-3 rounded-lg border border-n-weak bg-n-solid-2 text-sm text-n-slate-12 placeholder:text-n-slate-8 focus:outline-none focus:ring-2 focus:ring-n-brand/30" />
              <div v-if="allCategories.length > 0" class="flex flex-wrap gap-1.5 mt-0.5">
                <button
                  v-for="cat in allCategories"
                  :key="cat"
                  type="button"
                  class="inline-flex items-center h-6 px-2 rounded-full text-xs border transition-colors"
                  :class="form.category === cat ? 'bg-n-brand text-white border-n-brand' : 'bg-n-solid-2 text-n-slate-10 border-n-weak hover:border-n-brand/50'"
                  @click="form.category = form.category === cat ? '' : cat"
                >{{ cat }}</button>
              </div>
            </div>

            <!-- Descrição -->
            <div class="flex flex-col gap-1.5">
              <label class="text-xs font-semibold text-n-slate-10">Descrição <span class="font-normal text-n-slate-8">(opcional)</span></label>
              <textarea v-model="form.description" rows="3" placeholder="Descreva o produto para que a IA tenha contexto..." class="px-3 py-2 rounded-lg border border-n-weak bg-n-solid-2 text-sm text-n-slate-12 placeholder:text-n-slate-8 focus:outline-none focus:ring-2 focus:ring-n-brand/30 resize-none" />
            </div>

            <!-- Ativo -->
            <label class="flex items-center gap-3 cursor-pointer select-none p-3 rounded-lg border border-n-weak hover:bg-n-alpha-1 transition-colors">
              <div
                class="w-9 h-5 rounded-full relative flex-shrink-0 transition-colors"
                :class="form.active ? 'bg-n-brand' : 'bg-n-alpha-2'"
                @click="form.active = !form.active"
              >
                <div class="absolute top-0.5 w-4 h-4 rounded-full bg-white shadow-sm transition-all" :style="{ left: form.active ? '18px' : '2px' }" />
              </div>
              <div>
                <p class="text-sm font-medium text-n-slate-12">Produto ativo</p>
                <p class="text-xs text-n-slate-9">Produtos ativos ficam disponíveis para a IA e para venda.</p>
              </div>
            </label>
          </div>

          <div class="flex items-center justify-end gap-3 px-6 py-4 border-t border-n-weak flex-shrink-0">
            <button class="h-9 px-4 rounded-lg border border-n-weak text-sm font-semibold text-n-slate-11 hover:bg-n-alpha-2 transition-colors" @click="closeModal">Cancelar</button>
            <button
              class="h-9 px-4 rounded-lg bg-n-brand text-white text-sm font-semibold hover:brightness-110 transition-all disabled:opacity-50 flex items-center gap-2"
              :disabled="uiFlags.isSaving"
              @click="saveProduct"
            >
              <span v-if="uiFlags.isSaving" class="i-lucide-loader-2 animate-spin text-sm" />
              {{ editTarget ? 'Salvar alterações' : 'Criar produto' }}
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- DELETE CONFIRMATION -->
    <Teleport to="body">
      <div v-if="deleteTarget" class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div class="absolute inset-0 bg-black/50" @click="deleteTarget = null" />
        <div class="relative w-full max-w-sm bg-n-solid-1 rounded-2xl shadow-2xl border border-n-weak p-6 flex flex-col gap-4">
          <div class="flex items-start gap-3">
            <div class="w-10 h-10 rounded-full bg-ruby-3 flex items-center justify-center flex-shrink-0">
              <span class="i-lucide-trash-2 text-ruby-11 text-lg" />
            </div>
            <div>
              <h3 class="text-base font-semibold text-n-slate-12">Remover produto</h3>
              <p class="text-sm text-n-slate-10 mt-1">{{ deleteTarget?.name }}</p>
              <p class="text-xs text-n-slate-8 mt-0.5 font-mono">#{{ deleteTarget?.id }}</p>
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
