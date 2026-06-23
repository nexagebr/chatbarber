<script setup>
/* eslint-disable vue/no-bare-strings-in-template */
import { ref, computed, watchEffect } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import InboxesAPI from 'dashboard/api/inboxes';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';

const emit = defineEmits(['close', 'created']);

const inboxes = useMapGetter('inboxes/getWhatsAppInboxes');
const whatsappCloudInboxes = computed(() =>
  (inboxes.value || []).filter(i => i.channel_type === 'Channel::Whatsapp')
);
const inboxOptions = computed(() =>
  whatsappCloudInboxes.value.map(i => ({ value: i.id, label: i.name }))
);

const state = ref({
  inboxId: null,
  name: '',
  category: 'MARKETING',
  language: 'pt_BR',
  bodyText: '',
  footer: '',
  buttons: [],
});

const exampleValues = ref([]);
const error = ref('');
const success = ref('');
const loading = ref(false);

const categoryOptions = [
  { value: 'MARKETING', label: 'Marketing' },
  { value: 'UTILITY', label: 'Utilidade' },
];

const languageOptions = [
  { value: 'pt_BR', label: 'Português (BR)' },
  { value: 'en_US', label: 'English (US)' },
  { value: 'es', label: 'Español' },
];

const buttonTypeOptions = [
  { value: 'QUICK_REPLY', label: 'Resposta Rápida' },
  { value: 'URL', label: 'Abrir URL' },
  { value: 'PHONE_NUMBER', label: 'Ligar' },
];

// Extrai variáveis únicas em ordem de aparição: {{nome}}, {{1}}, etc.
const namedVars = computed(() => {
  const matches = state.value.bodyText.match(/\{\{([^}]+)\}\}/g) || [];
  return matches.reduce((acc, m) => {
    const name = m.slice(2, -2).trim();
    return acc.includes(name) ? acc : [...acc, name];
  }, []);
});

watchEffect(() => {
  const vars = namedVars.value;
  while (exampleValues.value.length < vars.length) exampleValues.value.push('');
  exampleValues.value = exampleValues.value.slice(0, vars.length);
});

const insertVariable = () => {
  state.value.bodyText += `{{variavel${namedVars.value.length + 1}}}`;
};

const nameSlug = computed({
  get: () => state.value.name,
  set: val => {
    state.value.name = val
      .toLowerCase()
      .replace(/[^a-z0-9_]/g, '_')
      .replace(/__+/g, '_');
  },
});

const addButton = () => {
  if (state.value.buttons.length >= 3) return;
  state.value.buttons.push({
    type: 'QUICK_REPLY',
    text: '',
    url: '',
    phone: '',
  });
};

const removeButton = idx => {
  state.value.buttons.splice(idx, 1);
};

const bodyErrors = computed(() => {
  const text = state.value.bodyText;
  if (!text.trim()) return [];
  if (/^\s*\{\{/.test(text)) {
    return [
      'O texto não pode começar com uma variável — adicione texto antes do primeiro {{..}}.',
    ];
  }
  return [];
});

const isValid = computed(
  () =>
    state.value.inboxId &&
    state.value.name.trim() &&
    state.value.bodyText.trim() &&
    bodyErrors.value.length === 0
);

const buildComponents = () => {
  const components = [];

  const bodyComp = { type: 'BODY', text: state.value.bodyText };
  const vars = namedVars.value;
  if (vars.length > 0) {
    const examples = vars.map(
      (_, i) => exampleValues.value[i] || `exemplo${i + 1}`
    );
    bodyComp.example = { body_text: [examples] };
  }
  components.push(bodyComp);

  if (state.value.footer.trim()) {
    components.push({ type: 'FOOTER', text: state.value.footer.trim() });
  }

  if (state.value.buttons.length > 0) {
    const buttons = state.value.buttons.map(b => {
      if (b.type === 'QUICK_REPLY')
        return { type: 'QUICK_REPLY', text: b.text };
      if (b.type === 'URL') return { type: 'URL', text: b.text, url: b.url };
      return { type: 'PHONE_NUMBER', text: b.text, phone_number: b.phone };
    });
    components.push({ type: 'BUTTONS', buttons });
  }

  return components;
};

const handleSubmit = async () => {
  error.value = '';
  success.value = '';
  loading.value = true;
  try {
    await InboxesAPI.createWhatsAppTemplate(state.value.inboxId, {
      name: state.value.name,
      category: state.value.category,
      language: state.value.language,
      components: buildComponents(),
    });
    success.value = 'Template enviado para aprovação da Meta!';
    setTimeout(() => {
      emit('created');
      emit('close');
    }, 2000);
  } catch (e) {
    error.value = e?.response?.data?.error || 'Erro ao criar template.';
  } finally {
    loading.value = false;
  }
};

const varLabel = n => `{{${n}}}`;
</script>

<template>
  <div
    class="w-[28rem] z-50 absolute top-10 ltr:right-0 rtl:left-0 bg-n-alpha-3 backdrop-blur-[100px] rounded-xl border border-n-weak shadow-md max-h-[90vh] overflow-y-auto"
  >
    <div class="p-6 flex flex-col gap-4">
      <!-- Header -->
      <div class="flex items-center justify-between">
        <h3 class="text-base font-medium text-n-slate-12">
          Novo Template WhatsApp
        </h3>
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

      <!-- Inbox -->
      <div class="flex flex-col gap-1">
        <label class="text-sm font-medium text-n-slate-12"
          >Inbox WhatsApp</label
        >
        <ComboBox
          v-model="state.inboxId"
          :options="inboxOptions"
          placeholder="Selecione o inbox"
          class="[&>div>button]:bg-n-alpha-black2"
        />
      </div>

      <!-- Nome / slug -->
      <div class="flex flex-col gap-1">
        <label class="text-sm font-medium text-n-slate-12"
          >Nome do template (slug)</label
        >
        <input
          :value="nameSlug"
          type="text"
          placeholder="ex: boas_vindas_cliente"
          class="w-full rounded-lg border border-n-weak bg-n-alpha-2 px-3 py-2 text-sm text-n-slate-12 placeholder-n-slate-8 focus:outline-none focus:border-n-brand transition-colors"
          @input="e => (nameSlug = e.target.value)"
        />
        <p class="text-[11px] text-n-slate-8">
          Apenas letras minúsculas, números e _ (gerado automaticamente)
        </p>
      </div>

      <!-- Categoria + Idioma -->
      <div class="flex gap-3">
        <div class="flex flex-col gap-1 flex-1">
          <label class="text-sm font-medium text-n-slate-12">Categoria</label>
          <ComboBox
            v-model="state.category"
            :options="categoryOptions"
            class="[&>div>button]:bg-n-alpha-black2"
          />
        </div>
        <div class="flex flex-col gap-1 flex-1">
          <label class="text-sm font-medium text-n-slate-12">Idioma</label>
          <ComboBox
            v-model="state.language"
            :options="languageOptions"
            class="[&>div>button]:bg-n-alpha-black2"
          />
        </div>
      </div>

      <!-- Corpo -->
      <div class="flex flex-col gap-1">
        <div class="flex items-center justify-between">
          <label class="text-sm font-medium text-n-slate-12"
            >Corpo da mensagem</label
          >
          <button
            type="button"
            class="text-[11px] font-semibold text-n-brand hover:text-n-brand/80 transition-colors"
            @click="insertVariable"
          >
            + variável
          </button>
        </div>
        <textarea
          v-model="state.bodyText"
          rows="4"
          placeholder="Olá {{nome}}, seu agendamento está confirmado para {{data}}. Até logo, {{profissional}}!"
          class="w-full rounded-lg border border-n-weak bg-n-alpha-2 px-3 py-2 text-sm text-n-slate-12 placeholder-n-slate-8 resize-none focus:outline-none focus:border-n-brand transition-colors"
        />
        <div v-if="bodyErrors.length" class="flex flex-col gap-1 mt-1">
          <p
            v-for="err in bodyErrors"
            :key="err"
            class="text-[11px] text-n-ruby-9"
          >
            ⚠ {{ err }}
          </p>
        </div>
        <p v-else class="text-[11px] text-n-slate-8">
          Use variáveis como {{ varLabel('nome') }}, {{ varLabel('data') }},
          {{ varLabel('profissional') }}.
        </p>
      </div>

      <!-- Exemplos de variáveis -->
      <div
        v-if="namedVars.length > 0"
        class="flex flex-col gap-2 p-3 rounded-lg border border-n-weak bg-n-alpha-2"
      >
        <p class="text-xs font-semibold text-n-slate-11">
          Exemplos para aprovação da Meta
        </p>
        <div
          v-for="(varName, idx) in namedVars"
          :key="varName"
          class="flex items-center gap-2"
        >
          <span
            class="text-[11px] font-mono text-n-brand bg-n-brand/10 px-1.5 py-0.5 rounded flex-shrink-0"
            >{{ varLabel(varName) }}</span
          >
          <input
            v-model="exampleValues[idx]"
            type="text"
            :placeholder="`Exemplo de ${varName}`"
            class="flex-1 rounded-md border border-n-weak bg-n-surface-1 px-2 py-1 text-xs text-n-slate-12 placeholder-n-slate-8 focus:outline-none focus:border-n-brand transition-colors"
          />
        </div>
      </div>

      <!-- Rodapé (opcional) -->
      <div class="flex flex-col gap-1">
        <label class="text-sm font-medium text-n-slate-12"
          >Rodapé
          <span class="text-n-slate-8 font-normal">(opcional)</span></label
        >
        <input
          v-model="state.footer"
          type="text"
          placeholder="Ex: Responda PARAR para cancelar"
          class="w-full rounded-lg border border-n-weak bg-n-alpha-2 px-3 py-2 text-sm text-n-slate-12 placeholder-n-slate-8 focus:outline-none focus:border-n-brand transition-colors"
        />
      </div>

      <!-- Botões -->
      <div class="flex flex-col gap-2">
        <div class="flex items-center justify-between">
          <label class="text-sm font-medium text-n-slate-12"
            >Botões
            <span class="text-n-slate-8 font-normal">(até 3)</span></label
          >
          <button
            v-if="state.buttons.length < 3"
            type="button"
            class="text-[11px] font-semibold text-n-brand hover:text-n-brand/80 transition-colors"
            @click="addButton"
          >
            + adicionar botão
          </button>
        </div>
        <div
          v-for="(btn, idx) in state.buttons"
          :key="idx"
          class="p-3 rounded-lg border border-n-weak bg-n-alpha-2 flex flex-col gap-2"
        >
          <div class="flex items-center gap-2">
            <div class="flex-1">
              <ComboBox
                v-model="btn.type"
                :options="buttonTypeOptions"
                class="[&>div>button]:bg-n-surface-1 [&>div>button]:text-xs"
              />
            </div>
            <button
              type="button"
              class="text-n-slate-8 hover:text-n-ruby-9 transition-colors flex-shrink-0"
              @click="removeButton(idx)"
            >
              <svg
                width="14"
                height="14"
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
          <input
            v-model="btn.text"
            type="text"
            placeholder="Texto do botão"
            class="w-full rounded-md border border-n-weak bg-n-surface-1 px-2 py-1.5 text-xs text-n-slate-12 placeholder-n-slate-8 focus:outline-none focus:border-n-brand transition-colors"
          />
          <input
            v-if="btn.type === 'URL'"
            v-model="btn.url"
            type="url"
            placeholder="https://exemplo.com"
            class="w-full rounded-md border border-n-weak bg-n-surface-1 px-2 py-1.5 text-xs text-n-slate-12 placeholder-n-slate-8 focus:outline-none focus:border-n-brand transition-colors"
          />
          <input
            v-if="btn.type === 'PHONE_NUMBER'"
            v-model="btn.phone"
            type="tel"
            placeholder="+5511999998888"
            class="w-full rounded-md border border-n-weak bg-n-surface-1 px-2 py-1.5 text-xs text-n-slate-12 placeholder-n-slate-8 focus:outline-none focus:border-n-brand transition-colors"
          />
        </div>
      </div>

      <!-- Preview -->
      <div
        v-if="state.bodyText"
        class="p-3 rounded-lg bg-n-alpha-black2 border border-n-weak"
      >
        <p class="text-[11px] font-semibold text-n-slate-9 mb-1.5">
          Pré-visualização
        </p>
        <p class="text-sm text-n-slate-12 whitespace-pre-wrap">
          {{ state.bodyText }}
        </p>
        <p v-if="state.footer" class="text-xs text-n-slate-8 mt-1">
          {{ state.footer }}
        </p>
        <div v-if="state.buttons.length" class="mt-2 flex flex-wrap gap-1">
          <span
            v-for="(btn, i) in state.buttons"
            :key="i"
            class="text-[11px] px-2 py-0.5 rounded border border-n-brand/40 text-n-brand"
            >{{ btn.text || '...' }}</span
          >
        </div>
      </div>

      <!-- Erros / Sucesso -->
      <p
        v-if="error"
        class="text-xs text-n-ruby-9 bg-n-ruby-9/10 px-3 py-2 rounded-lg"
      >
        {{ error }}
      </p>
      <p
        v-if="success"
        class="text-xs text-green-600 bg-green-50 dark:bg-green-900/20 px-3 py-2 rounded-lg"
      >
        {{ success }}
      </p>

      <!-- Ações -->
      <div class="flex gap-3 justify-end">
        <Button
          variant="faded"
          color="slate"
          size="sm"
          label="Cancelar"
          type="button"
          @click="emit('close')"
        />
        <Button
          size="sm"
          label="Enviar para Meta"
          type="button"
          :disabled="!isValid || loading"
          @click="handleSubmit"
        />
      </div>
    </div>
  </div>
</template>
