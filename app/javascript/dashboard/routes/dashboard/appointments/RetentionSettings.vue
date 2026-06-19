<script setup>
import { ref, computed, watch } from 'vue';
import { useStore } from 'vuex';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';

const emit = defineEmits(['close']);
const store = useStore();
const { accountId } = useAccount();

// ── account data ──────────────────────────────────────────────────────────────
const account  = computed(() => store.getters['accounts/getAccount'](accountId.value) ?? {});
const settings = computed(() => account.value?.settings ?? {});

// ── form state ────────────────────────────────────────────────────────────────
// Win-back
const winbackEnabled  = ref(false);
const winbackDays     = ref(60);
const winbackMessage  = ref('');
const winbackTemplate = ref({ name: '', language: 'pt_BR', body_params: [] });

// Birthday
const birthdayEnabled  = ref(false);
const birthdayMessage  = ref('');
const birthdayTemplate = ref({ name: '', language: 'pt_BR', body_params: [] });

// Shared
const retentionInboxId = ref('');

const DEFAULT_WINBACK  = 'Olá {{contact_name}}! Sentimos sua falta 😊 Faz {{days_since}} dias desde o seu último {{last_service}}. Que tal marcar um horário? 💈';
const DEFAULT_BIRTHDAY = 'Feliz aniversário, {{contact_name}}! 🎂🎉 Que seu dia seja incrível! Temos um mimo especial esperando por você. Agende já!';

const WINBACK_VARS = [
  { value: 'contact_name',      label: 'Nome do cliente' },
  { value: 'last_service',      label: 'Último serviço' },
  { value: 'last_professional', label: 'Último profissional' },
  { value: 'days_since',        label: 'Dias sem vir' },
];

const BIRTHDAY_VARS = [
  { value: 'contact_name', label: 'Nome do cliente' },
];

const VAR_EXAMPLES_WINBACK = {
  contact_name:      'João Silva',
  last_service:      'Corte',
  last_professional: 'Carlos',
  days_since:        '65',
};

const VAR_EXAMPLES_BIRTHDAY = {
  contact_name: 'João Silva',
};

// Populate from account settings when loaded
watch(settings, (s) => {
  winbackEnabled.value   = !!s.retention_winback_enabled;
  winbackDays.value      = s.retention_winback_days ? Number(s.retention_winback_days) : 60;
  winbackMessage.value   = s.retention_winback_message || '';
  if (s.retention_winback_template) {
    winbackTemplate.value = {
      name:        s.retention_winback_template.name || '',
      language:    s.retention_winback_template.language || 'pt_BR',
      body_params: s.retention_winback_template.body_params || [],
    };
  }

  birthdayEnabled.value  = !!s.retention_birthday_enabled;
  birthdayMessage.value  = s.retention_birthday_message || '';
  if (s.retention_birthday_template) {
    birthdayTemplate.value = {
      name:        s.retention_birthday_template.name || '',
      language:    s.retention_birthday_template.language || 'pt_BR',
      body_params: s.retention_birthday_template.body_params || [],
    };
  }

  retentionInboxId.value = s.retention_inbox_id ? String(s.retention_inbox_id) : '';
}, { immediate: true });

// ── inboxes ───────────────────────────────────────────────────────────────────
const inboxes = computed(() => store.getters['inboxes/getInboxes'] ?? []);

// All inboxes (for the outreach inbox selector)
const allInboxOptions = computed(() =>
  inboxes.value.filter(i => i.id)
);

// WhatsApp Official inboxes with approved templates
const whatsappInboxes = computed(() =>
  inboxes.value.filter(i =>
    i.channel_type === 'Channel::Whatsapp' &&
    Array.isArray(i.message_templates) &&
    i.message_templates.some(t => (t.status || '').toLowerCase() === 'approved')
  )
);
const hasWhatsappInboxes = computed(() => whatsappInboxes.value.length > 0);

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

// ── template helpers ──────────────────────────────────────────────────────────
function getSelectedTemplate(cfg) {
  return approvedTemplates.value.find(
    t => t.name === cfg.name && t.language === cfg.language
  ) ?? null;
}

function getBodyComponent(cfg) {
  const tmpl = getSelectedTemplate(cfg);
  return tmpl?.components?.find(c => (c.type || '').toUpperCase() === 'BODY') ?? null;
}

function getSlotCount(cfg) {
  const text = getBodyComponent(cfg)?.text || '';
  return (text.match(/\{\{\d+\}\}/g) || []).length;
}

function onTemplateSelect(e, cfg) {
  const val = e.target.value;
  if (!val) {
    cfg.name = ''; cfg.language = 'pt_BR'; cfg.body_params = [];
    return;
  }
  const [name, language] = val.split('|');
  const tmpl = approvedTemplates.value.find(t => t.name === name && t.language === language);
  if (!tmpl) return;
  const needed = (tmpl.components?.find(c => (c.type||'').toUpperCase() === 'BODY')?.text || '')
    .match(/\{\{\d+\}\}/g)?.length || 0;
  cfg.name = name;
  cfg.language = language;
  cfg.body_params = Array.from({ length: needed }, () => '');
}

function setBodyParam(cfg, idx, val) {
  const arr = [...(cfg.body_params || [])];
  arr[idx] = val;
  cfg.body_params = arr;
}

function slotLabel(idx) { return '{{' + idx + '}}'; }
function varToken(name)  { return '{{' + name + '}}'; }

// ── textarea insert at cursor ─────────────────────────────────────────────────
const winbackTextarea  = ref(null);
const birthdayTextarea = ref(null);

function insertWinbackVar(name) {
  const token = '{{' + name + '}}';
  const el = winbackTextarea.value;
  if (!el) { winbackMessage.value = (winbackMessage.value || '') + token; return; }
  const start = el.selectionStart ?? winbackMessage.value.length;
  const end   = el.selectionEnd   ?? winbackMessage.value.length;
  const cur   = winbackMessage.value || '';
  winbackMessage.value = cur.slice(0, start) + token + cur.slice(end);
  const newPos = start + token.length;
  el.focus();
  requestAnimationFrame(() => { el.setSelectionRange(newPos, newPos); });
}

function insertBirthdayVar(name) {
  const token = '{{' + name + '}}';
  const el = birthdayTextarea.value;
  if (!el) { birthdayMessage.value = (birthdayMessage.value || '') + token; return; }
  const start = el.selectionStart ?? birthdayMessage.value.length;
  const end   = el.selectionEnd   ?? birthdayMessage.value.length;
  const cur   = birthdayMessage.value || '';
  birthdayMessage.value = cur.slice(0, start) + token + cur.slice(end);
  const newPos = start + token.length;
  el.focus();
  requestAnimationFrame(() => { el.setSelectionRange(newPos, newPos); });
}

// ── previews ──────────────────────────────────────────────────────────────────
const winbackPreview = computed(() => {
  const tpl = winbackMessage.value || DEFAULT_WINBACK;
  return tpl
    .replace(/\{\{contact_name\}\}/g, 'João Silva')
    .replace(/\{\{last_service\}\}/g, 'Corte')
    .replace(/\{\{last_professional\}\}/g, 'Carlos')
    .replace(/\{\{days_since\}\}/g, '65');
});

const birthdayPreview = computed(() => {
  const tpl = birthdayMessage.value || DEFAULT_BIRTHDAY;
  return tpl.replace(/\{\{contact_name\}\}/g, 'João Silva');
});

// ── save ──────────────────────────────────────────────────────────────────────
const saving = ref(false);

async function save() {
  saving.value = true;
  try {
    const payload = {
      retention_winback_enabled:  winbackEnabled.value,
      retention_winback_days:     winbackDays.value,
      retention_winback_message:  winbackMessage.value || null,
      retention_birthday_enabled: birthdayEnabled.value,
      retention_birthday_message: birthdayMessage.value || null,
      retention_inbox_id:         retentionInboxId.value ? Number(retentionInboxId.value) : null,
    };

    payload.retention_winback_template = winbackTemplate.value.name
      ? { name: winbackTemplate.value.name, language: winbackTemplate.value.language, body_params: winbackTemplate.value.body_params }
      : null;

    payload.retention_birthday_template = birthdayTemplate.value.name
      ? { name: birthdayTemplate.value.name, language: birthdayTemplate.value.language, body_params: birthdayTemplate.value.body_params }
      : null;

    await store.dispatch('accounts/update', payload);
    useAlert('Configurações de retenção salvas!');
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
    <div class="mo-box" style="max-width:560px">

      <!-- Header -->
      <div class="mo-head">
        <div style="display:flex;align-items:center;gap:8px">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="rgb(var(--n-brand,66 65 255))" stroke-width="2"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/></svg>
          <span class="mo-head-title">Retenção e fidelização</span>
        </div>
        <button class="mo-x" @click="$emit('close')">
          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 6L6 18M6 6l12 12"/></svg>
        </button>
      </div>

      <!-- Form -->
      <div class="mo-form">

        <!-- ══ SEÇÃO WIN-BACK ════════════════════════════════════════════════ -->
        <div class="mo-section-head">
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="23 4 23 10 17 10"/><polyline points="1 20 1 14 7 14"/><path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"/></svg>
          <span>Cliente sumido</span>
        </div>

        <!-- Toggle win-back -->
        <div class="mo-toggle-row">
          <div>
            <p class="mo-toggle-title">Ativar reativação automática</p>
            <p class="mo-toggle-sub">Envia mensagem quando o cliente não vem há X dias</p>
          </div>
          <button
            :style="{
              width:'40px', height:'22px', borderRadius:'11px', border:'none', cursor:'pointer',
              background: winbackEnabled ? 'rgb(var(--n-brand,66 65 255))' : 'rgb(var(--slate-6,148 163 184))',
              position:'relative', transition:'background .2s', flexShrink:'0'
            }"
            @click="winbackEnabled = !winbackEnabled"
          >
            <span :style="{
              position:'absolute', top:'3px',
              left: winbackEnabled ? '21px' : '3px',
              width:'16px', height:'16px', borderRadius:'50%',
              background:'#fff', transition:'left .2s', display:'block'
            }" />
          </button>
        </div>

        <template v-if="winbackEnabled">

          <!-- Dias sem vir -->
          <div class="mo-field">
            <label class="mo-lbl">Quantos dias sem vir para acionar?</label>
            <div style="display:flex;align-items:center;gap:8px">
              <input v-model.number="winbackDays" type="number" min="7" max="365" class="mo-inp" style="width:90px" />
              <span style="font-size:12px;color:rgb(var(--slate-8))">dias sem agendamento concluído</span>
            </div>
          </div>

          <!-- Mensagem win-back -->
          <div class="mo-field">
            <label class="mo-lbl">Mensagem (texto livre)</label>
            <p style="font-size:11px;color:rgb(var(--slate-8));margin:0 0 6px;line-height:1.5">
              Clique numa variável para inserir no cursor:
            </p>
            <div class="var-chips">
              <button
                v-for="v in WINBACK_VARS" :key="v.value"
                class="var-chip" type="button" :title="v.label"
                @click="insertWinbackVar(v.value)"
              >{{ varToken(v.value) }}</button>
            </div>
            <textarea
              ref="winbackTextarea"
              v-model="winbackMessage"
              class="mo-inp" rows="3"
              :placeholder="DEFAULT_WINBACK"
            />
            <p style="font-size:11px;color:rgb(var(--slate-8));margin:4px 0 0">
              Usado quando o cliente respondeu nas últimas 24h (ou provedor não-oficial).
            </p>
          </div>

          <!-- Preview win-back -->
          <div class="mo-preview-box">
            <p class="mo-preview-label">Prévia</p>
            <p class="mo-preview-text">{{ winbackPreview }}</p>
          </div>

          <!-- Template WhatsApp Oficial win-back -->
          <div style="border-top:1px solid rgb(var(--border-weak));padding-top:14px;display:flex;flex-direction:column;gap:12px">
            <div class="mo-field">
              <label class="mo-lbl">Template WhatsApp Oficial (opcional)</label>
              <p style="font-size:11px;color:rgb(var(--slate-8));margin:0 0 6px;line-height:1.5">
                Usado quando o cliente não responde há mais de 24h no WhatsApp Oficial. Sem template, o envio é pulado nesses casos.
              </p>
              <template v-if="!hasWhatsappInboxes">
                <p style="font-size:11px;color:rgb(var(--slate-8));font-style:italic;margin:0">
                  Nenhuma caixa WhatsApp Oficial encontrada.
                </p>
              </template>
              <template v-else>
                <select
                  class="mo-inp"
                  :value="winbackTemplate.name ? `${winbackTemplate.name}|${winbackTemplate.language}` : ''"
                  @change="onTemplateSelect($event, winbackTemplate)"
                >
                  <option value="">— não usar template —</option>
                  <option v-for="t in approvedTemplates" :key="`${t.name}|${t.language}`" :value="`${t.name}|${t.language}`">
                    {{ t.name }} · {{ t.language }}
                  </option>
                </select>
              </template>
            </div>

            <template v-if="getSelectedTemplate(winbackTemplate) && getBodyComponent(winbackTemplate)">
              <div class="mo-preview-box">
                <p class="mo-preview-label">Texto do template</p>
                <p class="mo-preview-text">{{ getBodyComponent(winbackTemplate).text }}</p>
              </div>
              <div v-if="getSlotCount(winbackTemplate) > 0" class="mo-field">
                <label class="mo-lbl">Mapear slots → variáveis</label>
                <div style="display:flex;flex-direction:column;gap:8px">
                  <div v-for="idx in getSlotCount(winbackTemplate)" :key="idx" style="display:flex;align-items:center;gap:8px">
                    <span style="font-size:11px;font-weight:700;font-family:monospace;color:rgb(var(--slate-10));width:36px;flex-shrink:0">{{ slotLabel(idx) }}</span>
                    <select class="mo-inp" style="flex:1" :value="winbackTemplate.body_params[idx-1] || ''" @change="setBodyParam(winbackTemplate, idx-1, $event.target.value)">
                      <option value="">— escolher variável —</option>
                      <option v-for="v in WINBACK_VARS" :key="v.value" :value="v.value">
                        {{ v.label }} (ex: {{ VAR_EXAMPLES_WINBACK[v.value] }})
                      </option>
                    </select>
                  </div>
                </div>
              </div>
            </template>
          </div>

        </template>

        <!-- ══ SEÇÃO ANIVERSÁRIO ══════════════════════════════════════════════ -->
        <div class="mo-section-head" style="margin-top:8px">
          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
          <span>Aniversário</span>
        </div>

        <div style="border-radius:8px;background:rgb(var(--surface-2));border:1px solid rgb(var(--border-weak));padding:10px 14px;font-size:11px;color:rgb(var(--slate-8));line-height:1.6">
          A data de aniversário é configurada no contato, no campo <strong>Aniversário</strong> da aba de atributos.
          O campo é criado automaticamente pela plataforma.
        </div>

        <!-- Toggle birthday -->
        <div class="mo-toggle-row">
          <div>
            <p class="mo-toggle-title">Ativar felicitação de aniversário</p>
            <p class="mo-toggle-sub">Envia mensagem automaticamente no dia do aniversário do cliente</p>
          </div>
          <button
            :style="{
              width:'40px', height:'22px', borderRadius:'11px', border:'none', cursor:'pointer',
              background: birthdayEnabled ? 'rgb(var(--n-brand,66 65 255))' : 'rgb(var(--slate-6,148 163 184))',
              position:'relative', transition:'background .2s', flexShrink:'0'
            }"
            @click="birthdayEnabled = !birthdayEnabled"
          >
            <span :style="{
              position:'absolute', top:'3px',
              left: birthdayEnabled ? '21px' : '3px',
              width:'16px', height:'16px', borderRadius:'50%',
              background:'#fff', transition:'left .2s', display:'block'
            }" />
          </button>
        </div>

        <template v-if="birthdayEnabled">

          <!-- Mensagem aniversário -->
          <div class="mo-field">
            <label class="mo-lbl">Mensagem de aniversário (texto livre)</label>
            <p style="font-size:11px;color:rgb(var(--slate-8));margin:0 0 6px;line-height:1.5">
              Clique numa variável para inserir no cursor:
            </p>
            <div class="var-chips">
              <button
                v-for="v in BIRTHDAY_VARS" :key="v.value"
                class="var-chip" type="button" :title="v.label"
                @click="insertBirthdayVar(v.value)"
              >{{ varToken(v.value) }}</button>
            </div>
            <textarea
              ref="birthdayTextarea"
              v-model="birthdayMessage"
              class="mo-inp" rows="3"
              :placeholder="DEFAULT_BIRTHDAY"
            />
          </div>

          <!-- Preview birthday -->
          <div class="mo-preview-box">
            <p class="mo-preview-label">Prévia</p>
            <p class="mo-preview-text">{{ birthdayPreview }}</p>
          </div>

          <!-- Template WhatsApp Oficial birthday -->
          <div style="border-top:1px solid rgb(var(--border-weak));padding-top:14px;display:flex;flex-direction:column;gap:12px">
            <div class="mo-field">
              <label class="mo-lbl">Template WhatsApp Oficial (opcional)</label>
              <template v-if="!hasWhatsappInboxes">
                <p style="font-size:11px;color:rgb(var(--slate-8));font-style:italic;margin:0">
                  Nenhuma caixa WhatsApp Oficial encontrada.
                </p>
              </template>
              <template v-else>
                <select
                  class="mo-inp"
                  :value="birthdayTemplate.name ? `${birthdayTemplate.name}|${birthdayTemplate.language}` : ''"
                  @change="onTemplateSelect($event, birthdayTemplate)"
                >
                  <option value="">— não usar template —</option>
                  <option v-for="t in approvedTemplates" :key="`${t.name}|${t.language}`" :value="`${t.name}|${t.language}`">
                    {{ t.name }} · {{ t.language }}
                  </option>
                </select>
              </template>
            </div>

            <template v-if="getSelectedTemplate(birthdayTemplate) && getBodyComponent(birthdayTemplate)">
              <div class="mo-preview-box">
                <p class="mo-preview-label">Texto do template</p>
                <p class="mo-preview-text">{{ getBodyComponent(birthdayTemplate).text }}</p>
              </div>
              <div v-if="getSlotCount(birthdayTemplate) > 0" class="mo-field">
                <label class="mo-lbl">Mapear slots → variáveis</label>
                <div style="display:flex;flex-direction:column;gap:8px">
                  <div v-for="idx in getSlotCount(birthdayTemplate)" :key="idx" style="display:flex;align-items:center;gap:8px">
                    <span style="font-size:11px;font-weight:700;font-family:monospace;color:rgb(var(--slate-10));width:36px;flex-shrink:0">{{ slotLabel(idx) }}</span>
                    <select class="mo-inp" style="flex:1" :value="birthdayTemplate.body_params[idx-1] || ''" @change="setBodyParam(birthdayTemplate, idx-1, $event.target.value)">
                      <option value="">— escolher variável —</option>
                      <option v-for="v in BIRTHDAY_VARS" :key="v.value" :value="v.value">
                        {{ v.label }} (ex: {{ VAR_EXAMPLES_BIRTHDAY[v.value] }})
                      </option>
                    </select>
                  </div>
                </div>
              </div>
            </template>
          </div>

        </template>

        <!-- ══ SEÇÃO COMPARTILHADA: INBOX PARA REATIVAÇÃO ════════════════════ -->
        <div style="border-top:1px solid rgb(var(--border-weak));padding-top:16px">
          <div class="mo-field">
            <label class="mo-lbl">Inbox para novos contatos (reativação)</label>
            <p style="font-size:11px;color:rgb(var(--slate-8));margin:0 0 6px;line-height:1.5">
              Inbox usado para criar conversa quando o cliente não tem nenhuma. Sem isso, apenas clientes com conversa ativa são alcançados.
            </p>
            <select v-model="retentionInboxId" class="mo-inp">
              <option value="">— nenhum (só quem já conversou) —</option>
              <option v-for="i in allInboxOptions" :key="i.id" :value="String(i.id)">
                {{ i.name }} ({{ i.channel_type.replace('Channel::', '') }})
              </option>
            </select>
          </div>
        </div>

      </div>

      <!-- Footer -->
      <div class="mo-foot">
        <button class="mo-btn-cancel" @click="$emit('close')">Cancelar</button>
        <button class="mo-btn-save" :disabled="saving" @click="save">
          <span v-if="saving">Salvando…</span>
          <span v-else>Salvar</span>
        </button>
      </div>

    </div>
  </div>
</template>

<style scoped>
/* ── Modal shell (same as ReminderSettings) ───────────────────────────────── */
.mo-overlay {
  position: fixed; inset: 0; z-index: 9999;
  display: flex; align-items: center; justify-content: center;
  padding: 16px;
  background: rgba(0, 0, 0, 0.65);
  backdrop-filter: blur(8px);
}
.mo-box {
  position: relative; width: 100%; max-width: 560px; max-height: 90vh;
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

/* Section headings */
.mo-section-head {
  display: flex; align-items: center; gap: 6px;
  font-size: 12px; font-weight: 700; color: rgb(var(--slate-12));
  padding-bottom: 4px;
  border-bottom: 1px solid rgb(var(--border-weak));
}

/* Toggle row */
.mo-toggle-row {
  display: flex; align-items: center; justify-content: space-between;
  padding: 10px 14px; border-radius: 10px;
  background: rgb(var(--surface-2,245 247 251));
  border: 1px solid rgb(var(--border-weak));
}
.mo-toggle-title { font-size: 13px; font-weight: 700; color: rgb(var(--slate-12)); margin: 0; }
.mo-toggle-sub   { font-size: 11px; color: rgb(var(--slate-8)); margin: 2px 0 0; }

/* Preview box */
.mo-preview-box {
  border-radius: 8px; background: rgb(var(--surface-2));
  border: 1px solid rgb(var(--border-weak)); padding: 10px 14px;
}
.mo-preview-label {
  font-size: 10px; font-weight: 700; text-transform: uppercase;
  letter-spacing: .08em; color: rgb(var(--slate-8)); margin: 0 0 5px;
}
.mo-preview-text {
  font-size: 12px; color: rgb(var(--slate-12)); margin: 0;
  line-height: 1.6; white-space: pre-wrap;
}

/* Variable chips */
.var-chips { display: flex; flex-wrap: wrap; gap: 5px; margin-bottom: 6px; }
.var-chip {
  padding: 3px 8px; border-radius: 6px; font-size: 10px; font-weight: 600; font-family: monospace;
  background: rgb(var(--surface-2)); color: rgb(var(--slate-11));
  border: 1px solid rgb(var(--border-strong)); cursor: pointer; transition: background .12s;
}
.var-chip:hover { background: rgb(var(--surface-3, 230 232 240)); }
</style>
