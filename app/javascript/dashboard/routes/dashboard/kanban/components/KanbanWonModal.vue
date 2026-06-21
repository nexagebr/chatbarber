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
  <div class="kmo-overlay" @click.self="$emit('cancel')">
    <div class="kmo-box">

      <!-- Header -->
      <div class="kmo-head">
        <div style="display:flex;align-items:center;gap:8px">
          <span class="i-lucide-trophy" style="font-size:16px;color:rgb(var(--n-brand,66 65 255));flex-shrink:0" />
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

        <!-- Valor da venda -->
        <div class="kmo-field">
          <label class="kmo-lbl">Valor da venda <span class="kmo-opt">(opcional)</span></label>
          <div class="kmo-inp-wrap">
            <span class="kmo-prefix">R$</span>
            <input
              v-model="dealValue"
              type="text"
              inputmode="decimal"
              placeholder="0,00"
              class="reset-base kmo-inp-inner"
              autofocus
            />
          </div>
        </div>

        <!-- Observação -->
        <div class="kmo-field">
          <label class="kmo-lbl">Observação <span class="kmo-opt">(opcional)</span></label>
          <textarea
            v-model="outcomeNote"
            rows="2"
            placeholder="Ex: Cliente assinou contrato anual…"
            class="kmo-inp"
            style="height:auto;padding:8px 10px;resize:none"
          />
        </div>
      </div>

      <!-- Footer -->
      <div class="kmo-foot">
        <button type="button" class="kmo-btn-cancel" @click="$emit('cancel')">Cancelar</button>
        <button type="button" class="kmo-btn-save" @click="confirm">
          Confirmar venda
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
.kmo-inp:focus { border-color: rgb(var(--n-brand,66 65 255)); }

.kmo-inp-wrap {
  display: flex; height: 34px; border-radius: 8px;
  border: 1px solid rgb(var(--border-strong));
  background: rgb(var(--background-color));
  overflow: hidden; transition: border-color .15s;
}
.kmo-inp-wrap:focus-within { border-color: rgb(var(--n-brand,66 65 255)); }
.kmo-prefix {
  display: flex; align-items: center; padding: 0 10px;
  font-size: 12px; font-weight: 600; color: rgb(var(--slate-8));
  border-right: 1px solid rgb(var(--border-weak));
  background: rgb(var(--surface-2)); flex-shrink: 0;
}
.kmo-inp-inner {
  flex: 1; padding: 0 10px; background: transparent;
  color: rgb(var(--slate-12)); font-size: 13px; font-weight: 600;
  border: none; outline: none; min-width: 0;
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
.kmo-btn-save {
  height: 32px; padding: 0 16px; border-radius: 8px;
  background: rgb(var(--n-brand,66 65 255)); color: #fff;
  font-size: 12px; font-weight: 700; border: none; cursor: pointer;
  transition: opacity .15s;
}
.kmo-btn-save:hover { opacity: .88; }
</style>
