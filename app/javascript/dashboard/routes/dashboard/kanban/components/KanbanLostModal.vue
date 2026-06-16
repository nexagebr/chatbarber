<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import Button from 'dashboard/components-next/button/Button.vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';

const props = defineProps({
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
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm" @click.self="$emit('cancel')">
    <div class="w-full max-w-md bg-n-surface-1 rounded-2xl shadow-2xl overflow-hidden">

      <!-- Header vermelho -->
      <div class="flex items-center gap-3 px-6 py-5 bg-gradient-to-r from-n-ruby-9/15 to-n-ruby-9/5 border-b border-n-ruby-9/20">
        <div class="w-11 h-11 rounded-xl bg-n-ruby-9/15 flex items-center justify-center flex-shrink-0">
          <i class="i-lucide-x-circle text-2xl text-n-ruby-9" />
        </div>
        <div>
          <h2 class="text-base font-bold text-n-slate-12">{{ stageName }}</h2>
          <p class="text-xs text-n-slate-10 mt-0.5">Qual foi o motivo da perda?</p>
        </div>
        <button class="ml-auto text-n-slate-9 hover:text-n-slate-12 transition-colors" @click="$emit('cancel')">
          <i class="i-lucide-x text-base" />
        </button>
      </div>

      <!-- Contact -->
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

        <!-- Motivo de perda -->
        <div class="space-y-2">
          <label class="flex items-center gap-1.5 text-xs font-bold text-n-slate-11 uppercase tracking-wide">
            <i class="i-lucide-flag text-n-ruby-9" />
            Motivo de perda
            <span class="text-[10px] font-normal normal-case text-n-ruby-9 bg-n-ruby-9/10 px-1.5 py-0.5 rounded">obrigatório</span>
          </label>

          <!-- Preset reasons -->
          <div v-if="lossReasons.length > 0" class="flex flex-col gap-1.5">
            <button
              v-for="reason in lossReasons"
              :key="reason.id"
              class="flex items-center gap-2.5 px-3 py-2.5 rounded-xl border text-left text-sm transition-all"
              :class="selectedReason === reason.name && !isCustom
                ? 'bg-n-ruby-9/10 border-n-ruby-9 text-n-ruby-9 font-semibold'
                : 'border-n-weak text-n-slate-11 hover:border-n-ruby-9/40 hover:bg-n-ruby-9/5'"
              @click="selectReason(reason.name)"
            >
              <i
                class="text-sm flex-shrink-0"
                :class="selectedReason === reason.name && !isCustom ? 'i-lucide-check-circle text-n-ruby-9' : 'i-lucide-circle text-n-slate-8'"
              />
              {{ reason.name }}
            </button>
          </div>

          <div v-else class="text-xs text-n-slate-9 italic flex items-center gap-1.5 py-1">
            <i class="i-lucide-info" />
            Nenhum motivo cadastrado. Configure na aba "Motivos de Perda".
          </div>

          <!-- Custom reason option -->
          <button
            class="flex items-center gap-2.5 px-3 py-2.5 rounded-xl border text-left text-sm w-full transition-all"
            :class="isCustom
              ? 'bg-n-ruby-9/10 border-n-ruby-9 text-n-ruby-9 font-semibold'
              : 'border-dashed border-n-weak text-n-slate-9 hover:border-n-ruby-9/40 hover:text-n-slate-11'"
            @click="selectCustom"
          >
            <i class="i-lucide-pencil text-sm flex-shrink-0" />
            Outro motivo (digitar)
          </button>

          <input
            v-if="isCustom"
            v-model="customReason"
            type="text"
            placeholder="Descreva o motivo…"
            class="w-full text-sm border-2 border-n-ruby-9/30 rounded-xl px-3 py-2.5 bg-n-surface-1 text-n-slate-12 focus:outline-none focus:border-n-ruby-9 transition-colors"
            autofocus
          />
        </div>

        <!-- Observação -->
        <div class="space-y-1.5">
          <label class="text-xs font-semibold text-n-slate-11 uppercase tracking-wide">
            Observação <span class="normal-case text-n-slate-9 font-normal">(opcional)</span>
          </label>
          <textarea
            v-model="outcomeNote"
            rows="2"
            placeholder="Ex: Cliente escolheu concorrente por preço, voltará em 6 meses…"
            class="w-full text-sm border border-n-weak rounded-xl px-3 py-2.5 bg-n-surface-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-ruby-9/20 focus:border-n-ruby-9/50 resize-none transition-colors"
          />
        </div>
      </div>

      <!-- Footer -->
      <div class="flex items-center justify-end gap-2 px-6 py-4 border-t border-n-weak bg-n-alpha-1">
        <Button variant="secondary" size="sm" @click="$emit('cancel')">Cancelar</Button>
        <button
          class="flex items-center gap-1.5 px-4 py-2 rounded-lg text-sm font-semibold bg-n-ruby-9 hover:bg-n-ruby-11 text-white transition-colors disabled:opacity-40 disabled:cursor-not-allowed"
          :disabled="!canConfirm"
          @click="confirm"
        >
          <i class="i-lucide-check text-sm" />
          Confirmar perda
        </button>
      </div>
    </div>
  </div>
</template>
