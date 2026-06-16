<script setup>
import { ref, computed, watch } from 'vue';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAlert } from 'dashboard/composables';
import { applyAccountTheme } from 'dashboard/helper/themeHelper';
import NextButton from 'dashboard/components-next/button/Button.vue';

const { currentAccount, updateAccount } = useAccount();

const PRESET_COLORS = [
  { label: 'Violeta (padrão)', value: '#4241FF' },
  { label: 'Azul', value: '#0EA5E9' },
  { label: 'Índigo', value: '#6366F1' },
  { label: 'Verde', value: '#10B981' },
  { label: 'Rosa', value: '#EC4899' },
  { label: 'Laranja', value: '#F97316' },
  { label: 'Vermelho', value: '#EF4444' },
  { label: 'Âmbar', value: '#F59E0B' },
  { label: 'Ciano', value: '#06B6D4' },
  { label: 'Roxo', value: '#8B5CF6' },
];

const color = ref(currentAccount.value?.settings?.custom_color || '#4241FF');
const logoUrl = ref(currentAccount.value?.settings?.custom_logo_url || '');
const saving = ref(false);

watch(currentAccount, acc => {
  color.value = acc?.settings?.custom_color || '#4241FF';
  logoUrl.value = acc?.settings?.custom_logo_url || '';
});

// Live preview
watch(color, val => {
  applyAccountTheme({ custom_color: val });
});

const isDirty = computed(() => {
  const s = currentAccount.value?.settings || {};
  return color.value !== (s.custom_color || '#4241FF') ||
    logoUrl.value !== (s.custom_logo_url || '');
});

async function save() {
  saving.value = true;
  try {
    await updateAccount({
      custom_color: color.value === '#4241FF' ? null : color.value,
      custom_logo_url: logoUrl.value.trim() || null,
    });
    useAlert('Aparência salva com sucesso.');
  } catch {
    useAlert('Erro ao salvar aparência.');
  } finally {
    saving.value = false;
  }
}

function resetColor() {
  color.value = '#4241FF';
}
</script>

<template>
  <div class="flex flex-col gap-8">

    <!-- Brand color -->
    <div class="flex flex-col gap-4">
      <div>
        <h5 class="text-sm font-semibold text-n-slate-12">Cor principal</h5>
        <p class="text-xs text-n-slate-8 mt-0.5">Altera botões, links e elementos ativos em todo o app.</p>
      </div>

      <!-- Presets grid -->
      <div class="flex flex-wrap gap-2">
        <button
          v-for="preset in PRESET_COLORS"
          :key="preset.value"
          type="button"
          class="w-8 h-8 rounded-full border-2 transition-all hover:scale-110"
          :class="color === preset.value
            ? 'border-n-slate-12 scale-110 shadow-md'
            : 'border-transparent'"
          :style="{ backgroundColor: preset.value }"
          :title="preset.label"
          @click="color = preset.value"
        />
      </div>

      <!-- Custom color picker row -->
      <div class="flex items-center gap-3">
        <div class="relative">
          <input
            v-model="color"
            type="color"
            class="w-10 h-10 rounded-xl border border-n-weak cursor-pointer bg-transparent p-0.5"
          />
        </div>
        <div class="flex flex-col gap-0.5">
          <span class="text-xs font-medium text-n-slate-11">Cor personalizada</span>
          <code class="text-[11px] text-n-slate-8 font-mono">{{ color }}</code>
        </div>
        <button
          class="ml-auto text-xs text-n-slate-7 hover:text-n-slate-11 underline transition-colors"
          type="button"
          @click="resetColor"
        >Restaurar padrão</button>
      </div>

      <!-- Live preview strip -->
      <div class="flex items-center gap-3 p-3 rounded-xl bg-n-solid-2 border border-n-weak">
        <span class="text-xs text-n-slate-8">Prévia:</span>
        <button
          class="h-7 px-4 rounded-lg text-xs font-semibold text-white transition-all"
          :style="{ backgroundColor: color }"
        >Botão</button>
        <a
          href="#"
          class="text-xs font-medium underline transition-colors"
          :style="{ color: color }"
          @click.prevent
        >Link de exemplo</a>
        <div
          class="w-4 h-4 rounded border-2 transition-all"
          :style="{ borderColor: color, backgroundColor: color + '20' }"
        />
      </div>
    </div>

    <!-- Logo URL -->
    <div class="flex flex-col gap-3 pt-6 border-t border-n-weak">
      <div>
        <h5 class="text-sm font-semibold text-n-slate-12">Logo da conta</h5>
        <p class="text-xs text-n-slate-8 mt-0.5">URL de imagem exibida no topo da barra lateral. Deixe vazio para usar o logo padrão.</p>
      </div>
      <div class="flex items-center gap-3">
        <div
          class="w-10 h-10 rounded-xl border border-n-weak bg-n-solid-2 flex items-center justify-center overflow-hidden flex-shrink-0"
        >
          <img
            v-if="logoUrl"
            :src="logoUrl"
            class="w-full h-full object-contain"
            @error="logoUrl = ''"
          />
          <span v-else class="i-lucide-image text-n-slate-6 text-lg" />
        </div>
        <input
          v-model="logoUrl"
          type="url"
          placeholder="https://seusite.com/logo.png"
          class="flex-1 h-9 px-3 rounded-lg border border-n-weak bg-n-solid-2 text-xs text-n-slate-12 placeholder:text-n-slate-6 focus:outline-none focus:ring-2 focus:ring-n-brand/30 focus:border-n-brand/50"
        />
      </div>
    </div>

    <!-- Save -->
    <div class="flex items-center gap-3 pt-2">
      <NextButton
        type="submit"
        size="md"
        :disabled="saving || !isDirty"
        :is-loading="saving"
        @click="save"
      >
        Salvar aparência
      </NextButton>
      <span v-if="!isDirty" class="text-xs text-n-slate-7">Sem alterações</span>
    </div>

  </div>
</template>
