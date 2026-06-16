<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useRoute, useRouter } from 'vue-router';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import FaqTab from './tabs/FaqTab.vue';
import FilesTab from './tabs/FilesTab.vue';
import SitesTab from './tabs/SitesTab.vue';
import InboxesTab from './tabs/InboxesTab.vue';
import SettingsTab from './tabs/SettingsTab.vue';

const store = useStore();
const route = useRoute();
const router = useRouter();

const kbId = computed(() => route.params.id);
const active = computed(() => store.getters['knowledgeBases/getActive']);
const uiFlags = computed(() => store.getters['knowledgeBases/getUIFlags']);

const activeTab = ref('faq');

const tabs = [
  { key: 'faq', label: 'FAQ', icon: 'i-lucide-help-circle' },
  { key: 'files', label: 'Arquivos', icon: 'i-lucide-paperclip' },
  { key: 'sites', label: 'Sites', icon: 'i-lucide-globe' },
  { key: 'inboxes', label: 'Caixas de Entrada', icon: 'i-lucide-inbox' },
  { key: 'settings', label: 'Configurações', icon: 'i-lucide-settings' },
];

onMounted(async () => {
  await store.dispatch('knowledgeBases/fetchOne', kbId.value);
  store.dispatch('knowledgeBases/fetchFaqs', { kbId: kbId.value });
});

const setTab = tab => {
  activeTab.value = tab;
  if (tab === 'faq') {
    store.dispatch('knowledgeBases/fetchFaqs', { kbId: kbId.value });
  } else if (tab === 'files') {
    store.dispatch('knowledgeBases/fetchFiles', kbId.value);
  } else if (tab === 'sites') {
    store.dispatch('knowledgeBases/fetchSites', kbId.value);
  } else if (tab === 'inboxes') {
    store.dispatch('knowledgeBases/fetchInboxIds', kbId.value);
  }
};

const goBack = () => {
  router.push({ name: 'knowledge_base_list' });
};

const onKbUpdated = () => {
  store.dispatch('knowledgeBases/fetchOne', kbId.value);
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
            <!-- Back button -->
            <button
              class="w-8 h-8 rounded-lg flex items-center justify-center text-n-slate-9 hover:bg-n-alpha-2 transition-colors flex-shrink-0"
              title="Voltar"
              @click="goBack"
            >
              <span class="i-lucide-arrow-left text-base" />
            </button>

            <!-- Loading state -->
            <div
              v-if="uiFlags.isFetching && !active"
              class="flex items-center gap-2"
            >
              <Spinner class="w-4 h-4" />
            </div>

            <!-- KB name -->
            <template v-else-if="active">
              <div class="w-0.5 h-4 rounded-2xl bg-n-weak" />
              <span class="text-xl font-medium truncate text-n-slate-12">
                {{ active.name }}
              </span>
            </template>
          </div>
        </div>

        <!-- Tab bar (subHeader) -->
        <div
          class="flex items-center gap-0 overflow-x-auto border-b border-n-weak -mx-0"
        >
          <button
            v-for="tab in tabs"
            :key="tab.key"
            class="inline-flex items-center gap-2 px-4 py-3 text-sm font-medium whitespace-nowrap transition-colors border-b-2 -mb-px"
            :class="
              activeTab === tab.key
                ? 'text-n-brand border-n-brand'
                : 'text-n-slate-9 border-transparent hover:text-n-slate-12'
            "
            @click="setTab(tab.key)"
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
        <!-- Loading overlay for initial fetch -->
        <div
          v-if="uiFlags.isFetching && !active"
          class="flex items-center justify-center py-10 text-n-slate-11"
        >
          <Spinner />
        </div>
        <template v-else>
          <FaqTab v-if="activeTab === 'faq'" :kb-id="kbId" />
          <FilesTab v-else-if="activeTab === 'files'" :kb-id="kbId" />
          <SitesTab v-else-if="activeTab === 'sites'" :kb-id="kbId" />
          <InboxesTab v-else-if="activeTab === 'inboxes'" :kb-id="kbId" />
          <SettingsTab
            v-else-if="activeTab === 'settings'"
            :kb-id="kbId"
            @kb-updated="onKbUpdated"
          />
        </template>
      </div>
    </main>
  </section>
</template>
