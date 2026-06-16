<script setup>
import { ref } from 'vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';

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
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm" @click.self="$emit('cancel')">
    <div class="w-full max-w-md bg-n-surface-1 rounded-2xl shadow-2xl overflow-hidden">

      <!-- Header verde -->
      <div class="flex items-center gap-3 px-6 py-5 bg-gradient-to-r from-emerald-500/20 to-emerald-400/10 border-b border-emerald-500/20">
        <div class="w-11 h-11 rounded-xl bg-emerald-500/20 flex items-center justify-center flex-shrink-0">
          <i class="i-lucide-trophy text-2xl text-emerald-500" />
        </div>
        <div>
          <h2 class="text-base font-bold text-n-slate-12">🎉 {{ stageName }}</h2>
          <p class="text-xs text-n-slate-10 mt-0.5">Registre os detalhes desta conquista</p>
        </div>
        <button class="ml-auto text-n-slate-9 hover:text-n-slate-12 transition-colors" @click="$emit('cancel')">
          <i class="i-lucide-x text-base" />
        </button>
      </div>

      <!-- Contact info -->
      <div class="flex items-center gap-3 px-6 py-4 border-b border-n-weak bg-n-alpha-1">
        <Avatar
          :src="conversation.meta?.sender?.thumbnail"
          :username="conversation.meta?.sender?.name"
          :size="36"
        />
        <div>
          <p class="text-sm font-semibold text-n-slate-12">{{ conversation.meta?.sender?.name || 'Sem nome' }}</p>
          <p class="text-xs text-n-slate-9">#{{ conversation.id }}</p>
        </div>
      </div>

      <!-- Form -->
      <div class="px-6 py-5 space-y-4">

        <!-- Valor da venda (obrigatório visualmente destacado) -->
        <div class="space-y-1.5">
          <label class="flex items-center gap-1.5 text-xs font-bold text-n-slate-11 uppercase tracking-wide">
            <i class="i-lucide-circle-dollar-sign text-emerald-500" />
            Valor da venda
            <span class="text-[10px] font-normal normal-case text-emerald-600 bg-emerald-500/10 px-1.5 py-0.5 rounded">obrigatório</span>
          </label>
          <div class="relative">
            <span class="absolute left-3 top-1/2 -translate-y-1/2 text-sm font-semibold text-n-slate-10">R$</span>
            <input
              v-model="dealValue"
              type="number"
              step="0.01"
              min="0"
              placeholder="0,00"
              class="w-full pl-10 pr-4 py-3 text-lg font-bold border-2 border-emerald-500/30 rounded-xl bg-n-surface-1 text-n-slate-12 focus:outline-none focus:border-emerald-500 transition-colors"
              autofocus
            />
          </div>
        </div>

        <!-- Observação -->
        <div class="space-y-1.5">
          <label class="text-xs font-semibold text-n-slate-11 uppercase tracking-wide">
            Observação <span class="normal-case text-n-slate-9 font-normal">(opcional)</span>
          </label>
          <textarea
            v-model="outcomeNote"
            rows="2"
            placeholder="Ex: Cliente assinou contrato anual, negociação durou 3 semanas…"
            class="w-full text-sm border border-n-weak rounded-xl px-3 py-2.5 bg-n-surface-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 resize-none transition-colors"
          />
        </div>
      </div>

      <!-- Footer -->
      <div class="flex items-center justify-end gap-2 px-6 py-4 border-t border-n-weak bg-n-alpha-1">
        <Button variant="secondary" size="sm" @click="$emit('cancel')">Cancelar</Button>
        <button
          class="flex items-center gap-1.5 px-4 py-2 rounded-lg text-sm font-semibold bg-emerald-500 hover:bg-emerald-600 text-white transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          :disabled="dealValue === '' || dealValue === null"
          @click="confirm"
        >
          <i class="i-lucide-check text-sm" />
          Confirmar venda ganha
        </button>
      </div>
    </div>
  </div>
</template>
