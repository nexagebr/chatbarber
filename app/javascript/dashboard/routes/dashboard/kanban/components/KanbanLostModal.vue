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
  <div class="kmo-overlay" @click.self="$emit('cancel')">
    <div class="kmo-box">

      <!-- Header -->
      <div class="kmo-head">
        <div style="display:flex;align-items:center;gap:8px">
          <span class="i-lucide-x-circle" style="font-size:16px;color:#ef4444;flex-shrink:0" />
          <span class="kmo-title">{{ stageName }}</span>
        </div>
        <button class="kmo-x" @click="$emit('cancel')">
          <span class="i-lucide-x" style="font-size:15px" />
        </button>
      </div>

      <!-- Contact strip -->
      <div class="kmo-contact">
        <span class="i-lucide-user" style="font-size:12px;color:rgb(var(--slate-8));flex-shrink:0" />
        <span class="kmo-contact-name">{{ conversation.meta?.sender?.name || 'Sem nome' }}</span>
        <span class="kmo-contact-id">#{{ conversation.id }}</span>
      </div>

      <!-- Form -->
      <div class="kmo-form">

        <!-- Motivo -->
        <div class="kmo-field">
          <label class="kmo-lbl">Motivo de perda <span style="color:#ef4444">*</span></label>

          <div v-if="lossReasons.length > 0" style="display:flex;flex-wrap:wrap;gap:6px">
            <button
              v-for="reason in lossReasons"
              :key="reason.id"
              type="button"
              class="kmo-chip"
              :class="{ 'kmo-chip--lost': selectedReason === reason.name && !isCustom }"
              @click="selectReason(reason.name)"
            >
              {{ reason.name }}
            </button>
          </div>

          <p v-else class="kmo-empty">
            <span class="i-lucide-info" style="font-size:11px" />
            Nenhum motivo cadastrado. Configure na aba "Motivos de Perda".
          </p>

          <button
            type="button"
            class="kmo-chip kmo-chip--dashed"
            :class="{ 'kmo-chip--lost': isCustom }"
            @click="selectCustom"
          >
            <span class="i-lucide-pencil" style="font-size:11px" />
            Outro (digitar)
          </button>

          <input
            v-if="isCustom"
            v-model="customReason"
            type="text"
            placeholder="Descreva o motivo…"
            class="reset-base kmo-inp"
            autofocus
          />
        </div>

        <!-- Observação -->
        <div class="kmo-field">
          <label class="kmo-lbl">Observação <span class="kmo-opt">(opcional)</span></label>
          <textarea
            v-model="outcomeNote"
            rows="2"
            placeholder="Ex: Cliente escolheu concorrente por preço…"
            class="kmo-inp"
            style="height:auto;padding:8px 10px;resize:none"
          />
        </div>
      </div>

      <!-- Footer -->
      <div class="kmo-foot">
        <button type="button" class="kmo-btn-cancel" @click="$emit('cancel')">Cancelar</button>
        <button
          type="button"
          class="kmo-btn-del"
          :disabled="!canConfirm"
          @click="confirm"
        >
          Confirmar perda
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.kmo-overlay {
  position: fixed; inset: 0; z-index: 9999;
  display: flex; align-items: center; justify-content: center; padding: 16px;
  background: rgba(0,0,0,.65);
  backdrop-filter: blur(8px);
}
.kmo-box {
  position: relative; width: 100%; max-width: 440px; max-height: 90vh;
  background: rgb(var(--surface-1));
  border: 1px solid rgb(var(--border-strong));
  border-radius: 14px;
  box-shadow: 0 24px 64px rgba(0,0,0,.4);
  display: flex; flex-direction: column; overflow: hidden;
}
.kmo-head {
  display: flex; align-items: center; justify-content: space-between;
  padding: 16px 20px; border-bottom: 1px solid rgb(var(--border-weak)); flex-shrink: 0;
}
.kmo-title { font-size: 15px; font-weight: 700; color: rgb(var(--slate-12)); }
.kmo-x {
  background: none; border: none; cursor: pointer;
  color: rgb(var(--slate-8)); display: flex; transition: color .12s;
}
.kmo-x:hover { color: rgb(var(--slate-12)); }

.kmo-contact {
  display: flex; align-items: center; gap: 6px;
  padding: 8px 20px; border-bottom: 1px solid rgb(var(--border-weak));
  background: rgb(var(--background-color)); flex-shrink: 0;
}
.kmo-contact-name { font-size: 12px; font-weight: 600; color: rgb(var(--slate-12)); }
.kmo-contact-id { font-size: 11px; color: rgb(var(--slate-8)); font-family: monospace; margin-left: 2px; }

.kmo-form {
  flex: 1; overflow-y: auto; padding: 16px 20px;
  display: flex; flex-direction: column; gap: 14px;
}
.kmo-field { display: flex; flex-direction: column; gap: 6px; }
.kmo-lbl { font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: .1em; color: rgb(var(--slate-8)); }
.kmo-opt { text-transform: none; font-weight: 400; letter-spacing: 0; }

.kmo-inp {
  width: 100%; height: 34px; padding: 0 10px; border-radius: 8px;
  border: 1px solid rgb(var(--border-strong));
  background: rgb(var(--background-color));
  color: rgb(var(--slate-12)); font-size: 12px; font-family: inherit;
  outline: none; transition: border-color .15s; box-sizing: border-box;
}
.kmo-inp:focus { border-color: #ef4444; }

.kmo-chip {
  padding: 5px 10px; border-radius: 20px; cursor: pointer;
  font-size: 11px; font-weight: 600;
  background: rgb(var(--background-color));
  border: 1px solid rgb(var(--border-weak));
  color: rgb(var(--slate-10));
  transition: all .12s; display: inline-flex; align-items: center; gap: 4px;
}
.kmo-chip:hover { color: rgb(var(--slate-12)); border-color: rgb(var(--border-strong)); }
.kmo-chip--lost { background: rgba(239,68,68,.15); border-color: rgba(239,68,68,.5); color: #ef4444; }
.kmo-chip--dashed { border-style: dashed; }

.kmo-empty {
  display: flex; align-items: center; gap: 4px;
  font-size: 11px; color: rgb(var(--slate-8)); font-style: italic; margin: 0;
}

.kmo-foot {
  display: flex; align-items: center; justify-content: flex-end; gap: 8px;
  padding: 14px 20px; border-top: 1px solid rgb(var(--border-weak)); flex-shrink: 0;
}
.kmo-btn-cancel {
  height: 32px; padding: 0 14px; border-radius: 8px;
  border: 1px solid rgb(var(--border-strong)); background: transparent;
  color: rgb(var(--slate-10)); font-size: 12px; font-weight: 600; cursor: pointer;
  transition: background .12s;
}
.kmo-btn-cancel:hover { background: rgb(var(--surface-2)); }
.kmo-btn-del {
  height: 32px; padding: 0 16px; border-radius: 8px;
  background: #ef4444; color: #fff; font-size: 12px; font-weight: 700;
  border: none; cursor: pointer; transition: opacity .15s;
}
.kmo-btn-del:hover:not(:disabled) { opacity: .88; }
.kmo-btn-del:disabled { opacity: .45; cursor: not-allowed; }
</style>
