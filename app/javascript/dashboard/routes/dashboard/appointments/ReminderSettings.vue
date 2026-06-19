<script setup>
import { ref, computed, watch } from 'vue';
import { useStore } from 'vuex';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';

const emit = defineEmits(['close']);
const store = useStore();
const { accountId } = useAccount();

// ── account data ──────────────────────────────────────────────────────────────
const account = computed(() => store.getters['accounts/getAccount'](accountId.value) ?? {});
const settings = computed(() => account.value?.settings ?? {});

// ── form state ────────────────────────────────────────────────────────────────
const enabled      = ref(false);
const hoursBefore  = ref(2);
const message      = ref('');
const templateCfg  = ref({ name: '', language: 'pt_BR', body_params: [] });

const DEFAULT_MESSAGE = 'Olá {{contact_name}}! Passando para lembrar do seu horário dia {{date}} às {{time}} com {{professional}}. Posso confirmar? 💈';

const APPOINTMENT_VARS = [
  { value: 'contact_name', label: 'Nome do cliente' },
  { value: 'date',         label: 'Data' },
  { value: 'time',         label: 'Hora' },
  { value: 'professional', label: 'Profissional' },
  { value: 'service',      label: 'Serviço' },
];

const VAR_EXAMPLES = {
  contact_name: 'João Silva',
  date:         '17/06/2026',
  time:         '14:00',
  professional: 'Carlos',
  service:      'Corte',
};

// Populate from account settings when loaded
watch(settings, (s) => {
  enabled.value     = !!s.appointment_reminder_enabled;
  hoursBefore.value = s.appointment_reminder_hours_before ? Number(s.appointment_reminder_hours_before) : 2;
  message.value     = s.appointment_reminder_message || '';
  if (s.appointment_reminder_template) {
    templateCfg.value = {
      name:        s.appointment_reminder_template.name || '',
      language:    s.appointment_reminder_template.language || 'pt_BR',
      body_params: s.appointment_reminder_template.body_params || [],
    };
  }
}, { immediate: true });

// ── WhatsApp inboxes with approved templates ───────────────────────────────────
const inboxes = computed(() => store.getters['inboxes/getInboxes'] ?? []);
const whatsappInboxes = computed(() =>
  inboxes.value.filter(i =>
    i.channel_type === 'Channel::Whatsapp' &&
    Array.isArray(i.message_templates) &&
    i.message_templates.some(t => (t.status || '').toLowerCase() === 'approved')
  )
);
const hasWhatsappInboxes = computed(() => whatsappInboxes.value.length > 0);

// All approved templates across all WhatsApp inboxes (deduplicated by name+language)
const approvedTemplates = computed(() => {
  const seen = new Set();
  const result = [];
  for (const inbox of whatsappInboxes.value) {
    for (const t of (inbox.message_templates || [])) {
      if ((t.status || '').toLowerCase() !== 'approved') continue;
      const key = `${t.name}|${t.language}`;
      if (seen.has(key)) continue;
      seen.add(key);
      result.push(t);
    }
  }
  return result;
});

// ── selected template details ─────────────────────────────────────────────────
const selectedTemplate = computed(() =>
  approvedTemplates.value.find(
    t => t.name === templateCfg.value.name && t.language === templateCfg.value.language
  ) ?? null
);

// BODY component text from the template
const bodyComponent = computed(() =>
  selectedTemplate.value?.components?.find(c => (c.type || '').toUpperCase() === 'BODY') ?? null
);

// Count of positional slots ({{1}}, {{2}}, ...) in the body text
const slotCount = computed(() => {
  const text = bodyComponent.value?.text || '';
  const matches = text.match(/\{\{\d+\}\}/g) || [];
  return matches.length;
});

// Ensure body_params array has the right length when template changes
watch([selectedTemplate], () => {
  if (!selectedTemplate.value) return;
  const needed = slotCount.value;
  const current = templateCfg.value.body_params || [];
  if (current.length !== needed) {
    templateCfg.value.body_params = Array.from({ length: needed }, (_, i) => current[i] || '');
  }
});

function onTemplateSelect(e) {
  const val = e.target.value;
  if (!val) {
    templateCfg.value = { name: '', language: 'pt_BR', body_params: [] };
    return;
  }
  const [name, language] = val.split('|');
  const tmpl = approvedTemplates.value.find(t => t.name === name && t.language === language);
  if (!tmpl) return;
  const needed = (tmpl.components?.find(c => (c.type||'').toUpperCase() === 'BODY')?.text || '')
    .match(/\{\{\d+\}\}/g)?.length || 0;
  templateCfg.value = {
    name,
    language,
    body_params: Array.from({ length: needed }, () => ''),
  };
}

function slotLabel(idx) { return '{{' + idx + '}}'; }
function varToken(name)  { return '{{' + name + '}}'; }

// ref for the textarea so we can insert at cursor
const msgTextarea = ref(null);

function insertVar(name) {
  const token = '{{' + name + '}}';
  const el = msgTextarea.value;
  if (!el) { message.value = (message.value || '') + token; return; }
  const start = el.selectionStart ?? message.value.length;
  const end   = el.selectionEnd   ?? message.value.length;
  const cur   = message.value || '';
  message.value = cur.slice(0, start) + token + cur.slice(end);
  // restore cursor after the inserted token
  const newPos = start + token.length;
  el.focus();
  requestAnimationFrame(() => { el.setSelectionRange(newPos, newPos); });
}

function setBodyParam(idx, val) {
  const arr = [...(templateCfg.value.body_params || [])];
  arr[idx] = val;
  templateCfg.value.body_params = arr;
}

// ── preview (text message) ─────────────────────────────────────────────────────
const preview = computed(() => {
  const tpl = message.value || DEFAULT_MESSAGE;
  return tpl
    .replace('{{contact_name}}', 'João Silva')
    .replace('{{date}}', '17/06/2026')
    .replace('{{time}}', '14:00')
    .replace('{{professional}}', 'Carlos')
    .replace('{{service}}', 'Corte');
});

// ── save ──────────────────────────────────────────────────────────────────────
const saving = ref(false);

async function save() {
  saving.value = true;
  try {
    const payload = {
      appointment_reminder_enabled:      enabled.value,
      appointment_reminder_hours_before: hoursBefore.value,
      appointment_reminder_message:      message.value || null,
    };
    if (templateCfg.value.name) {
      payload.appointment_reminder_template = {
        name:        templateCfg.value.name,
        language:    templateCfg.value.language,
        body_params: templateCfg.value.body_params,
      };
    } else {
      payload.appointment_reminder_template = null;
    }
    await store.dispatch('accounts/update', payload);
    useAlert('Configurações de lembrete salvas!');
    emit('close');
  } catch {
    useAlert('Erro ao salvar. Tente novamente.');
  } finally {
    saving.value = false;
  }
}
</script>

<template>
  <!-- Overlay -->
  <div class="mo-overlay" @click.self="$emit('close')">
    <div class="mo-box" style="max-width:520px">

      <!-- Header -->
      <div class="mo-head">
        <div style="display:flex;align-items:center;gap:8px">
          <span class="i-lucide-bell" style="font-size:16px;color:rgb(var(--n-brand,66 65 255))" />
          <span class="mo-head-title">Lembretes automáticos</span>
        </div>
        <button class="mo-x" @click="$emit('close')">
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 6L6 18M6 6l12 12"/></svg>
        </button>
      </div>

      <!-- Form -->
      <div class="mo-form">

        <!-- Ativar toggle -->
        <div style="display:flex;align-items:center;justify-content:space-between;padding:10px 14px;border-radius:10px;background:rgb(var(--surface-2,245 247 251));border:1px solid rgb(var(--border-weak))">
          <div>
            <p style="font-size:13px;font-weight:700;color:rgb(var(--slate-12));margin:0">Ativar lembrete automático</p>
            <p style="font-size:11px;color:rgb(var(--slate-8));margin:2px 0 0">Envia mensagem ao cliente antes do horário agendado</p>
          </div>
          <!-- Toggle switch -->
          <button
            :style="{
              width: '40px', height: '22px', borderRadius: '11px', border: 'none', cursor: 'pointer',
              background: enabled ? 'rgb(var(--n-brand,66 65 255))' : 'rgb(var(--slate-6,148 163 184))',
              position: 'relative', transition: 'background .2s', flexShrink: '0'
            }"
            @click="enabled = !enabled"
          >
            <span :style="{
              position: 'absolute', top: '3px',
              left: enabled ? '21px' : '3px',
              width: '16px', height: '16px', borderRadius: '50%',
              background: '#fff', transition: 'left .2s', display: 'block'
            }" />
          </button>
        </div>

        <template v-if="enabled">

          <!-- Horas antes -->
          <div class="mo-field">
            <label class="mo-lbl">Enviar quantas horas antes?</label>
            <div style="display:flex;align-items:center;gap:8px">
              <input
                v-model.number="hoursBefore"
                type="number" min="1" max="168"
                class="mo-inp"
                style="width:90px"
              />
              <span style="font-size:12px;color:rgb(var(--slate-8))">hora(s) antes do agendamento</span>
            </div>
          </div>

          <!-- Mensagem texto livre -->
          <div class="mo-field">
            <label class="mo-lbl">Mensagem (texto livre)</label>
            <p style="font-size:11px;color:rgb(var(--slate-8));margin:0 0 6px;line-height:1.5">
              Clique numa variável para inserir no cursor:
            </p>
            <div class="var-chips">
              <button
                v-for="v in APPOINTMENT_VARS"
                :key="v.value"
                class="var-chip"
                type="button"
                :title="v.label"
                @click="insertVar(v.value)"
              >{{ varToken(v.value) }}</button>
            </div>
            <textarea
              ref="msgTextarea"
              v-model="message"
              class="mo-inp"
              rows="3"
              :placeholder="DEFAULT_MESSAGE"
            />
            <p style="font-size:11px;color:rgb(var(--slate-8));margin:4px 0 0">
              Usado quando o cliente respondeu nas últimas 24h (ou provedor não-oficial).
            </p>
          </div>

          <!-- Preview -->
          <div style="border-radius:8px;background:rgb(var(--surface-2));border:1px solid rgb(var(--border-weak));padding:10px 14px">
            <p style="font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.08em;color:rgb(var(--slate-8));margin:0 0 5px">Prévia</p>
            <p style="font-size:12px;color:rgb(var(--slate-12));margin:0;line-height:1.6;white-space:pre-wrap">{{ preview }}</p>
          </div>

          <!-- Template WhatsApp Oficial -->
          <div style="border-top:1px solid rgb(var(--border-weak));padding-top:14px;display:flex;flex-direction:column;gap:12px">
            <div class="mo-field">
              <label class="mo-lbl">Template WhatsApp Oficial (opcional)</label>
              <p style="font-size:11px;color:rgb(var(--slate-8));margin:0 0 6px;line-height:1.5">
                Usado quando o cliente não responde há mais de 24h no WhatsApp Oficial.
                Sem template configurado, o lembrete é pulado nesses casos.
              </p>
              <template v-if="!hasWhatsappInboxes">
                <p style="font-size:11px;color:rgb(var(--slate-8));font-style:italic;margin:0">
                  Nenhuma caixa WhatsApp Oficial encontrada. Quando adicionar uma, os templates aprovados aparecerão aqui.
                </p>
              </template>
              <template v-else>
                <select
                  class="mo-inp"
                  :value="templateCfg.name ? `${templateCfg.name}|${templateCfg.language}` : ''"
                  @change="onTemplateSelect"
                >
                  <option value="">— não usar template —</option>
                  <option
                    v-for="t in approvedTemplates"
                    :key="`${t.name}|${t.language}`"
                    :value="`${t.name}|${t.language}`"
                  >
                    {{ t.name }} · {{ t.language }}
                  </option>
                </select>
              </template>
            </div>

            <!-- Body + mapeamento de slots -->
            <template v-if="selectedTemplate && bodyComponent">
              <div style="border-radius:8px;background:rgb(var(--surface-2));border:1px solid rgb(var(--border-weak));padding:10px 12px">
                <p style="font-size:10px;font-weight:700;text-transform:uppercase;letter-spacing:.08em;color:rgb(var(--slate-8));margin:0 0 4px">Texto do template</p>
                <p style="font-size:12px;color:rgb(var(--slate-12));margin:0;line-height:1.6;white-space:pre-wrap">{{ bodyComponent.text }}</p>
              </div>

              <div v-if="slotCount > 0" class="mo-field">
                <label class="mo-lbl">Mapear slots → variáveis do agendamento</label>
                <div style="display:flex;flex-direction:column;gap:8px">
                  <div
                    v-for="idx in slotCount"
                    :key="idx"
                    style="display:flex;align-items:center;gap:8px"
                  >
                    <span style="font-size:11px;font-weight:700;font-family:monospace;color:rgb(var(--slate-10));width:36px;flex-shrink:0">{{ slotLabel(idx) }}</span>
                    <select
                      class="mo-inp"
                      style="flex:1"
                      :value="templateCfg.body_params[idx-1] || ''"
                      @change="setBodyParam(idx-1, $event.target.value)"
                    >
                      <option value="">— escolher variável —</option>
                      <option v-for="v in APPOINTMENT_VARS" :key="v.value" :value="v.value">
                        {{ v.label }} (ex: {{ VAR_EXAMPLES[v.value] }})
                      </option>
                    </select>
                  </div>
                </div>
              </div>
            </template>
          </div>

        </template>

      </div>

      <!-- Footer -->
      <div class="mo-foot">
        <button class="mo-btn-cancel" @click="$emit('close')">Cancelar</button>
        <button
          class="mo-btn-save"
          :disabled="saving"
          @click="save"
        >
          <span v-if="saving">Salvando…</span>
          <span v-else>Salvar</span>
        </button>
      </div>

    </div>
  </div>
</template>

<style scoped>
.mo-overlay {
  position: fixed; inset: 0; z-index: 9999;
  display: flex; align-items: center; justify-content: center;
  padding: 16px;
  background: rgba(0, 0, 0, 0.65);
  backdrop-filter: blur(8px);
}
.mo-box {
  position: relative; width: 100%; max-width: 520px; max-height: 90vh;
  background: rgb(var(--surface-1));
  border: 1px solid rgb(var(--border-strong));
  border-radius: 14px;
  box-shadow: 0 24px 64px rgba(0, 0, 0, 0.4);
  display: flex; flex-direction: column; overflow: hidden;
}
.mo-head {
  display: flex; align-items: center; justify-content: space-between;
  padding: 16px 20px;
  border-bottom: 1px solid rgb(var(--border-weak));
  flex-shrink: 0;
}
.mo-head-title { font-size: 15px; font-weight: 700; color: rgb(var(--slate-12)); }
.mo-x {
  background: none; border: none; cursor: pointer;
  color: rgb(var(--slate-8)); display: flex; transition: color .12s;
}
.mo-x:hover { color: rgb(var(--slate-12)); }
.mo-form {
  flex: 1; overflow-y: auto; padding: 16px 20px;
  display: flex; flex-direction: column; gap: 14px;
}
.mo-field { display: flex; flex-direction: column; gap: 5px; }
.mo-lbl {
  font-size: 10px; font-weight: 700; text-transform: uppercase;
  letter-spacing: .1em; color: rgb(var(--slate-8));
}
.mo-inp {
  width: 100%; height: 34px; padding: 0 10px; border-radius: 8px;
  border: 1px solid rgb(var(--border-strong));
  background: rgb(var(--background-color));
  color: rgb(var(--slate-12)); font-size: 12px; font-family: inherit;
  outline: none; transition: border-color .15s;
}
.mo-inp:focus { border-color: rgb(var(--n-brand, 66 65 255)); }
textarea.mo-inp { height: auto; padding: 8px 10px; }
.mo-foot {
  display: flex; align-items: center; justify-content: flex-end; gap: 8px;
  padding: 14px 20px;
  border-top: 1px solid rgb(var(--border-weak));
}
.mo-btn-cancel {
  height: 32px; padding: 0 14px; border-radius: 8px;
  border: 1px solid rgb(var(--border-strong));
  background: transparent; color: rgb(var(--slate-10));
  font-size: 12px; font-weight: 600; cursor: pointer; transition: background .12s;
}
.mo-btn-cancel:hover { background: rgb(var(--surface-2)); }
.mo-btn-save {
  height: 32px; padding: 0 16px; border-radius: 8px;
  background: rgb(var(--n-brand, 66 65 255)); color: #fff;
  font-size: 12px; font-weight: 700; border: none; cursor: pointer; transition: opacity .15s;
}
.mo-btn-save:hover:not(:disabled) { opacity: .88; }
.mo-btn-save:disabled { opacity: .5; cursor: not-allowed; }

/* variable chips */
.var-chips { display: flex; flex-wrap: wrap; gap: 5px; margin-bottom: 6px; }
.var-chip {
  padding: 3px 8px; border-radius: 6px; font-size: 10px; font-weight: 600; font-family: monospace;
  background: rgb(var(--surface-2)); color: rgb(var(--slate-11));
  border: 1px solid rgb(var(--border-strong)); cursor: pointer; transition: background .12s;
}
.var-chip:hover { background: rgb(var(--surface-3, 230 232 240)); }
</style>
