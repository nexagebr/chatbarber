<script setup>
import { reactive, computed, watch, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength, requiredIf } from '@vuelidate/validators';
import { useMapGetter } from 'dashboard/composables/store';

import Input from 'dashboard/components-next/input/Input.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';
import WhatsAppTemplateParser from 'dashboard/components-next/whatsapp/WhatsAppTemplateParser.vue';

const emit = defineEmits(['submit', 'cancel']);

const { t } = useI18n();

const formState = {
  uiFlags: useMapGetter('campaigns/getUIFlags'),
  labels: useMapGetter('labels/getLabels'),
  inboxes: useMapGetter('inboxes/getWhatsAppInboxes'),
  getFilteredWhatsAppTemplates: useMapGetter(
    'inboxes/getFilteredWhatsAppTemplates'
  ),
};

const initialState = {
  title: '',
  inboxId: null,
  templateId: null,
  scheduledAt: null,
  selectedAudience: [],
};

const state = reactive({ ...initialState });
const templateParserRef = ref(null);

// audience mode: 'label' or 'csv'
const audienceMode = ref('label');
const csvContacts = ref([]);
const csvError = ref('');
const csvFileRef = ref(null);

const isLabelMode = computed(() => audienceMode.value === 'label');

const rules = {
  title: { required, minLength: minLength(1) },
  inboxId: { required },
  templateId: { required },
  scheduledAt: { required },
  selectedAudience: {
    requiredIfLabel: requiredIf(() => isLabelMode.value),
  },
};

const v$ = useVuelidate(rules, state);

const isCreating = computed(() => formState.uiFlags.value.isCreating);

const currentDateTime = computed(() => {
  const now = new Date();
  const localTime = new Date(now.getTime() - now.getTimezoneOffset() * 60000);
  return localTime.toISOString().slice(0, 16);
});

const mapToOptions = (items, valueKey, labelKey) =>
  items?.map(item => ({
    value: item[valueKey],
    label: item[labelKey],
  })) ?? [];

const audienceList = computed(() =>
  mapToOptions(formState.labels.value, 'id', 'title')
);

const inboxOptions = computed(() =>
  mapToOptions(formState.inboxes.value, 'id', 'name')
);

const templateOptions = computed(() => {
  if (!state.inboxId) return [];
  const templates = formState.getFilteredWhatsAppTemplates.value(state.inboxId);
  return templates.map(template => {
    const friendlyName = template.name
      .replace(/_/g, ' ')
      .replace(/\b\w/g, l => l.toUpperCase());
    return {
      value: template.id,
      label: `${friendlyName} (${template.language || 'en'})`,
      template: template,
    };
  });
});

const selectedTemplate = computed(() => {
  if (!state.templateId) return null;
  return templateOptions.value.find(option => option.value === state.templateId)
    ?.template;
});

const getErrorMessage = (field, errorKey) => {
  const baseKey = 'CAMPAIGN.WHATSAPP.CREATE.FORM';
  return v$.value[field].$error ? t(`${baseKey}.${errorKey}.ERROR`) : '';
};

const formErrors = computed(() => ({
  title: getErrorMessage('title', 'TITLE'),
  inbox: getErrorMessage('inboxId', 'INBOX'),
  template: getErrorMessage('templateId', 'TEMPLATE'),
  scheduledAt: getErrorMessage('scheduledAt', 'SCHEDULED_AT'),
  audience: isLabelMode.value ? getErrorMessage('selectedAudience', 'AUDIENCE') : '',
}));

const csvAudienceValid = computed(() =>
  isLabelMode.value ? true : csvContacts.value.length > 0
);

const hasRequiredTemplateParams = computed(() => {
  return templateParserRef.value?.v$?.$invalid === false || true;
});

const isSubmitDisabled = computed(
  () => v$.value.$invalid || !hasRequiredTemplateParams.value || !csvAudienceValid.value
);

const formatToUTCString = localDateTime =>
  localDateTime ? new Date(localDateTime).toISOString() : null;

const resetState = () => {
  Object.assign(state, initialState);
  v$.value.$reset();
  csvContacts.value = [];
  csvError.value = '';
  audienceMode.value = 'label';
};

const handleCancel = () => emit('cancel');

// ── CSV helpers ──────────────────────────────────────────────────────────────

const downloadExample = () => {
  const content = 'telefone,nome\n+5511999998888,João Silva\n+5511988887777,Maria Santos\n+5521977776666,Ana Lima\n';
  const blob = new Blob([content], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = 'modelo_campanha.csv';
  link.click();
  URL.revokeObjectURL(url);
};

const detectDelimiter = firstLine => {
  const sc = (firstLine.match(/;/g) || []).length;
  const cm = (firstLine.match(/,/g) || []).length;
  return sc > cm ? ';' : ',';
};

const parseCsv = text => {
  // strip BOM if present
  const clean = text.replace(/^﻿/, '').trim();
  const lines = clean.split(/\r?\n/);
  if (lines.length < 2) return null;
  const sep = detectDelimiter(lines[0]);
  const headers = lines[0].split(sep).map(h => h.trim().toLowerCase().replace(/['"]/g, ''));
  const phoneIdx = headers.findIndex(h =>
    ['telefone', 'phone', 'fone', 'celular', 'whatsapp', 'número', 'numero'].includes(h)
  );
  const nameIdx = headers.findIndex(h =>
    ['nome', 'name', 'cliente', 'contato'].includes(h)
  );
  if (phoneIdx === -1) return null;
  return lines
    .slice(1)
    .filter(l => l.trim())
    .map(line => {
      const cols = line.split(sep).map(c => c.trim().replace(/^["']|["']$/g, ''));
      const columns = {};
      headers.forEach((h, i) => { columns[h] = cols[i] || ''; });
      return {
        phone: cols[phoneIdx] || '',
        name: nameIdx >= 0 ? cols[nameIdx] || '' : '',
        columns,
      };
    })
    .filter(c => c.phone.replace(/\D/g, '').length >= 8);
};

// non-phone column names from the CSV — used as variable chips in the template parser
const csvColumnNames = computed(() => {
  if (!csvContacts.value.length) return [];
  const phoneKeys = new Set(['telefone', 'phone', 'fone', 'celular', 'whatsapp', 'número', 'numero']);
  return Object.keys(csvContacts.value[0].columns || {}).filter(k => !phoneKeys.has(k));
});

const onCsvUpload = async event => {
  const file = event.target.files[0];
  if (!file) return;
  csvError.value = '';
  csvContacts.value = [];
  try {
    const text = await file.text();
    const parsed = parseCsv(text);
    if (!parsed) {
      csvError.value = 'Arquivo inválido. Certifique-se que há uma coluna "telefone".';
      return;
    }
    if (parsed.length === 0) {
      csvError.value = 'Nenhum número válido encontrado no arquivo.';
      return;
    }
    csvContacts.value = parsed;
  } catch {
    csvError.value = 'Erro ao ler o arquivo. Tente novamente.';
  }
};

const clearCsv = () => {
  csvContacts.value = [];
  csvError.value = '';
  if (csvFileRef.value) csvFileRef.value.value = '';
};

// ── form submission ──────────────────────────────────────────────────────────

const prepareCampaignDetails = () => {
  const currentTemplate = selectedTemplate.value;
  const parserData = templateParserRef.value;
  const templateContent = parserData?.renderedTemplate || '';
  const templateParams = {
    name: currentTemplate?.name || '',
    namespace: currentTemplate?.namespace || '',
    category: currentTemplate?.category || 'UTILITY',
    language: currentTemplate?.language || 'en_US',
    processed_params: parserData?.processedParams || {},
  };

  const audience = isLabelMode.value
    ? state.selectedAudience?.map(id => ({ id, type: 'Label' }))
    : csvContacts.value.map(c => ({ type: 'CsvContact', phone: c.phone, name: c.name, columns: c.columns || {} }));

  return {
    title: state.title,
    message: templateContent,
    template_params: templateParams,
    inbox_id: state.inboxId,
    scheduled_at: formatToUTCString(state.scheduledAt),
    audience,
  };
};

const handleSubmit = async () => {
  const isFormValid = await v$.value.$validate();
  if (!isFormValid) return;
  if (!csvAudienceValid.value) return;

  emit('submit', prepareCampaignDetails());
  resetState();
  handleCancel();
};

watch(
  () => state.inboxId,
  () => { state.templateId = null; }
);
</script>

<template>
  <form class="flex flex-col gap-4" @submit.prevent="handleSubmit">
    <Input
      v-model="state.title"
      :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.TITLE.LABEL')"
      :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.TITLE.PLACEHOLDER')"
      :message="formErrors.title"
      :message-type="formErrors.title ? 'error' : 'info'"
    />

    <div class="flex flex-col gap-1">
      <label for="inbox" class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.INBOX.LABEL') }}
      </label>
      <ComboBox
        id="inbox"
        v-model="state.inboxId"
        :options="inboxOptions"
        :has-error="!!formErrors.inbox"
        :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.INBOX.PLACEHOLDER')"
        :message="formErrors.inbox"
        class="[&>div>button]:bg-n-alpha-black2 [&>div>button:not(.focused)]:dark:outline-n-weak [&>div>button:not(.focused)]:hover:!outline-n-slate-6"
      />
    </div>

    <div class="flex flex-col gap-1">
      <label for="template" class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.LABEL') }}
      </label>
      <ComboBox
        id="template"
        v-model="state.templateId"
        :options="templateOptions"
        :has-error="!!formErrors.template"
        :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.PLACEHOLDER')"
        :message="formErrors.template"
        class="[&>div>button]:bg-n-alpha-black2 [&>div>button:not(.focused)]:dark:outline-n-weak [&>div>button:not(.focused)]:hover:!outline-n-slate-6"
      />
      <p class="mt-1 text-xs text-n-slate-11">
        {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.TEMPLATE.INFO') }}
      </p>
    </div>

    <!-- Template Parser -->
    <WhatsAppTemplateParser
      v-if="selectedTemplate"
      ref="templateParserRef"
      :template="selectedTemplate"
      :campaign-mode="true"
      :csv-columns="csvColumnNames"
      :show-contact-tokens="isLabelMode"
    />

    <!-- ── Audiência ─────────────────────────────────────────────────────── -->
    <div class="flex flex-col gap-2">
      <label class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.LABEL') }}
      </label>

      <!-- Mode toggle -->
      <div class="flex gap-1 p-1 rounded-lg bg-n-alpha-2 w-fit">
        <button
          type="button"
          :class="[
            'px-3 py-1.5 rounded-md text-xs font-semibold transition-all',
            isLabelMode
              ? 'bg-white dark:bg-n-solid-3 text-n-slate-12 shadow-sm'
              : 'text-n-slate-9 hover:text-n-slate-11'
          ]"
          @click="audienceMode = 'label'"
        >
          Por Tag
        </button>
        <button
          type="button"
          :class="[
            'px-3 py-1.5 rounded-md text-xs font-semibold transition-all',
            !isLabelMode
              ? 'bg-white dark:bg-n-solid-3 text-n-slate-12 shadow-sm'
              : 'text-n-slate-9 hover:text-n-slate-11'
          ]"
          @click="audienceMode = 'csv'"
        >
          Por Planilha (CSV)
        </button>
      </div>

      <!-- Tag audience -->
      <div v-if="isLabelMode">
        <TagMultiSelectComboBox
          v-model="state.selectedAudience"
          :options="audienceList"
          :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.LABEL')"
          :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.AUDIENCE.PLACEHOLDER')"
          :has-error="!!formErrors.audience"
          :message="formErrors.audience"
          class="[&>div>button]:bg-n-alpha-black2"
        />
      </div>

      <!-- CSV audience -->
      <div v-else class="flex flex-col gap-2">
        <!-- download example + upload -->
        <div class="flex items-center gap-2">
          <button
            type="button"
            class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg border border-n-weak bg-n-alpha-2 text-xs font-semibold text-n-slate-11 hover:text-n-slate-12 hover:border-n-strong transition-colors"
            @click="downloadExample"
          >
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
            Baixar modelo CSV
          </button>
          <label class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg border border-n-weak bg-n-alpha-2 text-xs font-semibold text-n-slate-11 hover:text-n-slate-12 hover:border-n-strong transition-colors cursor-pointer">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/></svg>
            Enviar planilha
            <input
              ref="csvFileRef"
              type="file"
              accept=".csv,.txt"
              class="hidden"
              @change="onCsvUpload"
            />
          </label>
        </div>

        <!-- error -->
        <p v-if="csvError" class="text-xs text-n-ruby-9">{{ csvError }}</p>

        <!-- preview -->
        <div v-if="csvContacts.length" class="rounded-lg border border-n-weak bg-n-alpha-2 overflow-hidden">
          <div class="flex items-center justify-between px-3 py-2 border-b border-n-weak">
            <span class="text-xs font-semibold text-n-slate-12">
              {{ csvContacts.length }} contato{{ csvContacts.length !== 1 ? 's' : '' }} carregado{{ csvContacts.length !== 1 ? 's' : '' }}
            </span>
            <button
              type="button"
              class="text-[10px] text-n-ruby-9 hover:text-n-ruby-11 font-semibold transition-colors"
              @click="clearCsv"
            >
              Remover
            </button>
          </div>
          <div class="max-h-36 overflow-y-auto">
            <div
              v-for="(c, i) in csvContacts.slice(0, 50)"
              :key="i"
              class="flex items-center gap-3 px-3 py-1.5 border-b border-n-weak last:border-0"
            >
              <span class="text-[10px] font-mono text-n-slate-9 w-4 flex-shrink-0">{{ i + 1 }}</span>
              <span class="text-xs font-semibold text-n-slate-12 flex-shrink-0">{{ c.phone }}</span>
              <span v-if="c.name" class="text-xs text-n-slate-9 truncate">{{ c.name }}</span>
            </div>
            <div v-if="csvContacts.length > 50" class="px-3 py-1.5 text-[10px] text-n-slate-8 text-center">
              + {{ csvContacts.length - 50 }} mais...
            </div>
          </div>
        </div>

        <!-- empty hint -->
        <p v-if="!csvContacts.length && !csvError" class="text-xs text-n-slate-8">
          Baixe o modelo, preencha com os números e faça o upload. Colunas obrigatórias: <strong>telefone</strong>. Opcional: <strong>nome</strong>.
        </p>
      </div>
    </div>

    <Input
      v-model="state.scheduledAt"
      :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.SCHEDULED_AT.LABEL')"
      type="datetime-local"
      :min="currentDateTime"
      :placeholder="t('CAMPAIGN.WHATSAPP.CREATE.FORM.SCHEDULED_AT.PLACEHOLDER')"
      :message="formErrors.scheduledAt"
      :message-type="formErrors.scheduledAt ? 'error' : 'info'"
    />

    <div class="flex gap-3 justify-between items-center w-full">
      <Button
        variant="faded"
        color="slate"
        type="button"
        :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.BUTTONS.CANCEL')"
        class="w-full bg-n-alpha-2 text-n-blue-11 hover:bg-n-alpha-3"
        @click="handleCancel"
      />
      <Button
        :label="t('CAMPAIGN.WHATSAPP.CREATE.FORM.BUTTONS.CREATE')"
        class="w-full"
        type="submit"
        :is-loading="isCreating"
        :disabled="isCreating || isSubmitDisabled"
      />
    </div>
  </form>
</template>
