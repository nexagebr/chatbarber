<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import CardLayout from 'dashboard/components-next/CardLayout.vue';

const props = defineProps({
  kbId: { type: [String, Number], required: true },
});

const store      = useStore();
const allInboxes = computed(() => store.getters['inboxes/getInboxes'] || []);
const savedIds   = computed(() => store.getters['knowledgeBases/getInboxIds']);
const uiFlags    = computed(() => store.getters['knowledgeBases/getUIFlags']);

const selected = ref([]);

onMounted(async () => {
  await store.dispatch('inboxes/get');
  await store.dispatch('knowledgeBases/fetchInboxIds', props.kbId);
});

watch(savedIds, ids => { selected.value = [...ids]; }, { immediate: true });

const toggleInbox = id => {
  const idx = selected.value.indexOf(id);
  if (idx >= 0) selected.value.splice(idx, 1);
  else selected.value.push(id);
};

const isSelected = id => selected.value.includes(id);

const channelIcon = inbox => {
  const type = (inbox.channel_type || '').toLowerCase();
  if (type.includes('whatsapp')) return 'i-lucide-message-circle';
  if (type.includes('email'))    return 'i-lucide-mail';
  if (type.includes('api'))      return 'i-lucide-code';
  if (type.includes('instagram'))return 'i-lucide-instagram';
  if (type.includes('facebook')) return 'i-lucide-facebook';
  if (type.includes('telegram')) return 'i-lucide-send';
  return 'i-lucide-inbox';
};

const channelLabel = inbox => {
  const type = (inbox.channel_type || '').replace('Channel::', '');
  return type || 'Canal';
};

const save = async () => {
  try {
    await store.dispatch('knowledgeBases/updateInboxIds', { kbId: props.kbId, ids: selected.value });
    useAlert('Caixas de entrada salvas.');
  } catch {
    useAlert('Erro ao salvar caixas de entrada.');
  }
};
</script>

<template>
  <div class="flex flex-col gap-5">

    <!-- Header text -->
    <div class="flex flex-col gap-1">
      <h5 class="text-sm font-semibold text-n-slate-12">Caixas de entrada vinculadas</h5>
      <p class="text-sm text-n-slate-9">
        Selecione as caixas de entrada que usarão esta base de conhecimento como contexto para a IA.
      </p>
    </div>

    <!-- Loading -->
    <div v-if="uiFlags.isFetching && allInboxes.length === 0" class="flex items-center justify-center py-10">
      <Spinner />
    </div>

    <!-- Empty -->
    <div v-else-if="allInboxes.length === 0" class="flex flex-col items-center justify-center py-10 gap-3">
      <div class="w-12 h-12 rounded-2xl bg-n-alpha-black2 flex items-center justify-center">
        <span class="i-lucide-inbox text-2xl text-n-slate-8" />
      </div>
      <p class="text-sm text-n-slate-9">Nenhuma caixa de entrada disponível</p>
    </div>

    <!-- Inbox list -->
    <div v-else class="flex flex-col gap-4">
      <CardLayout
        v-for="inbox in allInboxes"
        :key="inbox.id"
        layout="row"
        class="cursor-pointer"
        :class="isSelected(inbox.id) ? 'outline-n-brand/50' : ''"
        @click="toggleInbox(inbox.id)"
      >
        <div class="flex items-center gap-3 flex-1 min-w-0">
          <!-- Channel icon -->
          <div class="w-9 h-9 rounded-lg bg-n-alpha-black2 flex items-center justify-center flex-shrink-0">
            <span :class="[channelIcon(inbox), 'text-n-slate-8 text-base']" />
          </div>

          <!-- Info -->
          <div class="flex-1 min-w-0">
            <p class="text-base text-n-slate-12 truncate">{{ inbox.name }}</p>
            <p class="text-sm text-n-slate-11 truncate">{{ channelLabel(inbox) }}</p>
          </div>
        </div>

        <!-- Selected indicator -->
        <div class="shrink-0">
          <span v-if="isSelected(inbox.id)" class="i-lucide-check-circle text-n-brand text-lg" />
        </div>
      </CardLayout>
    </div>

    <!-- Save button -->
    <div class="flex items-center justify-end pt-2">
      <Button
        label="Salvar"
        size="sm"
        :is-loading="uiFlags.isSaving"
        :disabled="uiFlags.isSaving"
        @click="save"
      />
    </div>

  </div>
</template>
