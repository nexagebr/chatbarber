<script setup>
/* global axios */
import { ref, computed, watch } from 'vue';
import { useStore } from 'vuex';
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
    } catch {
      entry.uploading = false;
      entry.error = 'Erro ao enviar';
    }
  }
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

const removeFile = idx => { attachedFiles.value.splice(idx, 1); };

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
    const signedIds = attachedFiles.value.filter(f => f.signedId).map(f => f.signedId);
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
    scheduleError.value = e?.response?.data?.errors?.[0] || e?.response?.data?.error || 'Erro ao agendar mensagem';
  }
};

const cancelMessage = async id => {
  if (!confirm('Cancelar esta mensagem agendada?')) return;
  await store.dispatch('scheduledMessages/cancel', { conversationId: props.conversationId, id });
};

const close = () => emit('close');
</script>

<template>
  <Teleport to="body">
    <div v-if="show" class="smo-overlay" @click.self="close">
      <div class="smo-box">

        <!-- Header -->
        <div class="smo-head">
          <div style="display:flex;align-items:center;gap:8px">
            <span class="i-lucide-clock" style="font-size:15px;color:rgb(var(--n-brand,66 65 255));flex-shrink:0" />
            <span class="smo-title">Agendar mensagem</span>
          </div>
          <button class="smo-x" @click="close">
            <span class="i-lucide-x" style="font-size:15px" />
          </button>
        </div>

        <!-- Form -->
        <div class="smo-form">

          <!-- Tipo: público / privado -->
          <div class="smo-field">
            <label class="smo-lbl">Tipo</label>
            <div style="display:flex;gap:6px">
              <button
                type="button"
                class="smo-type-btn"
                :class="!isPrivate && 'smo-type-btn--on'"
                @click="isPrivate = false"
              >
                <span class="i-lucide-send" style="font-size:11px" />
                Resposta pública
              </button>
              <button
                type="button"
                class="smo-type-btn"
                :class="isPrivate && 'smo-type-btn--private'"
                @click="isPrivate = true"
              >
                <span class="i-lucide-lock" style="font-size:11px" />
                Nota privada
              </button>
            </div>
          </div>

          <!-- Mensagem -->
          <div class="smo-field">
            <label class="smo-lbl">Mensagem</label>
            <textarea
              v-model="messageContent"
              rows="4"
              placeholder="Digite a mensagem que será enviada…"
              class="smo-inp"
              :class="isPrivate && 'smo-inp--private'"
              style="height:auto;padding:8px 10px;resize:none"
            />
          </div>

          <!-- Data e horário -->
          <div class="smo-field">
            <label class="smo-lbl">Data e horário de envio</label>
            <input
              v-model="scheduledAt"
              type="datetime-local"
              :min="minDateTime"
              class="smo-inp reset-base"
            />
          </div>

          <!-- Anexos -->
          <div class="smo-field">
            <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:6px">
              <label class="smo-lbl" style="margin:0">Anexos <span style="font-weight:400;text-transform:none;letter-spacing:0;color:rgb(var(--slate-9))">(opcional)</span></label>
              <button type="button" class="smo-attach-btn" @click="fileInputRef.click()">
                <span class="i-lucide-paperclip" style="font-size:11px" />
                Adicionar
              </button>
              <input ref="fileInputRef" type="file" multiple class="hidden" @change="onFilesPicked" />
            </div>
            <div v-if="attachedFiles.length" style="display:flex;flex-direction:column;gap:6px">
              <div
                v-for="(f, idx) in attachedFiles"
                :key="idx"
                class="smo-file-row"
              >
                <div class="smo-file-icon">
                  <span v-if="f.uploading" class="i-lucide-loader-2 animate-spin" style="font-size:11px;color:rgb(var(--n-brand,66 65 255))" />
                  <span v-else-if="f.error" class="i-lucide-alert-circle" style="font-size:11px;color:#ef4444" />
                  <span v-else class="i-lucide-file" style="font-size:11px;color:rgb(var(--slate-9))" />
                </div>
                <div style="flex:1;min-width:0">
                  <p style="font-size:12px;font-weight:600;color:rgb(var(--slate-12));margin:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">{{ f.name }}</p>
                  <p style="font-size:10px;color:rgb(var(--slate-8));margin:0">
                    <span v-if="f.uploading">Enviando…</span>
                    <span v-else-if="f.error" style="color:#ef4444">{{ f.error }}</span>
                    <span v-else>{{ formatFileSize(f.size) }}</span>
                  </p>
                </div>
                <button type="button" class="smo-file-rm" @click="removeFile(idx)">
                  <span class="i-lucide-x" style="font-size:11px" />
                </button>
              </div>
            </div>
          </div>

          <!-- Adiar conversa -->
          <label class="smo-check-row" style="cursor:pointer">
            <div
              class="smo-check"
              :class="snoozeConversation && 'smo-check--on'"
              @click="snoozeConversation = !snoozeConversation"
            >
              <span v-if="snoozeConversation" class="i-lucide-check" style="font-size:9px;color:#fff" />
            </div>
            <input v-model="snoozeConversation" type="checkbox" class="hidden" />
            <span class="i-lucide-alarm-clock" style="font-size:13px;color:rgb(var(--slate-9))" />
            <span style="font-size:12px;color:rgb(var(--slate-11))">Adiar conversa até o envio</span>
          </label>

          <!-- Erro -->
          <div v-if="scheduleError" class="smo-error">
            <span class="i-lucide-alert-circle" style="font-size:12px;flex-shrink:0" />
            {{ scheduleError }}
          </div>

        </div>

        <!-- Footer -->
        <div class="smo-foot">
          <button type="button" class="smo-btn-cancel" @click="close">Cancelar</button>
          <button
            type="button"
            class="smo-btn-save"
            :class="isPrivate && 'smo-btn-save--private'"
            :disabled="!canSchedule || uiFlags.isCreating"
            @click="schedule"
          >
            <span v-if="uiFlags.isCreating" class="i-lucide-loader-2 animate-spin" style="font-size:11px" />
            <span v-else :class="isPrivate ? 'i-lucide-lock' : 'i-lucide-send'" style="font-size:11px" />
            {{ isPrivate ? 'Agendar nota privada' : 'Agendar envio' }}
          </button>
        </div>

        <!-- Lista de agendamentos -->
        <div v-if="scheduledMessages.length || uiFlags.isFetching" class="smo-history">
          <div class="smo-history-head">
            <span class="i-lucide-list-clock" style="font-size:12px;color:rgb(var(--slate-9))" />
            <span class="smo-lbl" style="margin:0">Agendamentos</span>
            <span style="margin-left:auto;font-size:10px;color:rgb(var(--slate-9))">
              {{ scheduledMessages.filter(m => m.status === 'pending').length }} pendente(s)
            </span>
          </div>

          <div v-if="uiFlags.isFetching" style="display:flex;justify-content:center;padding:16px">
            <span class="i-lucide-loader-2 animate-spin" style="font-size:18px;color:rgb(var(--n-brand,66 65 255))" />
          </div>

          <div v-else class="smo-msg-list">
            <div
              v-for="msg in scheduledMessages"
              :key="msg.id"
              class="smo-msg-row"
              :class="{
                'smo-msg-row--sent': msg.status === 'sent',
                'smo-msg-row--failed': msg.status === 'failed',
              }"
            >
              <div
                class="smo-msg-icon"
                :class="{
                  'smo-msg-icon--brand': msg.status === 'pending' && !msg.is_private,
                  'smo-msg-icon--private': msg.status === 'pending' && msg.is_private,
                  'smo-msg-icon--sent': msg.status === 'sent',
                  'smo-msg-icon--failed': msg.status === 'failed',
                }"
              >
                <span
                  style="font-size:10px"
                  :class="{
                    'i-lucide-send': msg.status === 'pending' && !msg.is_private,
                    'i-lucide-lock': msg.status === 'pending' && msg.is_private,
                    'i-lucide-check-circle': msg.status === 'sent',
                    'i-lucide-alert-circle': msg.status === 'failed',
                  }"
                />
              </div>
              <div style="flex:1;min-width:0">
                <p class="smo-msg-content" :class="msg.status === 'sent' && 'smo-msg-content--dim'">
                  {{ msg.content || '(sem texto)' }}
                </p>
                <div style="display:flex;align-items:center;flex-wrap:wrap;gap:6px;margin-top:3px">
                  <span style="display:flex;align-items:center;gap:3px;font-size:10px;color:rgb(var(--slate-8))">
                    <span class="i-lucide-clock" style="font-size:9px" />
                    {{ formatDate(msg.scheduled_at) }}
                  </span>
                  <span v-if="msg.status === 'sent'" class="smo-badge smo-badge--sent">enviada</span>
                  <span v-else-if="msg.status === 'failed'" class="smo-badge smo-badge--failed">falhou</span>
                  <span v-if="msg.is_private" class="smo-badge smo-badge--private">privada</span>
                  <span v-if="msg.signed_ids?.length" style="display:flex;align-items:center;gap:2px;font-size:10px;color:rgb(var(--slate-8))">
                    <span class="i-lucide-paperclip" style="font-size:9px" />{{ msg.signed_ids.length }}
                  </span>
                </div>
              </div>
              <button
                v-if="msg.status === 'pending'"
                v-tooltip.top="'Cancelar'"
                class="smo-msg-cancel"
                :disabled="uiFlags.isCancelling"
                @click="cancelMessage(msg.id)"
              >
                <span class="i-lucide-x" style="font-size:11px" />
              </button>
            </div>
          </div>
        </div>

        <div v-else-if="!uiFlags.isFetching" class="smo-empty">
          <span class="i-lucide-calendar-x" style="font-size:12px;flex-shrink:0" />
          Nenhuma mensagem agendada para esta conversa
        </div>

      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.smo-overlay {
  position: fixed; inset: 0; z-index: 9999;
  display: flex; align-items: center; justify-content: center; padding: 16px;
  background: rgba(0,0,0,.65);
  backdrop-filter: blur(8px);
}
.smo-box {
  position: relative; width: 100%; max-width: 480px; max-height: 90vh;
  background: rgb(var(--surface-1));
  border: 1px solid rgb(var(--border-strong));
  border-radius: 14px;
  box-shadow: 0 24px 64px rgba(0,0,0,.4);
  display: flex; flex-direction: column; overflow: hidden;
}

/* Head */
.smo-head {
  display: flex; align-items: center; justify-content: space-between;
  padding: 16px 20px; border-bottom: 1px solid rgb(var(--border-weak)); flex-shrink: 0;
}
.smo-title { font-size: 15px; font-weight: 700; color: rgb(var(--slate-12)); }
.smo-x {
  background: none; border: none; cursor: pointer;
  color: rgb(var(--slate-8)); display: flex; transition: color .12s;
}
.smo-x:hover { color: rgb(var(--slate-12)); }

/* Form */
.smo-form {
  flex: 1; overflow-y: auto; padding: 16px 20px;
  display: flex; flex-direction: column; gap: 14px;
}
.smo-field { display: flex; flex-direction: column; gap: 5px; }
.smo-lbl {
  font-size: 10px; font-weight: 700; text-transform: uppercase;
  letter-spacing: .1em; color: rgb(var(--slate-8));
}

/* Type toggle */
.smo-type-btn {
  display: inline-flex; align-items: center; gap: 5px;
  padding: 5px 10px; border-radius: 20px; cursor: pointer;
  font-size: 11px; font-weight: 600;
  background: rgb(var(--background-color));
  border: 1px solid rgb(var(--border-weak));
  color: rgb(var(--slate-10)); transition: all .12s; font-family: inherit;
}
.smo-type-btn:hover { color: rgb(var(--slate-12)); border-color: rgb(var(--border-strong)); }
.smo-type-btn--on { background: rgba(66,65,255,.15); border-color: rgba(66,65,255,.5); color: rgb(var(--n-brand,66 65 255)); }
.smo-type-btn--private { background: rgba(234,179,8,.15); border-color: rgba(234,179,8,.5); color: #a16207; }

/* Inputs */
.smo-inp {
  width: 100%; height: 34px; padding: 0 10px; border-radius: 8px;
  border: 1px solid rgb(var(--border-strong));
  background: rgb(var(--background-color));
  color: rgb(var(--slate-12)); font-size: 12px; font-family: inherit;
  outline: none; transition: border-color .15s; box-sizing: border-box;
}
.smo-inp:focus { border-color: rgb(var(--n-brand,66 65 255)); }
.smo-inp--private:focus { border-color: #ca8a04; }
textarea.smo-inp { height: auto; }

/* Attachments */
.smo-attach-btn {
  display: inline-flex; align-items: center; gap: 4px;
  font-size: 11px; font-weight: 600; color: rgb(var(--n-brand,66 65 255));
  background: none; border: none; cursor: pointer; font-family: inherit;
  transition: opacity .12s;
}
.smo-attach-btn:hover { opacity: .75; }
.smo-file-row {
  display: flex; align-items: center; gap: 8px;
  padding: 6px 10px; border-radius: 8px;
  border: 1px solid rgb(var(--border-weak));
  background: rgb(var(--surface-2));
}
.smo-file-icon {
  width: 24px; height: 24px; border-radius: 6px;
  background: rgb(var(--background-color));
  border: 1px solid rgb(var(--border-weak));
  display: flex; align-items: center; justify-content: center; flex-shrink: 0;
}
.smo-file-rm {
  background: none; border: none; cursor: pointer; padding: 3px;
  color: rgb(var(--slate-8)); border-radius: 4px; display: flex;
  transition: color .12s;
}
.smo-file-rm:hover { color: #ef4444; }

/* Checkbox */
.smo-check-row { display: flex; align-items: center; gap: 8px; }
.smo-check {
  width: 15px; height: 15px; border-radius: 4px; flex-shrink: 0;
  border: 1.5px solid rgb(var(--border-strong));
  background: transparent; display: flex; align-items: center; justify-content: center;
  transition: all .12s;
}
.smo-check--on { background: rgb(var(--n-brand,66 65 255)); border-color: rgb(var(--n-brand,66 65 255)); }

/* Error */
.smo-error {
  display: flex; align-items: center; gap: 6px;
  padding: 8px 10px; border-radius: 8px;
  background: rgba(239,68,68,.1); border: 1px solid rgba(239,68,68,.3);
  font-size: 12px; color: #ef4444;
}

/* Footer */
.smo-foot {
  display: flex; align-items: center; justify-content: flex-end; gap: 8px;
  padding: 14px 20px; border-top: 1px solid rgb(var(--border-weak)); flex-shrink: 0;
}
.smo-btn-cancel {
  height: 32px; padding: 0 14px; border-radius: 8px;
  border: 1px solid rgb(var(--border-strong)); background: transparent;
  color: rgb(var(--slate-10)); font-size: 12px; font-weight: 600;
  cursor: pointer; font-family: inherit; transition: background .12s;
}
.smo-btn-cancel:hover { background: rgb(var(--surface-2)); }
.smo-btn-save {
  height: 32px; padding: 0 16px; border-radius: 8px;
  background: rgb(var(--n-brand,66 65 255)); color: #fff;
  font-size: 12px; font-weight: 700; border: none; cursor: pointer;
  font-family: inherit; transition: opacity .15s;
  display: inline-flex; align-items: center; gap: 5px;
}
.smo-btn-save:hover:not(:disabled) { opacity: .88; }
.smo-btn-save:disabled { opacity: .45; cursor: not-allowed; }
.smo-btn-save--private { background: #ca8a04; }

/* History */
.smo-history { border-top: 1px solid rgb(var(--border-weak)); flex-shrink: 0; }
.smo-history-head {
  display: flex; align-items: center; gap: 6px;
  padding: 10px 20px; border-bottom: 1px solid rgb(var(--border-weak));
}
.smo-msg-list {
  display: flex; flex-direction: column; gap: 0;
  max-height: 220px; overflow-y: auto;
}
.smo-msg-row {
  display: flex; align-items: flex-start; gap: 10px;
  padding: 10px 20px; border-bottom: 1px solid rgb(var(--border-weak));
  transition: background .1s;
}
.smo-msg-row:last-child { border-bottom: none; }
.smo-msg-row:hover { background: rgb(var(--surface-2)); }
.smo-msg-row--sent { opacity: .65; }
.smo-msg-row--failed { background: rgba(239,68,68,.04); }
.smo-msg-icon {
  width: 26px; height: 26px; border-radius: 7px;
  display: flex; align-items: center; justify-content: center; flex-shrink: 0; margin-top: 1px;
}
.smo-msg-icon--brand  { background: rgba(66,65,255,.12); color: rgb(var(--n-brand,66 65 255)); }
.smo-msg-icon--private { background: rgba(234,179,8,.12); color: #a16207; }
.smo-msg-icon--sent   { background: rgb(var(--surface-2)); color: rgb(var(--slate-9)); }
.smo-msg-icon--failed { background: rgba(239,68,68,.1);  color: #ef4444; }
.smo-msg-content {
  font-size: 12px; color: rgb(var(--slate-12)); margin: 0;
  display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden;
}
.smo-msg-content--dim { color: rgb(var(--slate-9)); }
.smo-badge {
  font-size: 10px; font-weight: 600;
  padding: 1px 6px; border-radius: 20px;
}
.smo-badge--sent    { background: rgb(var(--surface-2)); color: rgb(var(--slate-9)); }
.smo-badge--failed  { background: rgba(239,68,68,.1); color: #ef4444; }
.smo-badge--private { background: rgba(234,179,8,.12); color: #a16207; }
.smo-msg-cancel {
  background: none; border: none; cursor: pointer; padding: 4px;
  border-radius: 6px; color: rgb(var(--slate-8));
  display: flex; transition: all .12s; flex-shrink: 0;
  opacity: 0;
}
.smo-msg-row:hover .smo-msg-cancel { opacity: 1; }
.smo-msg-cancel:hover { color: #ef4444; background: rgba(239,68,68,.1); }
.smo-msg-cancel:disabled { opacity: .4; cursor: not-allowed; }

/* Empty */
.smo-empty {
  display: flex; align-items: center; gap: 6px;
  padding: 12px 20px; border-top: 1px solid rgb(var(--border-weak));
  font-size: 11px; color: rgb(var(--slate-9)); flex-shrink: 0;
}
</style>
