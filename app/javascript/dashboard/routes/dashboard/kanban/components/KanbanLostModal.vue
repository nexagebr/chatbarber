<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';

defineProps({
  conversation: { type: Object, required: true },
  stageName: { type: String, default: 'Perdido' },
});

const emit = defineEmits(['confirm', 'cancel']);

const store = useStore();

const lossReasons = computed(() => store.getters['kanbanLossReasons/getActiveLossReasons']);

const selectedReason = ref('');
const customReason = ref('');
const outcomeNote = ref('');
const isCustom = ref(false);

const finalReason = computed(() => {
  if (isCustom.value) return customReason.value.trim();
  return selectedReason.value;
});

const canConfirm = computed(() => finalReason.value.length > 0);

const selectReason = reason => {
  selectedReason.value = reason;
  isCustom.value = false;
};

const selectCustom = () => {
  selectedReason.value = '';
  isCustom.value = true;
};

const confirm = () => {
  if (!canConfirm.value) return;
  emit('confirm', {
    lossReason: finalReason.value,
    outcomeNote: outcomeNote.value.trim() || null,
  });
};

onMounted(() => {
  store.dispatch('kanbanLossReasons/get');
});
</script>

<template>
  <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
    <div class="absolute inset-0 bg-black/50" @click="$emit('cancel')" />
    <div class="relative w-full max-w-lg bg-n-solid-1 rounded-2xl shadow-2xl border border-n-weak flex flex-col max-h-[90vh]">

      <!-- Header -->
      <div class="flex items-center justify-between px-6 py-4 border-b border-n-weak flex-shrink-0">
        <div class="flex items-center gap-2">
          <span class="i-lucide-x-circle text-ruby-9 text-lg" />
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

        <!-- Motivo de perda -->
        <div class="flex flex-col gap-1.5">
          <label class="text-xs font-semibold text-n-slate-10">
            Motivo de perda <span class="text-ruby-9">*</span>
          </label>

          <!-- Preset reasons -->
          <div v-if="lossReasons.length > 0" class="flex flex-col gap-1.5">
            <button
              v-for="reason in lossReasons"
              :key="reason.id"
              type="button"
              class="flex items-center gap-2.5 h-10 px-3 rounded-lg border text-left text-sm transition-colors"
              :class="selectedReason === reason.name && !isCustom
                ? 'bg-ruby-3 border-ruby-7 text-ruby-11 font-medium'
                : 'border-n-weak bg-n-solid-2 text-n-slate-11 hover:border-ruby-6 hover:bg-ruby-2'"
              @click="selectReason(reason.name)"
            >
              <span
                class="text-sm flex-shrink-0"
                :class="selectedReason === reason.name && !isCustom
                  ? 'i-lucide-check-circle text-ruby-9'
                  : 'i-lucide-circle text-n-slate-7'"
              />
              {{ reason.name }}
            </button>
          </div>

          <p v-else class="text-xs text-n-slate-8 flex items-center gap-1.5 py-1">
            <span class="i-lucide-info text-xs" />
            Nenhum motivo cadastrado. Configure na aba "Motivos de Perda".
          </p>

          <!-- Custom reason option -->
          <button
            type="button"
            class="flex items-center gap-2.5 h-10 px-3 rounded-lg border text-left text-sm w-full transition-colors"
            :class="isCustom
              ? 'bg-ruby-3 border-ruby-7 text-ruby-11 font-medium'
              : 'border-dashed border-n-weak bg-n-solid-2 text-n-slate-9 hover:border-ruby-6 hover:text-n-slate-11'"
            @click="selectCustom"
          >
            <span class="i-lucide-pencil text-sm flex-shrink-0" />
            Outro motivo (digitar)
          </button>

          <input
            v-if="isCustom"
            v-model="customReason"
            type="text"
            placeholder="Descreva o motivo…"
            class="h-10 px-3 rounded-lg border border-n-weak bg-n-solid-2 text-sm text-n-slate-12 placeholder:text-n-slate-8 focus:outline-none focus:ring-2 focus:ring-ruby-9/30 focus:border-ruby-7 transition-colors"
            autofocus
          />
        </div>

        <!-- Observação -->
        <div class="flex flex-col gap-1.5">
          <label class="text-xs font-semibold text-n-slate-10">
            Observação <span class="font-normal text-n-slate-8">(opcional)</span>
          </label>
          <textarea
            v-model="outcomeNote"
            rows="3"
            placeholder="Ex: Cliente escolheu concorrente por preço, voltará em 6 meses…"
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
          class="h-9 px-4 rounded-lg bg-ruby-9 text-white text-sm font-semibold hover:bg-ruby-10 transition-colors disabled:opacity-40 disabled:cursor-not-allowed flex items-center gap-2"
          :disabled="!canConfirm"
          @click="confirm"
        >
          <span class="i-lucide-check text-sm" />
          Confirmar perda
        </button>
      </div>
    </div>
  </div>
</template>
