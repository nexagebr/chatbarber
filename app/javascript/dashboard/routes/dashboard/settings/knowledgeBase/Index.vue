<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const store = useStore();
const router = useRouter();

const list = computed(() => store.getters['knowledgeBases/getList']);
const uiFlags = computed(() => store.getters['knowledgeBases/getUIFlags']);

onMounted(() => {
  store.dispatch('knowledgeBases/fetchList');
});

// ── create modal ─────────────────────────────────────────────────────────────
const showCreateModal = ref(false);
const createForm = ref({ name: '', description: '' });

const openCreate = () => {
  createForm.value = { name: '', description: '' };
  showCreateModal.value = true;
};

const closeCreate = () => {
  showCreateModal.value = false;
};

const submitCreate = async () => {
  if (!createForm.value.name.trim()) {
    useAlert('O nome é obrigatório.');
    return;
  }
  try {
    const kb = await store.dispatch('knowledgeBases/createKB', {
      name: createForm.value.name.trim(),
      description: createForm.value.description.trim(),
    });
    closeCreate();
    useAlert('Base de conhecimento criada!');
    router.push({ name: 'knowledge_base_detail', params: { id: kb.id } });
  } catch {
    useAlert('Erro ao criar base de conhecimento.');
  }
};

// ── delete ────────────────────────────────────────────────────────────────────
const deleteTarget = ref(null);

const openDelete = kb => {
  deleteTarget.value = kb;
};

const cancelDelete = () => {
  deleteTarget.value = null;
};

const confirmDelete = async () => {
  try {
    await store.dispatch('knowledgeBases/deleteKB', deleteTarget.value.id);
    useAlert('Base de conhecimento removida.');
  } catch {
    useAlert('Erro ao remover base de conhecimento.');
  }
  cancelDelete();
};

// ── navigation ────────────────────────────────────────────────────────────────
const openDetail = kb => {
  router.push({ name: 'knowledge_base_detail', params: { id: kb.id } });
};
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">
    <!-- Header -->
    <header class="sticky top-0 z-10 px-6">
      <div class="w-full max-w-[60rem] mx-auto">
        <div
          class="flex items-start lg:items-center justify-between w-full py-6 lg:py-0 lg:h-20 gap-4 lg:gap-2 flex-col lg:flex-row"
        >
          <div class="flex gap-3 items-center">
            <span class="text-xl font-medium text-n-slate-12">
              Bases de Conhecimento
            </span>
          </div>
          <div class="flex gap-2">
            <button
              class="inline-flex items-center gap-1.5 h-8 px-3 rounded-lg bg-n-brand text-white text-sm font-medium hover:brightness-110 transition-all"
              @click="openCreate"
            >
              <span class="i-lucide-plus text-base" />
              Nova Base
            </button>
          </div>
        </div>
      </div>
    </header>

    <!-- Main content -->
    <main class="flex-1 px-6 overflow-y-auto">
      <div class="w-full max-w-[60rem] h-full mx-auto py-4">

        <!-- Loading -->
        <div
          v-if="uiFlags.isFetching"
          class="flex items-center justify-center py-10 text-n-slate-11"
        >
          <Spinner />
        </div>

        <!-- Empty state -->
        <div
          v-else-if="list.length === 0"
          class="flex flex-col items-center justify-center py-16 gap-6"
        >
          <div
            class="w-16 h-16 rounded-2xl bg-n-alpha-black2 flex items-center justify-center"
          >
            <span class="i-lucide-book-open text-3xl text-n-slate-8" />
          </div>
          <div class="text-center">
            <p class="text-base font-medium text-n-slate-12">
              Nenhuma base de conhecimento
            </p>
            <p class="text-sm text-n-slate-9 mt-1">
              Crie bases para organizar FAQs, sites e arquivos para sua IA.
            </p>
          </div>
          <button
            class="inline-flex items-center gap-1.5 h-8 px-3 rounded-lg bg-n-brand text-white text-sm font-medium hover:brightness-110 transition-all"
            @click="openCreate"
          >
            <span class="i-lucide-plus text-base" />
            Criar primeira base
          </button>
        </div>

        <!-- KB list -->
        <div v-else class="flex flex-col gap-4">
          <div
            v-for="kb in list"
            :key="kb.id"
            class="flex items-center gap-4 p-4 rounded-xl border border-n-weak bg-n-solid-1 hover:bg-n-alpha-1 transition-colors group cursor-pointer"
            @click="openDetail(kb)"
          >
            <!-- Icon -->
            <div
              class="w-10 h-10 rounded-xl bg-n-alpha-black2 flex items-center justify-center flex-shrink-0"
            >
              <span class="i-lucide-book-open text-n-slate-8 text-lg" />
            </div>

            <!-- Content -->
            <div class="flex-1 min-w-0">
              <p class="text-base text-n-slate-12 font-medium truncate">
                {{ kb.name }}
              </p>
              <p class="text-sm text-n-slate-9 truncate mt-0.5">
                {{ kb.description || 'Sem descrição' }}
              </p>
            </div>

            <!-- Stats -->
            <div
              class="hidden sm:flex items-center gap-4 text-sm text-n-slate-9 shrink-0"
            >
              <span class="flex items-center gap-1">
                <span class="i-lucide-help-circle text-xs" />
                {{ kb.faq_count ?? 0 }} FAQs
              </span>
              <span class="flex items-center gap-1">
                <span class="i-lucide-globe text-xs" />
                {{ kb.site_count ?? 0 }} sites
              </span>
              <span class="flex items-center gap-1">
                <span class="i-lucide-inbox text-xs" />
                {{ kb.inbox_count ?? 0 }} caixas
              </span>
            </div>

            <!-- Actions -->
            <div
              class="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity flex-shrink-0"
              @click.stop
            >
              <button
                class="w-8 h-8 rounded-lg flex items-center justify-center text-n-slate-9 hover:bg-ruby-3 hover:text-ruby-11 transition-colors"
                title="Excluir"
                @click="openDelete(kb)"
              >
                <span class="i-lucide-trash-2 text-sm" />
              </button>
            </div>
          </div>
        </div>
      </div>
    </main>

    <!-- CREATE MODAL -->
    <Teleport to="body">
      <div
        v-if="showCreateModal"
        class="fixed inset-0 z-50 flex items-center justify-center p-4"
      >
        <div class="absolute inset-0 bg-black/50" @click="closeCreate" />
        <div
          class="relative w-full max-w-md bg-n-solid-1 rounded-2xl shadow-2xl border border-n-weak overflow-hidden"
        >
          <div
            class="flex items-center justify-between px-6 py-4 border-b border-n-weak"
          >
            <div class="flex items-center gap-2">
              <span class="i-lucide-book-plus text-n-brand text-lg" />
              <h3 class="text-base font-semibold text-n-slate-12">
                Nova Base de Conhecimento
              </h3>
            </div>
            <button
              class="w-8 h-8 rounded-lg flex items-center justify-center text-n-slate-9 hover:bg-n-alpha-2 transition-colors"
              @click="closeCreate"
            >
              <span class="i-lucide-x text-base" />
            </button>
          </div>
          <div class="px-6 py-5 flex flex-col gap-4">
            <div class="flex flex-col gap-1.5">
              <label class="text-xs font-semibold text-n-slate-10">
                Nome <span class="text-ruby-9">*</span>
              </label>
              <input
                v-model="createForm.name"
                type="text"
                placeholder="ex: FAQ Produtos, Suporte Técnico..."
                class="h-10 px-3 rounded-lg border border-n-weak bg-n-solid-2 text-sm text-n-slate-12 placeholder:text-n-slate-8 focus:outline-none focus:ring-2 focus:ring-n-brand/30"
                @keydown.enter="submitCreate"
              />
            </div>
            <div class="flex flex-col gap-1.5">
              <label class="text-xs font-semibold text-n-slate-10">
                Descrição
                <span class="font-normal text-n-slate-8">(opcional)</span>
              </label>
              <textarea
                v-model="createForm.description"
                rows="3"
                placeholder="Descreva o propósito desta base de conhecimento..."
                class="px-3 py-2 rounded-lg border border-n-weak bg-n-solid-2 text-sm text-n-slate-12 placeholder:text-n-slate-8 focus:outline-none focus:ring-2 focus:ring-n-brand/30 resize-none"
              />
            </div>
          </div>
          <div
            class="flex items-center justify-end gap-3 px-6 py-4 border-t border-n-weak"
          >
            <button
              class="h-9 px-4 rounded-lg border border-n-weak text-sm font-semibold text-n-slate-11 hover:bg-n-alpha-2 transition-colors"
              @click="closeCreate"
            >
              Cancelar
            </button>
            <button
              class="h-9 px-4 rounded-lg bg-n-brand text-white text-sm font-semibold hover:brightness-110 transition-all disabled:opacity-50 flex items-center gap-2"
              :disabled="uiFlags.isSaving"
              @click="submitCreate"
            >
              <span
                v-if="uiFlags.isSaving"
                class="i-lucide-loader-2 animate-spin text-sm"
              />
              Criar base
            </button>
          </div>
        </div>
      </div>
    </Teleport>

    <!-- DELETE CONFIRMATION -->
    <Teleport to="body">
      <div
        v-if="deleteTarget"
        class="fixed inset-0 z-50 flex items-center justify-center p-4"
      >
        <div class="absolute inset-0 bg-black/50" @click="cancelDelete" />
        <div
          class="relative w-full max-w-sm bg-n-solid-1 rounded-2xl shadow-2xl border border-n-weak p-6 flex flex-col gap-4"
        >
          <div class="flex items-start gap-3">
            <div
              class="w-10 h-10 rounded-full bg-ruby-3 flex items-center justify-center flex-shrink-0"
            >
              <span class="i-lucide-trash-2 text-ruby-11 text-lg" />
            </div>
            <div>
              <h3 class="text-base font-semibold text-n-slate-12">
                Excluir base de conhecimento
              </h3>
              <p class="text-sm text-n-slate-10 mt-1">
                Tem certeza que deseja excluir
                <strong>{{ deleteTarget?.name }}</strong>? Esta ação não pode
                ser desfeita.
              </p>
            </div>
          </div>
          <div class="flex items-center justify-end gap-3">
            <button
              class="h-9 px-4 rounded-lg border border-n-weak text-sm font-semibold text-n-slate-11 hover:bg-n-alpha-2 transition-colors"
              @click="cancelDelete"
            >
              Cancelar
            </button>
            <button
              class="h-9 px-4 rounded-lg bg-ruby-9 text-white text-sm font-semibold hover:bg-ruby-10 transition-colors"
              @click="confirmDelete"
            >
              Excluir
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </section>
</template>
