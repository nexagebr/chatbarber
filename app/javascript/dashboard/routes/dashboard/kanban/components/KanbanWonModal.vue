<script setup>
import { ref } from 'vue';

const props = defineProps({
  conversation: { type: Object, required: true },
  stageName: { type: String, default: 'Venda Ganha' },
});

const emit = defineEmits(['confirm', 'cancel']);

const dealValue = ref(
  props.conversation.additional_attributes?.deal_value ??
  props.conversation.custom_attributes?.deal_value ??
  ''
);
const outcomeNote = ref('');

const confirm = () => {
  emit('confirm', {
    dealValue: dealValue.value !== '' ? Number(String(dealValue.value).replace(/[^0-9,.]/g, '').replace(',', '.')) : null,
    outcomeNote: outcomeNote.value.trim() || null,
  });
};
</script>

<template>
  <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
    <div class="absolute inset-0 bg-black/50" @click="$emit('cancel')" />
    <div class="relative w-full max-w-lg bg-n-solid-1 rounded-2xl shadow-2xl border border-n-weak flex flex-col max-h-[90vh]">

      <!-- Header -->
      <div class="flex items-center justify-between px-6 py-4 border-b border-n-weak flex-shrink-0">
        <div class="flex items-center gap-2">
          <span class="i-lucide-trophy text-n-brand text-lg" />
          <h3 class="text-base font-semibold text-n-slate-12">{{ stageName }}</h3>
        </div>
        <button
          class="w-8 h-8 rounded-lg flex items-center justify-center text-n-slate-9 hover:bg-n-alpha-2 transition-colors"
          @click="$emit('cancel')"
        >
          <span class="i-lucide-x text-base" />
        </button>
      </div>

      <!-- Contact info -->
      <div class="flex items-center gap-3 px-6 py-3 border-b border-n-weak bg-n-alpha-1 flex-shrink-0">
        <div class="w-8 h-8 rounded-full bg-n-alpha-black2 flex items-center justify-center flex-shrink-0 border border-n-weak">
          <span class="i-lucide-user text-n-slate-7 text-sm" />
        </div>
        <div class="min-w-0">
          <p class="text-sm font-medium text-n-slate-12 truncate">{{ conversation.meta?.sender?.name || 'Sem nome' }}</p>
          <p class="text-xs text-n-slate-8 font-mono">#{{ conversation.id }}</p>
        </div>
      </div>

      <!-- Form -->
      <div class="flex-1 overflow-y-auto px-6 py-5 flex flex-col gap-4">

        <!-- Valor da venda -->
        <div class="flex flex-col gap-1.5">
          <label class="text-xs font-semibold text-n-slate-10">
            Valor da venda <span class="font-normal text-n-slate-8">(opcional)</span>
          </label>
          <div class="flex h-10 rounded-lg border border-n-weak bg-n-solid-2 overflow-hidden focus-within:ring-2 focus-within:ring-n-brand/30">
            <span
            class="flex items-center px-3 text-xs text-n-slate-8 border-r border-n-weak bg-n-alpha-1 flex-shrink-0 select-none"
            >R$</span
          >
            <input
              v-model="dealValue"
              type="text"
              inputmode="decimal"
              placeholder="0,00"
              class="flex-1 px-3 bg-transparent text-sm text-n-slate-12 placeholder:text-n-slate-8 focus:outline-none min-w-0"
              autofocus
            />
          </div>
        </div>

        <!-- Observação -->
        <div class="flex flex-col gap-1.5">
          <label class="text-xs font-semibold text-n-slate-10">
            Observação <span class="font-normal text-n-slate-8">(opcional)</span>
          </label>
          <textarea
            v-model="outcomeNote"
            rows="3"
            placeholder="Ex: Cliente assinou contrato anual, negociação durou 3 semanas…"
            class="px-3 py-2 rounded-lg border border-n-weak bg-n-solid-2 text-sm text-n-slate-12 placeholder:text-n-slate-8 focus:outline-none focus:ring-2 focus:ring-n-brand/30 resize-none"
          />
        </div>
      </div>

      <!-- Footer -->
      <div class="flex items-center justify-end gap-3 px-6 py-4 border-t border-n-weak flex-shrink-0">
        <button
          class="h-9 px-4 rounded-lg border border-n-weak text-sm font-semibold text-n-slate-11 hover:bg-n-alpha-2 transition-colors"
          @click="$emit('cancel')"
        >
          Cancelar
        </button>
        <button
          class="h-9 px-4 rounded-lg bg-n-brand text-white text-sm font-semibold hover:brightness-110 transition-all flex items-center gap-2"
          @click="confirm"
        >
          <span class="i-lucide-check text-sm" />
          Confirmar venda
        </button>
      </div>
    </div>
  </div>
</template>
