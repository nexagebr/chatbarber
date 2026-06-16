<script setup>
import { computed, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';
import { dynamicTime } from 'shared/helpers/timeHelper';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const route = useRoute();
const router = useRouter();

const conversations   = useMapGetter('contactConversations/getAllConversationsByContactId');
const notesByContact  = useMapGetter('contactNotes/getAllNotesByContactId');
const convUIFlags     = useMapGetter('contactConversations/getUIFlags');
const notesUIFlags    = useMapGetter('contactNotes/getUIFlags');

const isFetching = computed(
  () => convUIFlags.value.isFetching || notesUIFlags.value.isFetching
);

const contactConversations = computed(
  () => conversations.value(route.params.contactId) || []
);
const contactNotes = computed(
  () => notesByContact.value(route.params.contactId) || []
);

// ── Filters ──
const activeFilter = ref('all');
const FILTERS = [
  { key: 'all',           label: 'Tudo' },
  { key: 'conversations', label: 'Conversas' },
  { key: 'notes',         label: 'Notas' },
  { key: 'events',        label: 'Eventos' },
];

const isEventNote = content => /^[📊👤🔄]/.test(content || '');

// ── Build unified timeline ──
const allItems = computed(() => {
  const items = [];

  contactConversations.value.forEach(conv => {
    items.push({
      type: 'conversation',
      id: `conv-${conv.id}`,
      date: conv.created_at,
      title: `Conversa #${conv.id}`,
      preview: conv.meta?.sender?.name || '',
      agent: conv.meta?.assignee?.name || null,
      status: conv.status,
      inboxId: conv.inboxId,
      raw: conv,
    });
  });

  contactNotes.value.forEach(note => {
    const content = note.content?.replace(/<[^>]*>/g, '').trim() || '';
    const isEvent = isEventNote(content);
    items.push({
      type: isEvent ? 'event' : 'note',
      id: `note-${note.id}`,
      date: note.createdAt,
      title: isEvent ? content : 'Nota adicionada',
      preview: isEvent ? '' : content,
      agent: note.user?.name || null,
      raw: note,
    });
  });

  return items.sort((a, b) => {
    const da = a.date ? new Date(typeof a.date === 'number' ? a.date * 1000 : a.date) : 0;
    const db = b.date ? new Date(typeof b.date === 'number' ? b.date * 1000 : b.date) : 0;
    return db - da;
  });
});

const filteredItems = computed(() => {
  if (activeFilter.value === 'all') return allItems.value;
  if (activeFilter.value === 'conversations') return allItems.value.filter(i => i.type === 'conversation');
  if (activeFilter.value === 'notes') return allItems.value.filter(i => i.type === 'note');
  if (activeFilter.value === 'events') return allItems.value.filter(i => i.type === 'event');
  return allItems.value;
});

const countFor = key => {
  if (key === 'all') return allItems.value.length;
  if (key === 'conversations') return allItems.value.filter(i => i.type === 'conversation').length;
  if (key === 'notes') return allItems.value.filter(i => i.type === 'note').length;
  if (key === 'events') return allItems.value.filter(i => i.type === 'event').length;
  return 0;
};

const formatDate = raw => {
  if (!raw) return '';
  const ts = typeof raw === 'number' ? raw * 1000 : new Date(raw).getTime();
  return dynamicTime(ts / 1000);
};

const statusLabel = status => {
  const map = { open: 'Aberta', resolved: 'Resolvida', pending: 'Pendente', snoozed: 'Adiada' };
  return map[status] || status;
};

const statusColor = status => {
  const map = {
    open:     'text-green-600 bg-green-50 dark:bg-green-900/20 dark:text-green-400',
    resolved: 'text-slate-500 bg-n-alpha-2',
    pending:  'text-amber-600 bg-amber-50 dark:bg-amber-900/20 dark:text-amber-400',
    snoozed:  'text-blue-500 bg-blue-50 dark:bg-blue-900/20 dark:text-blue-400',
  };
  return map[status] || 'text-slate-500 bg-n-alpha-2';
};

const openConversation = item => {
  router.push({
    name: 'inbox_conversation',
    params: { accountId: route.params.accountId, conversation_id: item.raw.id },
  });
};
</script>

<template>
  <div class="flex flex-col h-full">

    <!-- filter chips -->
    <div class="flex items-center gap-1.5 px-6 pt-4 pb-3 flex-wrap">
      <button
        v-for="f in FILTERS"
        :key="f.key"
        class="inline-flex items-center gap-1 h-7 px-3 rounded-full text-xs font-semibold transition-colors"
        :class="activeFilter === f.key
          ? 'bg-n-brand text-white'
          : 'bg-n-alpha-2 text-n-slate-10 hover:bg-n-alpha-3'"
        @click="activeFilter = f.key"
      >
        {{ f.label }}
        <span
          class="inline-flex items-center justify-center min-w-[18px] h-[18px] px-1 rounded-full text-[10px] font-bold"
          :class="activeFilter === f.key ? 'bg-white/20 text-white' : 'bg-n-alpha-3 text-n-slate-9'"
        >
          {{ countFor(f.key) }}
        </span>
      </button>
    </div>

    <!-- loading -->
    <div v-if="isFetching" class="flex items-center justify-center py-10 text-n-slate-11">
      <Spinner />
    </div>

    <!-- empty -->
    <p
      v-else-if="filteredItems.length === 0"
      class="px-6 py-10 text-sm text-center text-n-slate-11"
    >
      Nenhuma atividade encontrada.
    </p>

    <!-- timeline -->
    <div v-else class="flex-1 overflow-y-auto px-6 pb-6">
      <div class="relative">
        <!-- vertical line -->
        <div class="absolute left-[15px] top-0 bottom-0 w-px bg-n-weak" />

        <div class="flex flex-col gap-0">
          <div
            v-for="item in filteredItems"
            :key="item.id"
            class="relative flex gap-3 py-3 group"
          >
            <!-- dot icon -->
            <div
              class="relative z-10 flex-shrink-0 w-8 h-8 rounded-full flex items-center justify-center"
              :class="{
                'bg-n-brand/10 text-n-brand':     item.type === 'conversation',
                'bg-amber-500/10 text-amber-500': item.type === 'note',
                'bg-violet-500/10 text-violet-500': item.type === 'event',
              }"
            >
              <span
                class="text-sm"
                :class="{
                  'i-lucide-message-circle': item.type === 'conversation',
                  'i-lucide-file-text':      item.type === 'note',
                  'i-lucide-activity':       item.type === 'event',
                }"
              />
            </div>

            <!-- content -->
            <div class="flex-1 min-w-0 pt-0.5">
              <div class="flex items-start justify-between gap-2">
                <div class="min-w-0 flex-1">
                  <!-- conversation -->
                  <template v-if="item.type === 'conversation'">
                    <button
                      class="text-sm font-semibold text-n-slate-12 hover:text-n-brand transition-colors text-left leading-tight"
                      @click="openConversation(item)"
                    >
                      {{ item.title }}
                    </button>
                    <div class="flex items-center gap-1.5 mt-1 flex-wrap">
                      <span
                        class="inline-flex items-center h-5 px-1.5 rounded text-[10px] font-semibold"
                        :class="statusColor(item.status)"
                      >
                        {{ statusLabel(item.status) }}
                      </span>
                      <span v-if="item.agent" class="text-xs text-n-slate-9 truncate">
                        {{ item.agent }}
                      </span>
                    </div>
                  </template>

                  <!-- event (auto-logged: stage/agent change) -->
                  <template v-else-if="item.type === 'event'">
                    <p class="text-sm font-medium text-n-slate-11 leading-snug">
                      {{ item.title }}
                    </p>
                    <span v-if="item.agent" class="text-xs text-n-slate-9">
                      por {{ item.agent }}
                    </span>
                  </template>

                  <!-- note -->
                  <template v-else>
                    <p class="text-sm font-semibold text-n-slate-12 leading-tight">
                      {{ item.title }}
                    </p>
                    <p
                      v-if="item.preview"
                      class="mt-1 text-xs text-n-slate-10 line-clamp-2 leading-relaxed"
                    >
                      {{ item.preview }}
                    </p>
                    <span v-if="item.agent" class="text-xs text-n-slate-9">
                      por {{ item.agent }}
                    </span>
                  </template>
                </div>

                <!-- date -->
                <span class="text-[11px] text-n-slate-9 flex-shrink-0 mt-0.5">
                  {{ formatDate(item.date) }}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

  </div>
</template>
