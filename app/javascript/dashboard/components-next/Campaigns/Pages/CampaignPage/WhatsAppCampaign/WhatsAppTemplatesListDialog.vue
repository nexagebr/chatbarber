<script setup>
/* eslint-disable vue/no-bare-strings-in-template, @intlify/vue-i18n/no-raw-text */
import { ref, computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';

const props = defineProps({ inboxId: { type: Number, default: null } });
const emit = defineEmits(['close']);

const inboxes = useMapGetter('inboxes/getWhatsAppInboxes');
const whatsappCloudInboxes = computed(() =>
  (inboxes.value || []).filter(i => i.channel_type === 'Channel::Whatsapp')
);
const inboxOptions = computed(() =>
  whatsappCloudInboxes.value.map(i => ({ value: i.id, label: i.name }))
);

const selectedInboxId = ref(
  props.inboxId ||
    (whatsappCloudInboxes.value.length === 1
      ? whatsappCloudInboxes.value[0].id
      : null)
);

const templates = computed(() => {
  if (!selectedInboxId.value) return [];
  const inbox = whatsappCloudInboxes.value.find(
    i => i.id === selectedInboxId.value
  );
  return inbox?.message_templates || [];
});

const statusFilter = ref('all');
const search = ref('');

const filtered = computed(() => {
  let list = templates.value;
  if (statusFilter.value !== 'all') {
    list = list.filter(
      t => (t.status || '').toUpperCase() === statusFilter.value
    );
  }
  if (search.value.trim()) {
    const q = search.value.trim().toLowerCase();
    list = list.filter(t => (t.name || '').toLowerCase().includes(q));
  }
  return list;
});

const statusBadge = status => {
  const s = (status || '').toUpperCase();
  if (s === 'APPROVED')
    return {
      label: 'Aprovado',
      cls: 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400',
    };
  if (s === 'PENDING' || s === 'PENDING_DELETION')
    return {
      label: 'Em análise',
      cls: 'bg-yellow-100 text-yellow-700 dark:bg-yellow-900/30 dark:text-yellow-400',
    };
  if (s === 'REJECTED' || s === 'DISABLED')
    return {
      label: 'Rejeitado',
      cls: 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400',
    };
  return { label: status || '—', cls: 'bg-n-slate-3 text-n-slate-9' };
};

const bodyText = template => {
  const body = (template.components || []).find(c => c.type === 'BODY');
  return body?.text || '—';
};

const counts = computed(() => ({
  all: templates.value.length,
  APPROVED: templates.value.filter(
    t => (t.status || '').toUpperCase() === 'APPROVED'
  ).length,
  PENDING: templates.value.filter(t =>
    ['PENDING', 'PENDING_DELETION'].includes((t.status || '').toUpperCase())
  ).length,
  REJECTED: templates.value.filter(t =>
    ['REJECTED', 'DISABLED'].includes((t.status || '').toUpperCase())
  ).length,
}));
</script>

<template>
  <div
    class="w-[32rem] z-50 absolute top-10 ltr:right-0 rtl:left-0 bg-n-alpha-3 backdrop-blur-[100px] rounded-xl border border-n-weak shadow-md max-h-[85vh] flex flex-col"
  >
    <!-- Header -->
    <div class="flex items-center justify-between px-5 pt-5 pb-3 flex-shrink-0">
      <h3 class="text-base font-medium text-n-slate-12">Templates WhatsApp</h3>
      <button
        type="button"
        class="text-n-slate-9 hover:text-n-slate-12 transition-colors"
        @click="emit('close')"
      >
        <svg
          width="16"
          height="16"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
        >
          <line x1="18" y1="6" x2="6" y2="18" />
          <line x1="6" y1="6" x2="18" y2="18" />
        </svg>
      </button>
    </div>

    <!-- Inbox selector (hidden when inbox is known from context) -->
    <div v-if="!props.inboxId" class="px-5 pb-3 flex-shrink-0">
      <ComboBox
        v-model="selectedInboxId"
        :options="inboxOptions"
        placeholder="Selecione o inbox"
        class="[&>div>button]:bg-n-alpha-black2"
      />
    </div>

    <template v-if="selectedInboxId">
      <!-- Filtros -->
      <div class="px-5 pb-3 flex items-center gap-2 flex-shrink-0">
        <input
          v-model="search"
          type="text"
          placeholder="Buscar por nome..."
          class="flex-1 rounded-lg border border-n-weak bg-n-alpha-2 px-3 py-1.5 text-xs text-n-slate-12 placeholder-n-slate-8 focus:outline-none focus:border-n-brand transition-colors"
        />
        <div class="flex gap-1">
          <button
            v-for="f in [
              { key: 'all', icon: null, count: counts.all },
              {
                key: 'APPROVED',
                icon: 'i-lucide-check',
                count: counts.APPROVED,
              },
              { key: 'PENDING', icon: 'i-lucide-clock', count: counts.PENDING },
              { key: 'REJECTED', icon: 'i-lucide-x', count: counts.REJECTED },
            ]"
            :key="f.key"
            type="button"
            class="flex items-center gap-1 text-[10px] px-2 py-1 rounded-md border transition-colors"
            :class="
              statusFilter === f.key
                ? 'border-n-brand bg-n-brand/10 text-n-brand'
                : 'border-n-weak text-n-slate-9 hover:border-n-slate-7'
            "
            @click="statusFilter = f.key"
          >
            <span v-if="f.icon" class="size-3" :class="f.icon" />
            <span v-else>Todos</span>
            <span>{{ f.count }}</span>
          </button>
        </div>
      </div>

      <!-- Lista -->
      <div class="overflow-y-auto flex-1 px-5 pb-4 flex flex-col gap-2">
        <p
          v-if="filtered.length === 0"
          class="text-xs text-n-slate-8 text-center py-8"
        >
          Nenhum template encontrado.
        </p>
        <div
          v-for="t in filtered"
          :key="t.id || t.name"
          class="rounded-lg border border-n-weak bg-n-alpha-2 p-3 flex flex-col gap-1.5"
        >
          <div class="flex items-center justify-between gap-2">
            <span
              class="text-xs font-medium text-n-slate-12 font-mono truncate"
              >{{ t.name }}</span
            >
            <span
              class="text-[10px] px-1.5 py-0.5 rounded font-medium flex-shrink-0"
              :class="statusBadge(t.status).cls"
            >
              {{ statusBadge(t.status).label }}
            </span>
          </div>
          <p class="text-[11px] text-n-slate-9 line-clamp-2">
            {{ bodyText(t) }}
          </p>
          <div class="flex items-center gap-2 text-[10px] text-n-slate-8">
            <span>{{ t.language }}</span>
            <span v-if="t.category">· {{ t.category }}</span>
          </div>
        </div>
      </div>
    </template>

    <div v-else class="px-5 pb-6 text-xs text-n-slate-8 text-center py-10">
      Selecione um inbox para ver os templates.
    </div>

    <div
      class="px-5 pb-4 pt-1 flex justify-end flex-shrink-0 border-t border-n-weak"
    >
      <Button
        variant="faded"
        color="slate"
        size="sm"
        label="Fechar"
        type="button"
        @click="emit('close')"
      />
    </div>
  </div>
</template>
