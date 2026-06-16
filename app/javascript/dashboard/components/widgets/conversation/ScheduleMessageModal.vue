<script setup>
/* global axios */
import { ref, computed, watch } from 'vue';
import { useStore } from 'vuex';
import Modal from 'dashboard/components/Modal.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import wootConstants from 'dashboard/constants/globals';

const props = defineProps({
  show: { type: Boolean, default: false },
  conversationId: { type: [Number, String], required: true },
  defaultMessage: { type: String, default: '' },
});

const emit = defineEmits(['close']);

const store = useStore();

const messageContent = ref('');
const scheduledAt = ref('');
const isPrivate = ref(false);
const snoozeConversation = ref(false);
const attachedFiles = ref([]);
const fileInputRef = ref(null);
const scheduleError = ref('');

const minDateTime = computed(() => {
  const now = new Date();
  now.setMinutes(now.getMinutes() + 1);
  const pad = n => String(n).padStart(2, '0');
  return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}T${pad(now.getHours())}:${pad(now.getMinutes())}`;
});

const scheduledMessages = computed(() => store.getters['scheduledMessages/getScheduledMessages']);
const uiFlags = computed(() => store.getters['scheduledMessages/getUIFlags']);
const currentAccountId = computed(() => store.getters['getCurrentAccountId']);

watch(() => props.show, async newVal => {
  if (newVal) {
    messageContent.value = props.defaultMessage || '';
    scheduledAt.value = '';
    isPrivate.value = false;
    snoozeConversation.value = false;
    attachedFiles.value = [];
    scheduleError.value = '';
    await store.dispatch('scheduledMessages/list', props.conversationId);
  }
});

const formatDate = iso => {
  if (!iso) return '';
  return new Date(iso).toLocaleString('pt-BR', {
    day: '2-digit', month: '2-digit', year: 'numeric',
    hour: '2-digit', minute: '2-digit',
  });
};

const formatFileSize = bytes => {
  if (bytes < 1024) return `${bytes}B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)}KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)}MB`;
};

const onFilesPicked = async event => {
  const files = Array.from(event.target.files);
  for (const file of files) {
    const entry = { file, name: file.name, size: file.size, uploading: true, signedId: null, error: null };
    attachedFiles.value.push(entry);
    try {
      const signedId = await uploadFile(file);
      entry.uploading = false;
      entry.signedId = signedId;
    } catch (e) {
      entry.uploading = false;
      entry.error = 'Erro ao enviar';
    }
  }
  // Reset input so same file can be re-selected
  if (fileInputRef.value) fileInputRef.value.value = '';
};

const uploadFile = async file => {
  const formData = new FormData();
  formData.append('file', file);
  const { data } = await axios.post(
    `/api/v1/accounts/${currentAccountId.value}/conversations/${props.conversationId}/scheduled_messages/upload_attachment`,
    formData
  );
  return data.signed_id;
};

const removeFile = idx => {
  attachedFiles.value.splice(idx, 1);
};

const isUploading = computed(() => attachedFiles.value.some(f => f.uploading));

const canSchedule = computed(() => {
  if (isUploading.value) return false;
  if (!scheduledAt.value) return false;
  const hasContent = messageContent.value.trim().length > 0;
  const hasAttachments = attachedFiles.value.some(f => f.signedId);
  return hasContent || hasAttachments;
});

const schedule = async () => {
  if (!canSchedule.value) return;
  scheduleError.value = '';
  try {
    const signedIds = attachedFiles.value
      .filter(f => f.signedId)
      .map(f => f.signedId);

    const scheduledDate = new Date(scheduledAt.value);
    const scheduledIso = scheduledDate.toISOString();
    const scheduledUnix = Math.floor(scheduledDate.getTime() / 1000);
    await store.dispatch('scheduledMessages/create', {
      conversationId: props.conversationId,
      content: messageContent.value.trim(),
      scheduledAt: scheduledIso,
      isPrivate: isPrivate.value,
      signedIds,
    });
    if (snoozeConversation.value) {
      await store.dispatch('toggleStatus', {
        conversationId: props.conversationId,
        status: wootConstants.STATUS_TYPE.SNOOZED,
        snoozedUntil: scheduledUnix,
      });
    }
    messageContent.value = '';
    scheduledAt.value = '';
    isPrivate.value = false;
    snoozeConversation.value = false;
    attachedFiles.value = [];
  } catch (e) {
    const msg = e?.response?.data?.errors?.[0] || e?.response?.data?.error || 'Erro ao agendar mensagem';
    scheduleError.value = msg;
  }
};

const cancelMessage = async id => {
  if (!confirm('Cancelar esta mensagem agendada?')) return;
  await store.dispatch('scheduledMessages/cancel', {
    conversationId: props.conversationId,
    id,
  });
};

const close = () => emit('close');
</script>

<template>
  <Modal :show="show" :on-close="close" size="medium" :show-close-button="false">
    <div class="flex flex-col">
      <!-- Header -->
      <div class="flex items-center justify-between px-6 pt-5 pb-4 border-b border-n-weak">
        <div class="flex items-center gap-3">
          <div class="flex items-center justify-center w-9 h-9 rounded-lg bg-n-brand/10 flex-shrink-0">
            <i class="i-lucide-clock text-n-brand text-base" />
          </div>
          <div>
            <h2 class="text-base font-semibold text-n-slate-12 leading-tight">
              Agendar mensagem
            </h2>
            <p class="text-xs text-n-slate-10 mt-0.5">
              Será enviada automaticamente na data/horário definidos
            </p>
          </div>
        </div>
        <button
          class="flex items-center justify-center w-8 h-8 rounded-lg text-n-slate-9 hover:text-n-slate-12 hover:bg-n-alpha-2 transition-colors"
          @click="close"
        >
          <i class="i-lucide-x text-base" />
        </button>
      </div>

      <!-- Form -->
      <div class="px-6 py-5 space-y-4">

        <!-- Message type toggle -->
        <div class="flex items-center gap-2">
          <button
            class="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium transition-all border"
            :class="!isPrivate
              ? 'bg-n-brand/10 text-n-brand border-n-brand/30'
              : 'bg-n-alpha-1 text-n-slate-10 border-n-weak hover:text-n-slate-12'"
            @click="isPrivate = false"
          >
            <i class="i-lucide-send text-sm" />
            Resposta pública
          </button>
          <button
            class="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium transition-all border"
            :class="isPrivate
              ? 'bg-n-yellow-9/10 text-n-yellow-10 border-n-yellow-9/30'
              : 'bg-n-alpha-1 text-n-slate-10 border-n-weak hover:text-n-slate-12'"
            @click="isPrivate = true"
          >
            <i class="i-lucide-lock text-sm" />
            Nota privada
          </button>
        </div>

        <!-- Message textarea -->
        <div class="space-y-1.5">
          <label class="text-xs font-semibold text-n-slate-11 uppercase tracking-wide">
            Mensagem
          </label>
          <textarea
            v-model="messageContent"
            rows="4"
            placeholder="Digite a mensagem que será enviada..."
            class="w-full px-3 py-2.5 text-sm border border-n-weak rounded-lg bg-n-surface-1 text-n-slate-12 resize-none focus:outline-none focus:ring-2 focus:ring-n-brand/30 focus:border-n-brand transition-all placeholder:text-n-slate-9"
            :class="isPrivate ? 'border-n-yellow-9/40 focus:ring-n-yellow-9/20 focus:border-n-yellow-9/60' : ''"
          />
        </div>

        <!-- Attachments -->
        <div class="space-y-2">
          <div class="flex items-center justify-between">
            <label class="text-xs font-semibold text-n-slate-11 uppercase tracking-wide">
              Anexos
              <span class="normal-case font-normal text-n-slate-9 ml-1">opcional</span>
            </label>
            <button
              class="flex items-center gap-1 text-xs text-n-brand hover:text-n-brand/80 transition-colors"
              @click="fileInputRef.click()"
            >
              <i class="i-lucide-paperclip text-sm" />
              Adicionar arquivo
            </button>
            <input
              ref="fileInputRef"
              type="file"
              multiple
              class="hidden"
              @change="onFilesPicked"
            />
          </div>

          <div v-if="attachedFiles.length" class="space-y-1.5">
            <div
              v-for="(f, idx) in attachedFiles"
              :key="idx"
              class="flex items-center gap-2 p-2 rounded-lg border border-n-weak bg-n-alpha-1"
            >
              <div class="w-7 h-7 rounded-md bg-n-alpha-2 flex items-center justify-center flex-shrink-0">
                <i v-if="f.uploading" class="i-lucide-loader-2 animate-spin text-n-brand text-xs" />
                <i v-else-if="f.error" class="i-lucide-alert-circle text-n-ruby-9 text-xs" />
                <i v-else class="i-lucide-file text-n-slate-10 text-xs" />
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-xs font-medium text-n-slate-12 truncate">{{ f.name }}</p>
                <p class="text-[10px] text-n-slate-9">
                  <span v-if="f.uploading">Enviando…</span>
                  <span v-else-if="f.error" class="text-n-ruby-9">{{ f.error }}</span>
                  <span v-else>{{ formatFileSize(f.size) }}</span>
                </p>
              </div>
              <button
                class="flex-shrink-0 p-1 rounded text-n-slate-9 hover:text-n-ruby-9 transition-colors"
                @click="removeFile(idx)"
              >
                <i class="i-lucide-x text-xs" />
              </button>
            </div>
          </div>
        </div>

        <!-- Date/time picker -->
        <div class="space-y-1.5">
          <label class="text-xs font-semibold text-n-slate-11 uppercase tracking-wide">
            Data e horário de envio
          </label>
          <input
            v-model="scheduledAt"
            type="datetime-local"
            :min="minDateTime"
            class="w-full px-3 py-2.5 text-sm border border-n-weak rounded-lg bg-n-surface-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand/30 focus:border-n-brand transition-all"
          />
        </div>

        <!-- Error message -->
        <div
          v-if="scheduleError"
          class="flex items-center gap-2 px-3 py-2 rounded-lg bg-n-ruby-9/10 border border-n-ruby-9/30 text-sm text-n-ruby-10"
        >
          <i class="i-lucide-alert-circle text-sm flex-shrink-0" />
          <span>{{ scheduleError }}</span>
        </div>

        <!-- Snooze option -->
        <label class="flex items-center gap-2.5 cursor-pointer select-none group">
          <div
            class="flex items-center justify-center w-4 h-4 rounded border transition-all flex-shrink-0"
            :class="snoozeConversation
              ? 'bg-n-brand border-n-brand'
              : 'bg-transparent border-n-weak group-hover:border-n-brand/50'"
          >
            <i v-if="snoozeConversation" class="i-lucide-check text-white" style="font-size:10px" />
          </div>
          <input v-model="snoozeConversation" type="checkbox" class="sr-only" />
          <div class="flex items-center gap-1.5">
            <i class="i-lucide-alarm-clock text-n-slate-10 text-sm" />
            <span class="text-sm text-n-slate-11">Adiar conversa até o envio</span>
          </div>
        </label>

        <!-- Schedule button -->
        <Button
          :disabled="!canSchedule"
          :is-loading="uiFlags.isCreating"
          class="w-full"
          :color="isPrivate ? 'amber' : 'blue'"
          @click="schedule"
        >
          <i :class="isPrivate ? 'i-lucide-lock' : 'i-lucide-send'" class="mr-1.5 text-sm" />
          {{ isPrivate ? 'Agendar nota privada' : 'Agendar envio' }}
        </Button>
      </div>

      <!-- Scheduled messages list -->
      <div
        v-if="scheduledMessages.length || uiFlags.isFetching"
        class="border-t border-n-weak"
      >
        <div class="px-6 py-3 flex items-center gap-2">
          <i class="i-lucide-list-clock text-n-slate-10 text-sm" />
          <span class="text-xs font-semibold text-n-slate-11 uppercase tracking-wide">
            Histórico de agendamentos
          </span>
          <span class="ml-auto text-[10px] text-n-slate-9">
            {{ scheduledMessages.filter(m => m.status === 'pending').length }} pendente(s)
          </span>
        </div>

        <div v-if="uiFlags.isFetching" class="flex justify-center py-6">
          <i class="i-lucide-loader-2 animate-spin text-xl text-n-brand" />
        </div>

        <div v-else class="px-4 pb-4 space-y-2 max-h-64 overflow-y-auto">
          <div
            v-for="msg in scheduledMessages"
            :key="msg.id"
            class="group flex items-start gap-3 p-3 rounded-xl border transition-all"
            :class="{
              'bg-n-surface-1 border-n-weak hover:border-n-brand/30': msg.status === 'pending',
              'bg-n-alpha-1 border-n-weak/50 opacity-70': msg.status === 'sent',
              'bg-n-ruby-9/5 border-n-ruby-9/20': msg.status === 'failed',
            }"
          >
            <!-- Icon -->
            <div class="flex-shrink-0 mt-0.5">
              <div
                class="w-7 h-7 rounded-lg flex items-center justify-center"
                :class="{
                  'bg-n-brand/10': msg.status === 'pending' && !msg.is_private,
                  'bg-n-yellow-9/10': msg.status === 'pending' && msg.is_private,
                  'bg-n-slate-3': msg.status === 'sent',
                  'bg-n-ruby-9/10': msg.status === 'failed',
                }"
              >
                <i
                  class="text-xs"
                  :class="{
                    'i-lucide-send text-n-brand': msg.status === 'pending' && !msg.is_private,
                    'i-lucide-lock text-n-yellow-10': msg.status === 'pending' && msg.is_private,
                    'i-lucide-check-circle text-n-slate-9': msg.status === 'sent',
                    'i-lucide-alert-circle text-n-ruby-9': msg.status === 'failed',
                  }"
                />
              </div>
            </div>

            <!-- Content -->
            <div class="flex-1 min-w-0">
              <p class="text-sm line-clamp-2" :class="msg.status === 'sent' ? 'text-n-slate-10' : 'text-n-slate-12'">
                {{ msg.content }}
              </p>
              <div class="flex items-center flex-wrap gap-2 mt-1">
                <div class="flex items-center gap-1 text-xs text-n-slate-9">
                  <i class="i-lucide-clock text-[10px]" />
                  <span>{{ formatDate(msg.scheduled_at) }}</span>
                </div>
                <!-- Status badge -->
                <span
                  v-if="msg.status === 'sent'"
                  class="text-[10px] px-1.5 py-0.5 rounded bg-n-slate-3 text-n-slate-9 font-medium"
                >
                  enviada
                </span>
                <span
                  v-else-if="msg.status === 'failed'"
                  class="text-[10px] px-1.5 py-0.5 rounded bg-n-ruby-9/10 text-n-ruby-9 font-medium"
                >
                  falhou
                </span>
                <span
                  v-if="msg.is_private"
                  class="text-[10px] px-1.5 py-0.5 rounded bg-n-yellow-9/10 text-n-yellow-10 font-medium"
                >
                  privada
                </span>
                <span
                  v-if="msg.signed_ids && msg.signed_ids.length"
                  class="flex items-center gap-0.5 text-[10px] text-n-slate-9"
                >
                  <i class="i-lucide-paperclip text-[9px]" />
                  {{ msg.signed_ids.length }}
                </span>
              </div>
            </div>

            <!-- Cancel button (only for pending) -->
            <button
              v-if="msg.status === 'pending'"
              v-tooltip.top="'Cancelar'"
              class="flex-shrink-0 opacity-0 group-hover:opacity-100 p-1.5 rounded-lg text-n-slate-9 hover:text-n-ruby-9 hover:bg-n-ruby-9/10 transition-all"
              :disabled="uiFlags.isCancelling"
              @click="cancelMessage(msg.id)"
            >
              <i class="i-lucide-x text-sm" />
            </button>
          </div>
        </div>
      </div>

      <!-- Empty state -->
      <div
        v-else-if="!uiFlags.isFetching"
        class="border-t border-n-weak px-6 py-4 flex items-center gap-2 text-xs text-n-slate-9"
      >
        <i class="i-lucide-info text-sm flex-shrink-0" />
        <span>Nenhuma mensagem agendada para esta conversa</span>
      </div>
    </div>
  </Modal>
</template>
