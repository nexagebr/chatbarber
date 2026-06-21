<script setup>
import { ref, computed } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import conversationApi from 'dashboard/api/conversations';

const props = defineProps({
  conversationId: { type: [Number, String], required: true },
});

const store = useStore();
const currentChat = useMapGetter('getSelectedChat');
const conversationMetadataGetter = useMapGetter(
  'conversationMetadata/getConversationMetadata'
);

const currentConversationMetaData = computed(() =>
  conversationMetadataGetter.value(props.conversationId)
);

const contactGetter = useMapGetter('contacts/getContact');
const contactId = computed(() => currentChat.value?.meta?.sender?.id);
const contact = computed(() => contactGetter.value(contactId.value));

const leadSource = computed(() => {
  const convLS = currentConversationMetaData.value?.additional_attributes?.lead_source;
  const contactLS = contact.value?.additional_attributes?.lead_source;
  return convLS || contactLS || null;
});

const hasData = computed(() => !!leadSource.value);

// ── channel meta ──────────────────────────────────────────────────────────────
const CHANNEL_META = {
  website: {
    label: 'Website',
    icon: 'i-lucide-globe',
    color: 'bg-blue-500/10 text-blue-500 ring-1 ring-blue-500/20',
  },
  whatsapp_ad: {
    label: 'WhatsApp Ads',
    icon: 'i-lucide-megaphone',
    color: 'bg-emerald-500/10 text-emerald-500 ring-1 ring-emerald-500/20',
  },
  manual: {
    label: 'Manual',
    icon: 'i-lucide-pencil',
    color: 'bg-n-alpha-black2 text-n-slate-9 ring-1 ring-n-weak',
  },
};
const channelMeta = computed(
  () => CHANNEL_META[leadSource.value?.channel] || CHANNEL_META.manual
);

// Format values
function capitalize(str) {
  if (!str) return str;
  return str.charAt(0).toUpperCase() + str.slice(1);
}
function formatMedium(val) {
  if (!val) return val;
  const map = { cpc: 'CPC', cpm: 'CPM', cpa: 'CPA', seo: 'SEO', ppc: 'PPC' };
  return map[val.toLowerCase()] || capitalize(val);
}

function truncateMiddle(str, maxLen = 28) {
  if (!str || str.length <= maxLen) return str;
  const half = Math.floor((maxLen - 3) / 2);
  return str.slice(0, half) + '...' + str.slice(-half);
}

function formatHostPath(url) {
  try {
    const u = new URL(url);
    return u.hostname + (u.pathname !== '/' ? u.pathname : '');
  } catch {
    return url;
  }
}

// Copy to clipboard
const copiedField = ref(null);
async function copyToClipboard(text, field) {
  try {
    await navigator.clipboard.writeText(text);
    copiedField.value = field;
    setTimeout(() => { copiedField.value = null; }, 1500);
  } catch { /* silent */ }
}

// ── inline edit form ──────────────────────────────────────────────────────────
const editing = ref(false);
const saving = ref(false);

const CHANNEL_OPTIONS = [
  { value: 'website', label: 'Website', icon: 'i-lucide-globe' },
  { value: 'whatsapp_ad', label: 'WhatsApp Ads', icon: 'i-lucide-megaphone' },
  { value: 'manual', label: 'Outro / Manual', icon: 'i-lucide-pencil' },
];

const SOURCE_SUGGESTIONS = [
  'google', 'facebook', 'instagram', 'whatsapp', 'email', 'indicacao', 'organico',
];

const editForm = ref({
  channel: 'manual',
  source: '',
  medium: '',
  campaign: '',
  referer_url: '',
});

function startEdit() {
  const ls = leadSource.value || {};
  editForm.value = {
    channel: ls.channel || 'manual',
    source: ls.source || '',
    medium: ls.medium || '',
    campaign: ls.campaign || '',
    referer_url: ls.referer_url || '',
  };
  editing.value = true;
}

function cancelEdit() {
  editing.value = false;
}

async function saveEdit() {
  saving.value = true;
  try {
    const payload = {
      channel: editForm.value.channel,
      source: editForm.value.source.trim() || undefined,
      medium: editForm.value.medium.trim() || undefined,
      campaign: editForm.value.campaign.trim() || undefined,
      referer_url: editForm.value.referer_url.trim() || undefined,
    };
    const { data } = await conversationApi.updateLeadSource(props.conversationId, payload);

    // Commit directly — conversationMetadata has no get action, only mutation
    const currentMeta = currentConversationMetaData.value || {};
    store.commit('conversationMetadata/SET_CONVERSATION_METADATA', {
      id: Number(props.conversationId),
      data: {
        ...currentMeta,
        additional_attributes: {
          ...(currentMeta.additional_attributes || {}),
          lead_source: data.lead_source,
        },
      },
    });

    editing.value = false;
    useAlert('Origem do lead atualizada.');
  } catch {
    useAlert('Erro ao salvar origem.');
  } finally {
    saving.value = false;
  }
}
</script>

<template>
  <div class="px-4 pb-4 pt-1">

    <!-- ── Empty state ───────────────────────────────────────────────────────── -->
    <div v-if="!hasData && !editing" class="flex flex-col items-center gap-3 py-3">
      <div class="flex flex-col items-center gap-1 text-n-slate-7">
        <span class="i-lucide-map-pin-off text-base" />
        <span class="text-xs text-center">Origem não identificada</span>
      </div>
      <button
        class="inline-flex items-center gap-1.5 h-7 px-3 rounded-lg border border-n-weak text-xs font-medium text-n-slate-10 hover:bg-n-alpha-2 hover:border-n-brand/40 hover:text-n-slate-12 transition-colors"
        @click="startEdit"
      >
        <span class="i-lucide-plus text-xs" />
        Preencher manualmente
      </button>
    </div>

    <!-- ── Data view ─────────────────────────────────────────────────────────── -->
    <div v-else-if="hasData && !editing" class="flex flex-col gap-0">

      <!-- Header: channel badge -->
      <div class="flex items-center mb-3">
        <span
          class="inline-flex items-center gap-1.5 h-5 px-2 rounded-full text-[10px] font-semibold tracking-wide"
          :class="channelMeta.color"
        >
          <span :class="channelMeta.icon" class="text-[10px]" />
          {{ channelMeta.label }}
        </span>
      </div>

      <!-- Field rows: label left, value right -->
      <div class="flex flex-col divide-y divide-n-weak/50">

        <div v-if="leadSource.source" class="flex items-center justify-between py-1.5 gap-2">
          <span class="text-[11px] text-n-slate-7 shrink-0">Origem</span>
          <span class="text-[11px] font-medium text-n-slate-12 text-right">{{ capitalize(leadSource.source) }}</span>
        </div>

        <div v-if="leadSource.medium" class="flex items-center justify-between py-1.5 gap-2">
          <span class="text-[11px] text-n-slate-7 shrink-0">Meio</span>
          <span class="text-[11px] font-medium text-n-slate-12 text-right">{{ formatMedium(leadSource.medium) }}</span>
        </div>

        <div v-if="leadSource.campaign" class="flex items-center justify-between py-1.5 gap-2">
          <span class="text-[11px] text-n-slate-7 shrink-0">Campanha</span>
          <span class="text-[11px] font-medium text-n-slate-12 text-right truncate max-w-[60%]" :title="leadSource.campaign">
            {{ leadSource.campaign }}
          </span>
        </div>

        <!-- gclid / fbclid as copyable monospace chips -->
        <div v-if="leadSource.gclid" class="flex items-center justify-between py-1.5 gap-2">
          <span class="text-[11px] text-n-slate-7 shrink-0">Google Click ID</span>
          <button
            class="inline-flex items-center gap-1 px-1.5 py-0.5 rounded bg-n-alpha-black2 hover:bg-n-alpha-3 transition-colors group"
            :title="leadSource.gclid"
            @click="copyToClipboard(leadSource.gclid, 'gclid')"
          >
            <span class="text-[10px] font-mono text-n-slate-9">{{ truncateMiddle(leadSource.gclid, 18) }}</span>
            <span
              class="text-[9px] transition-colors"
              :class="copiedField === 'gclid' ? 'i-lucide-check text-emerald-500' : 'i-lucide-copy text-n-slate-6 group-hover:text-n-slate-9'"
            />
          </button>
        </div>

        <div v-if="leadSource.fbclid" class="flex items-center justify-between py-1.5 gap-2">
          <span class="text-[11px] text-n-slate-7 shrink-0">Facebook Click ID</span>
          <button
            class="inline-flex items-center gap-1 px-1.5 py-0.5 rounded bg-n-alpha-black2 hover:bg-n-alpha-3 transition-colors group"
            :title="leadSource.fbclid"
            @click="copyToClipboard(leadSource.fbclid, 'fbclid')"
          >
            <span class="text-[10px] font-mono text-n-slate-9">{{ truncateMiddle(leadSource.fbclid, 18) }}</span>
            <span
              class="text-[9px] transition-colors"
              :class="copiedField === 'fbclid' ? 'i-lucide-check text-emerald-500' : 'i-lucide-copy text-n-slate-6 group-hover:text-n-slate-9'"
            />
          </button>
        </div>

        <!-- WhatsApp Ad fields -->
        <template v-if="leadSource.ad && leadSource.channel === 'whatsapp_ad'">
          <div v-if="leadSource.ad.headline" class="flex items-center justify-between py-1.5 gap-2">
            <span class="text-[11px] text-n-slate-7 shrink-0">Anúncio</span>
            <span class="text-[11px] font-medium text-n-slate-12 text-right truncate max-w-[60%]">{{ leadSource.ad.headline }}</span>
          </div>
          <div v-if="leadSource.ad.ctwa_clid" class="flex items-center justify-between py-1.5 gap-2">
            <span class="text-[11px] text-n-slate-7 shrink-0">ctwa_clid</span>
            <button
              class="inline-flex items-center gap-1 px-1.5 py-0.5 rounded bg-n-alpha-black2 hover:bg-n-alpha-3 transition-colors group"
              @click="copyToClipboard(leadSource.ad.ctwa_clid, 'ctwa')"
            >
              <span class="text-[10px] font-mono text-n-slate-9">{{ truncateMiddle(leadSource.ad.ctwa_clid, 18) }}</span>
              <span class="text-[9px] transition-colors" :class="copiedField === 'ctwa' ? 'i-lucide-check text-emerald-500' : 'i-lucide-copy text-n-slate-6 group-hover:text-n-slate-9'" />
            </button>
          </div>
        </template>

        <!-- URL -->
        <div v-if="leadSource.referer_url" class="flex items-center justify-between py-1.5 gap-2">
          <span class="text-[11px] text-n-slate-7 shrink-0">Página</span>
          <a
            :href="leadSource.referer_url"
            target="_blank"
            rel="noopener noreferrer"
            class="text-[11px] text-n-brand hover:underline truncate max-w-[60%]"
            :title="leadSource.referer_url"
          >{{ formatHostPath(leadSource.referer_url) }}</a>
        </div>

      </div>

      <!-- Edit button -->
      <button
        class="mt-3 w-full inline-flex items-center justify-center gap-1.5 h-7 rounded-lg border border-n-weak text-xs font-medium text-n-slate-9 hover:bg-n-alpha-2 hover:text-n-slate-11 transition-colors"
        @click="startEdit"
      >
        <span class="i-lucide-pencil text-xs" />
        Editar origem
      </button>
    </div>

    <!-- ── Edit form ──────────────────────────────────────────────────────────── -->
    <div v-if="editing" class="flex flex-col gap-2.5">

      <!-- Canal -->
      <div class="flex flex-col gap-1">
        <span class="text-[10px] font-semibold text-n-slate-6 uppercase tracking-widest">Canal</span>
        <div class="grid grid-cols-3 gap-1">
          <button
            v-for="opt in CHANNEL_OPTIONS"
            :key="opt.value"
            type="button"
            class="inline-flex flex-col items-center justify-center gap-1 py-2 px-1 rounded-lg text-[10px] font-medium border transition-all"
            :class="editForm.channel === opt.value
              ? 'bg-n-brand/10 text-n-brand border-n-brand/40'
              : 'bg-transparent text-n-slate-8 border-n-weak hover:border-n-brand/30 hover:text-n-slate-11'"
            @click="editForm.channel = opt.value"
          >
            <span :class="opt.icon" class="text-sm" />
            {{ opt.label }}
          </button>
        </div>
      </div>

      <!-- Origem + Meio side by side -->
      <div class="grid grid-cols-2 gap-2">
        <div class="flex flex-col gap-1">
          <label class="text-[10px] font-semibold text-n-slate-6 uppercase tracking-widest">Origem</label>
          <input
            v-model="editForm.source"
            type="text"
            placeholder="google…"
            list="ls-source-suggestions"
            class="h-7 px-2.5 rounded-lg border border-n-weak bg-n-solid-2 text-xs text-n-slate-12 placeholder:text-n-slate-6 focus:outline-none focus:ring-2 focus:ring-n-brand/30 focus:border-n-brand/50"
          />
          <datalist id="ls-source-suggestions">
            <option v-for="s in SOURCE_SUGGESTIONS" :key="s" :value="s" />
          </datalist>
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-[10px] font-semibold text-n-slate-6 uppercase tracking-widest">Meio</label>
          <input
            v-model="editForm.medium"
            type="text"
            placeholder="cpc, organic…"
            class="h-7 px-2.5 rounded-lg border border-n-weak bg-n-solid-2 text-xs text-n-slate-12 placeholder:text-n-slate-6 focus:outline-none focus:ring-2 focus:ring-n-brand/30 focus:border-n-brand/50"
          />
        </div>
      </div>

      <!-- Campanha -->
      <div class="flex flex-col gap-1">
        <label class="text-[10px] font-semibold text-n-slate-6 uppercase tracking-widest">Campanha</label>
        <input
          v-model="editForm.campaign"
          type="text"
          placeholder="nome-da-campanha"
          class="h-7 px-2.5 rounded-lg border border-n-weak bg-n-solid-2 text-xs text-n-slate-12 placeholder:text-n-slate-6 focus:outline-none focus:ring-2 focus:ring-n-brand/30 focus:border-n-brand/50"
        />
      </div>

      <!-- URL -->
      <div class="flex flex-col gap-1">
        <label class="text-[10px] font-semibold text-n-slate-6 uppercase tracking-widest">URL de origem</label>
        <input
          v-model="editForm.referer_url"
          type="url"
          placeholder="https://…"
          class="h-7 px-2.5 rounded-lg border border-n-weak bg-n-solid-2 text-xs text-n-slate-12 placeholder:text-n-slate-6 focus:outline-none focus:ring-2 focus:ring-n-brand/30 focus:border-n-brand/50"
        />
      </div>

      <!-- Actions -->
      <div class="flex gap-2 pt-1">
        <button
          class="h-7 px-3 rounded-lg border border-n-weak text-xs font-medium text-n-slate-9 hover:bg-n-alpha-2 transition-colors disabled:opacity-40"
          :disabled="saving"
          @click="cancelEdit"
        >Cancelar</button>
        <button
          class="flex-1 h-7 rounded-lg bg-n-brand text-white text-xs font-semibold hover:brightness-110 disabled:opacity-50 flex items-center justify-center gap-1.5 transition-all"
          :disabled="saving"
          @click="saveEdit"
        >
          <span v-if="saving" class="i-lucide-loader-2 animate-spin text-xs" />
          Salvar
        </button>
      </div>
    </div>

  </div>
</template>
