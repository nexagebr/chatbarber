<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import CardLayout from 'dashboard/components-next/CardLayout.vue';

const props = defineProps({
  kbId: { type: [String, Number], required: true },
});

const store = useStore();
const sites = computed(() => store.getters['knowledgeBases/getSites']);
const uiFlags = computed(() => store.getters['knowledgeBases/getUIFlags']);

onMounted(() => {
  store.dispatch('knowledgeBases/fetchSites', props.kbId);
});

// ── add site ──────────────────────────────────────────────────────────────────
const form = ref({ url: '', title: '' });

const getDomain = url => {
  try {
    return new URL(url).hostname;
  } catch {
    return url;
  }
};

const faviconUrl = url => {
  try {
    const domain = new URL(url).hostname;
    return `https://www.google.com/s2/favicons?domain=${domain}&sz=16`;
  } catch {
    return '';
  }
};

const addSite = async () => {
  if (!form.value.url.trim()) {
    useAlert('Informe a URL do site.');
    return;
  }
  let url = form.value.url.trim();
  if (!url.startsWith('http://') && !url.startsWith('https://')) {
    url = `https://${url}`;
  }
  try {
    await store.dispatch('knowledgeBases/createSite', {
      kbId: props.kbId,
      url,
      title: form.value.title.trim(),
    });
    form.value = { url: '', title: '' };
    useAlert('Site adicionado.');
  } catch {
    useAlert('Erro ao adicionar site.');
  }
};

// ── delete ────────────────────────────────────────────────────────────────────
const deleteTarget = ref(null);

const openDelete = site => {
  deleteTarget.value = site;
};

const cancelDelete = () => {
  deleteTarget.value = null;
};

const confirmDelete = async () => {
  try {
    await store.dispatch('knowledgeBases/deleteSite', {
      kbId: props.kbId,
      id: deleteTarget.value.id,
    });
    useAlert('Site removido.');
  } catch {
    useAlert('Erro ao remover site.');
  }
  cancelDelete();
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <!-- Add form -->
    <div
      class="outline outline-1 outline-n-container rounded-xl p-5 flex flex-col gap-3 bg-n-solid-2"
    >
      <h4 class="text-sm font-medium text-n-slate-12">Adicionar site</h4>
      <div class="flex flex-col sm:flex-row gap-3">
        <div class="flex flex-col gap-1.5 flex-1">
          <label class="text-xs text-n-slate-9">
            URL <span class="text-ruby-9">*</span>
          </label>
          <input
            v-model="form.url"
            type="url"
            placeholder="https://exemplo.com/faq"
            class="h-9 px-3 rounded-lg border border-n-weak bg-n-solid-1 text-sm text-n-slate-12 placeholder:text-n-slate-8 focus:outline-none focus:ring-2 focus:ring-n-brand/30"
            @keydown.enter="addSite"
          />
        </div>
        <div class="flex flex-col gap-1.5 sm:w-48">
          <label class="text-xs text-n-slate-9">
            Título
            <span class="font-normal text-n-slate-8">(opcional)</span>
          </label>
          <input
            v-model="form.title"
            type="text"
            placeholder="Nome do site"
            class="h-9 px-3 rounded-lg border border-n-weak bg-n-solid-1 text-sm text-n-slate-12 placeholder:text-n-slate-8 focus:outline-none focus:ring-2 focus:ring-n-brand/30"
            @keydown.enter="addSite"
          />
        </div>
        <Button
          label="Adicionar"
          icon="i-lucide-plus"
          size="sm"
          class="self-end flex-shrink-0"
          :is-loading="uiFlags.isSaving"
          :disabled="uiFlags.isSaving"
          @click="addSite"
        />
      </div>
    </div>

    <!-- Loading -->
    <div
      v-if="uiFlags.isFetching"
      class="flex items-center justify-center py-8 text-n-slate-11"
    >
      <Spinner />
    </div>

    <!-- Empty state -->
    <div
      v-else-if="sites.length === 0"
      class="flex flex-col items-center justify-center py-10 gap-3"
    >
      <div
        class="w-12 h-12 rounded-2xl bg-n-alpha-black2 flex items-center justify-center"
      >
        <span class="i-lucide-globe text-2xl text-n-slate-8" />
      </div>
      <p class="text-sm text-n-slate-9">Nenhum site adicionado ainda</p>
    </div>

    <!-- Sites list -->
    <div v-else class="flex flex-col gap-4">
      <CardLayout
        v-for="site in sites"
        :key="site.id"
        layout="row"
      >
        <div class="flex items-center gap-3 flex-1 min-w-0">
          <div
            class="w-9 h-9 rounded-lg bg-n-alpha-black2 flex items-center justify-center flex-shrink-0"
          >
            <img
              v-if="site.url"
              :src="faviconUrl(site.url)"
              :alt="getDomain(site.url)"
              class="w-4 h-4"
              @error="$event.target.style.display = 'none'"
            />
            <span v-else class="i-lucide-globe text-n-slate-8 text-sm" />
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-base text-n-slate-12 truncate">
              {{ site.title || getDomain(site.url) }}
            </p>
            <a
              :href="site.url"
              target="_blank"
              rel="noopener noreferrer"
              class="text-sm text-n-brand hover:underline truncate block"
              @click.stop
            >
              {{ site.url }}
            </a>
          </div>
        </div>
        <div class="flex items-center gap-2 shrink-0">
          <a
            :href="site.url"
            target="_blank"
            rel="noopener noreferrer"
            class="w-7 h-7 rounded-lg flex items-center justify-center text-n-slate-9 hover:bg-n-alpha-2 transition-colors"
            @click.stop
          >
            <span class="i-lucide-external-link text-sm" />
          </a>
          <Button
            icon="i-lucide-trash-2"
            color="ruby"
            size="xs"
            class="rounded-md"
            @click.stop="openDelete(site)"
          />
        </div>
      </CardLayout>
    </div>

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
                Remover site
              </h3>
              <p class="text-sm text-n-slate-10 mt-1 truncate">
                {{
                  deleteTarget?.title ||
                  getDomain(deleteTarget?.url || '')
                }}
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
              Remover
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>
