<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import CardLayout from 'dashboard/components-next/CardLayout.vue';
import Input from 'dashboard/components-next/input/Input.vue';

const props = defineProps({
  kbId: { type: [String, Number], required: true },
});

const store   = useStore();
const allFaqs = computed(() => store.getters['knowledgeBases/getFaqs']);
const uiFlags = computed(() => store.getters['knowledgeBases/getUIFlags']);

onMounted(() => store.dispatch('knowledgeBases/fetchFaqs', { kbId: props.kbId }));

// ── client-side search ────────────────────────────────────────────────────────
const search = ref('');

// ── category chips ────────────────────────────────────────────────────────────
const selectedCategory = ref(null);

const allCategories = computed(() => {
  const cats = new Set();
  allFaqs.value.forEach(f => cats.add(f.category || 'Geral'));
  return Array.from(cats).sort((a, b) => a.localeCompare(b));
});

const selectCategory = cat => {
  selectedCategory.value = selectedCategory.value === cat ? null : cat;
};

// ── filtered (search + category) ─────────────────────────────────────────────
const filtered = computed(() => {
  const q = search.value.trim().toLowerCase();
  return allFaqs.value.filter(f => {
    const cat = f.category || 'Geral';
    const matchesCat = !selectedCategory.value || cat === selectedCategory.value;
    if (!matchesCat) return false;
    if (!q) return true;
    return (
      f.question.toLowerCase().includes(q) ||
      f.answer.toLowerCase().includes(q) ||
      cat.toLowerCase().includes(q)
    );
  });
});

// ── grouped by category ───────────────────────────────────────────────────────
const grouped = computed(() => {
  const groups = {};
  filtered.value.forEach(faq => {
    const cat = faq.category || 'Geral';
    if (!groups[cat]) groups[cat] = [];
    groups[cat].push(faq);
  });
  return Object.entries(groups).sort(([a], [b]) => a.localeCompare(b));
});

// ── expand/collapse ───────────────────────────────────────────────────────────
const expanded = ref({});
const toggle   = id => { expanded.value[id] = !expanded.value[id]; };

// ── modal ─────────────────────────────────────────────────────────────────────
const showModal  = ref(false);
const editTarget = ref(null);
const form       = ref({ category: '', question: '', answer: '' });

const openCreate = () => {
  editTarget.value = null;
  form.value = { category: selectedCategory.value || '', question: '', answer: '' };
  showModal.value = true;
};

const openEdit = faq => {
  editTarget.value = faq;
  form.value = { category: faq.category || '', question: faq.question, answer: faq.answer };
  showModal.value = true;
};

const closeModal = () => { showModal.value = false; editTarget.value = null; };

const saveFaq = async () => {
  if (!form.value.question.trim() || !form.value.answer.trim()) {
    useAlert('Preencha a pergunta e a resposta.');
    return;
  }
  try {
    if (editTarget.value) {
      await store.dispatch('knowledgeBases/updateFaq', { kbId: props.kbId, id: editTarget.value.id, ...form.value });
      useAlert('FAQ atualizado.');
    } else {
      await store.dispatch('knowledgeBases/createFaq', { kbId: props.kbId, ...form.value });
      useAlert('FAQ criado.');
    }
    closeModal();
  } catch {
    useAlert('Erro ao salvar FAQ.');
  }
};

// ── delete ────────────────────────────────────────────────────────────────────
const deleteTarget = ref(null);

const confirmDelete = async () => {
  try {
    await store.dispatch('knowledgeBases/deleteFaq', { kbId: props.kbId, id: deleteTarget.value.id });
    useAlert('FAQ removido.');
  } catch {
    useAlert('Erro ao remover FAQ.');
  }
  deleteTarget.value = null;
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <!-- Toolbar -->
    <div class="flex items-center justify-between gap-3">
      <Input
        v-model="search"
        placeholder="Buscar FAQs..."
        class="w-64"
        size="sm"
        type="search"
      />
      <Button label="Novo FAQ" icon="i-lucide-plus" size="sm" @click="openCreate" />
    </div>

    <!-- Category chips -->
    <div v-if="allCategories.length > 1" class="flex items-center gap-2 flex-wrap">
      <button
        class="inline-flex items-center h-7 px-3 rounded-full text-xs font-medium transition-colors border"
        :class="
          !selectedCategory
            ? 'bg-n-brand text-white border-n-brand'
            : 'bg-n-solid-2 text-n-slate-11 border-n-weak hover:border-n-brand/50 hover:text-n-slate-12'
        "
        @click="selectedCategory = null"
      >
        Todos
        <span class="ml-1.5 text-[10px] opacity-70">{{ allFaqs.length }}</span>
      </button>
      <button
        v-for="cat in allCategories"
        :key="cat"
        class="inline-flex items-center h-7 px-3 rounded-full text-xs font-medium transition-colors border"
        :class="
          selectedCategory === cat
            ? 'bg-n-brand text-white border-n-brand'
            : 'bg-n-solid-2 text-n-slate-11 border-n-weak hover:border-n-brand/50 hover:text-n-slate-12'
        "
        @click="selectCategory(cat)"
      >
        {{ cat }}
        <span class="ml-1.5 text-[10px] opacity-70">
          {{ allFaqs.filter(f => (f.category || 'Geral') === cat).length }}
        </span>
      </button>
    </div>

    <!-- Loading -->
    <div v-if="uiFlags.isFetching && allFaqs.length === 0" class="flex items-center justify-center py-10 text-n-slate-11">
      <Spinner />
    </div>

    <!-- Empty state -->
    <div v-else-if="allFaqs.length === 0" class="flex flex-col items-center justify-center py-16 gap-4">
      <div class="w-16 h-16 rounded-2xl bg-n-alpha-black2 flex items-center justify-center">
        <span class="i-lucide-help-circle text-3xl text-n-slate-8" />
      </div>
      <div class="text-center">
        <p class="text-base font-medium text-n-slate-12">Nenhum FAQ encontrado</p>
        <p class="text-sm text-n-slate-9 mt-1">Adicione perguntas e respostas que sua IA usará.</p>
      </div>
      <Button label="Criar primeiro FAQ" icon="i-lucide-plus" size="sm" @click="openCreate" />
    </div>

    <!-- No search results -->
    <p v-else-if="filtered.length === 0" class="text-sm text-n-slate-9 text-center py-10">
      Nenhum resultado para "{{ search }}"<template v-if="selectedCategory"> na categoria "{{ selectedCategory }}"</template>.
    </p>

    <!-- Grouped list -->
    <div v-else class="flex flex-col gap-4">
      <div v-for="[category, items] in grouped" :key="category" class="flex flex-col gap-2">
        <!-- Category header (only shown when viewing all) -->
        <div v-if="!selectedCategory" class="flex items-center gap-2 px-1">
          <span class="i-lucide-folder text-n-slate-8 text-xs" />
          <span class="text-xs font-semibold text-n-slate-10 flex-1">{{ category }}</span>
          <span class="text-xs text-n-slate-8">{{ items.length }} {{ items.length === 1 ? 'item' : 'itens' }}</span>
        </div>

        <!-- FAQ cards -->
        <CardLayout v-for="faq in items" :key="faq.id" layout="col" class="cursor-pointer">
          <!-- Question row -->
          <div class="flex gap-2 justify-between w-full">
            <div class="flex items-center gap-2 flex-1 min-w-0" @click="toggle(faq.id)">
              <span
                class="i-lucide-chevron-right text-n-slate-8 text-sm flex-shrink-0 transition-transform"
                :class="expanded[faq.id] ? 'rotate-90' : ''"
              />
              <span class="text-base text-n-slate-12 line-clamp-1">{{ faq.question }}</span>
            </div>
            <div class="flex items-center gap-1 shrink-0">
              <Button icon="i-lucide-pencil" color="slate" size="xs" class="rounded-md hover:bg-n-alpha-2" @click.stop="openEdit(faq)" />
              <Button icon="i-lucide-trash-2" color="ruby" size="xs" class="rounded-md" @click.stop="deleteTarget = faq" />
            </div>
          </div>

          <!-- Answer (expanded) -->
          <div v-if="expanded[faq.id]" class="flex gap-4 justify-between items-start w-full">
            <p class="text-sm text-n-slate-11 whitespace-pre-wrap leading-relaxed">{{ faq.answer }}</p>
          </div>
        </CardLayout>
      </div>
    </div>

    <!-- CREATE/EDIT MODAL -->
    <Teleport to="body">
      <div v-if="showModal" class="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div class="absolute inset-0 bg-black/50" @click="closeModal" />
        <div class="relative w-full max-w-xl bg-n-solid-1 rounded-2xl shadow-2xl border border-n-weak flex flex-col max-h-[90vh]">
          <div class="flex items-center justify-between px-6 py-4 border-b border-n-weak flex-shrink-0">
            <div class="flex items-center gap-2">
              <span class="i-lucide-help-circle text-n-brand text-lg" />
              <h3 class="text-base font-semibold text-n-slate-12">{{ editTarget ? 'Editar FAQ' : 'Novo FAQ' }}</h3>
            </div>
            <button class="w-8 h-8 rounded-lg flex items-center justify-center text-n-slate-9 hover:bg-n-alpha-2 transition-colors" @click="closeModal">
              <span class="i-lucide-x text-base" />
            </button>
          </div>
          <div class="flex-1 overflow-y-auto px-6 py-5 flex flex-col gap-4">
            <div class="flex flex-col gap-1.5">
              <label class="text-xs font-semibold text-n-slate-10">Categoria <span class="font-normal text-n-slate-8">(opcional)</span></label>
              <input v-model="form.category" type="text" placeholder="ex: Pagamentos, Produto, Suporte..." class="h-10 px-3 rounded-lg border border-n-weak bg-n-solid-2 text-sm text-n-slate-12 placeholder:text-n-slate-8 focus:outline-none focus:ring-2 focus:ring-n-brand/30" />
              <!-- Category suggestions from existing ones -->
              <div v-if="allCategories.length > 0" class="flex flex-wrap gap-1.5 mt-0.5">
                <button
                  v-for="cat in allCategories"
                  :key="cat"
                  class="inline-flex items-center h-6 px-2 rounded-full text-xs border transition-colors"
                  :class="
                    form.category === cat
                      ? 'bg-n-brand text-white border-n-brand'
                      : 'bg-n-solid-2 text-n-slate-10 border-n-weak hover:border-n-brand/50'
                  "
                  type="button"
                  @click="form.category = form.category === cat ? '' : cat"
                >
                  {{ cat }}
                </button>
              </div>
            </div>
            <div class="flex flex-col gap-1.5">
              <label class="text-xs font-semibold text-n-slate-10">Pergunta <span class="text-ruby-9">*</span></label>
              <textarea v-model="form.question" rows="2" placeholder="ex: Como faço para cancelar minha assinatura?" class="px-3 py-2 rounded-lg border border-n-weak bg-n-solid-2 text-sm text-n-slate-12 placeholder:text-n-slate-8 focus:outline-none focus:ring-2 focus:ring-n-brand/30 resize-none" />
            </div>
            <div class="flex flex-col gap-1.5">
              <label class="text-xs font-semibold text-n-slate-10">Resposta <span class="text-ruby-9">*</span></label>
              <textarea v-model="form.answer" rows="5" placeholder="Escreva a resposta que a IA deve usar como contexto..." class="px-3 py-2 rounded-lg border border-n-weak bg-n-solid-2 text-sm text-n-slate-12 placeholder:text-n-slate-8 focus:outline-none focus:ring-2 focus:ring-n-brand/30 resize-y" />
            </div>
          </div>
          <div class="flex items-center justify-end gap-3 px-6 py-4 border-t border-n-weak flex-shrink-0">
            <button class="h-9 px-4 rounded-lg border border-n-weak text-sm font-semibold text-n-slate-11 hover:bg-n-alpha-2 transition-colors" @click="closeModal">Cancelar</button>
            <button class="h-9 px-4 rounded-lg bg-n-brand text-white text-sm font-semibold hover:brightness-110 transition-all disabled:opacity-50 flex items-center gap-2" :disabled="uiFlags.isSaving" @click="saveFaq">
              <span v-if="uiFlags.isSaving" class="i-lucide-loader-2 animate-spin text-sm" />
              {{ editTarget ? 'Salvar alterações' : 'Criar FAQ' }}
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
              <h3 class="text-base font-semibold text-n-slate-12">Remover FAQ</h3>
              <p class="text-sm text-n-slate-10 mt-1 line-clamp-2">{{ deleteTarget?.question }}</p>
            </div>
          </div>
          <div class="flex items-center justify-end gap-3">
            <button class="h-9 px-4 rounded-lg border border-n-weak text-sm font-semibold text-n-slate-11 hover:bg-n-alpha-2 transition-colors" @click="deleteTarget = null">Cancelar</button>
            <button class="h-9 px-4 rounded-lg bg-ruby-9 text-white text-sm font-semibold hover:bg-ruby-10 transition-colors" @click="confirmDelete">Remover</button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>
