<script setup>
import { ref, computed, watch } from 'vue';
import { useStore } from 'vuex';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  kbId: { type: [String, Number], required: true },
});

const emit = defineEmits(['kb-updated']);

const store  = useStore();
const router = useRouter();

const active  = computed(() => store.getters['knowledgeBases/getActive']);
const uiFlags = computed(() => store.getters['knowledgeBases/getUIFlags']);

const form = ref({ name: '', description: '' });

watch(active, kb => {
  if (kb) form.value = { name: kb.name || '', description: kb.description || '' };
}, { immediate: true });

const saveSettings = async () => {
  if (!form.value.name.trim()) { useAlert('O nome é obrigatório.'); return; }
  try {
    await store.dispatch('knowledgeBases/updateKB', {
      id: props.kbId,
      name: form.value.name.trim(),
      description: form.value.description.trim(),
    });
    useAlert('Configurações salvas.');
    emit('kb-updated');
  } catch {
    useAlert('Erro ao salvar configurações.');
  }
};

const showDeleteDialog = ref(false);

const confirmDeleteKB = async () => {
  try {
    await store.dispatch('knowledgeBases/deleteKB', props.kbId);
    useAlert('Base de conhecimento excluída.');
    router.push({ name: 'knowledge_base_list' });
  } catch {
    useAlert('Erro ao excluir base de conhecimento.');
  }
  showDeleteDialog.value = false;
};
</script>

<template>
  <div class="flex flex-col gap-8 pb-8 max-w-2xl">

    <!-- ── Informações ────────────────────────────────────────── -->
    <div class="flex flex-col gap-1 pb-4 border-b border-n-weak">
      <h5 class="text-base font-semibold text-n-slate-12">Informações da base</h5>
      <p class="text-sm text-n-slate-9">Edite o nome e a descrição desta base de conhecimento.</p>
    </div>

    <div class="flex flex-col gap-5">
      <div class="flex flex-col gap-1.5">
        <label class="text-sm font-medium text-n-slate-11">
          Nome <span class="text-ruby-9">*</span>
        </label>
        <input
          v-model="form.name"
          type="text"
          placeholder="Nome da base de conhecimento"
          class="h-10 px-3 rounded-lg border border-n-weak bg-n-solid-2 text-sm text-n-slate-12 placeholder:text-n-slate-8 focus:outline-none focus:ring-2 focus:ring-n-brand/30 w-full"
        />
      </div>

      <div class="flex flex-col gap-1.5">
        <label class="text-sm font-medium text-n-slate-11">
          Descrição
          <span class="font-normal text-n-slate-8 text-xs ml-1">(opcional)</span>
        </label>
        <textarea
          v-model="form.description"
          rows="3"
          placeholder="Descreva o propósito desta base de conhecimento..."
          class="px-3 py-2 rounded-lg border border-n-weak bg-n-solid-2 text-sm text-n-slate-12 placeholder:text-n-slate-8 focus:outline-none focus:ring-2 focus:ring-n-brand/30 resize-none w-full"
        />
      </div>

      <div>
        <Button
          label="Salvar alterações"
          size="sm"
          :is-loading="uiFlags.isSaving"
          :disabled="uiFlags.isSaving"
          @click="saveSettings"
        />
      </div>
    </div>

    <!-- ── Zona de perigo ─────────────────────────────────────── -->
    <div class="flex flex-col gap-4 p-5 rounded-xl border border-ruby-6 bg-ruby-2/40">
      <div class="flex flex-col gap-1">
        <h6 class="text-sm font-semibold text-ruby-11">Excluir base de conhecimento</h6>
        <p class="text-sm text-n-slate-10 leading-relaxed">
          Todos os FAQs, arquivos, sites e vínculos serão permanentemente removidos.
          Esta ação não pode ser desfeita.
        </p>
      </div>
      <div>
        <Button
          :label="`Excluir ${active?.name || 'base'}`"
          color="ruby"
          size="sm"
          @click="showDeleteDialog = true"
        />
      </div>
    </div>

  </div>

  <!-- DELETE CONFIRMATION -->
  <Teleport to="body">
    <div v-if="showDeleteDialog" class="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div class="absolute inset-0 bg-black/50" @click="showDeleteDialog = false" />
      <div class="relative w-full max-w-sm bg-n-solid-1 rounded-2xl shadow-2xl border border-n-weak p-6 flex flex-col gap-4">
        <div class="flex items-start gap-3">
          <div class="w-10 h-10 rounded-full bg-ruby-3 flex items-center justify-center flex-shrink-0">
            <span class="i-lucide-alert-triangle text-ruby-11 text-lg" />
          </div>
          <div>
            <h3 class="text-base font-semibold text-n-slate-12">Excluir base de conhecimento</h3>
            <p class="text-sm text-n-slate-10 mt-1">
              Esta ação é irreversível. Todos os dados desta base serão excluídos permanentemente.
            </p>
          </div>
        </div>
        <div class="flex items-center justify-end gap-3">
          <button
            class="h-9 px-4 rounded-lg border border-n-weak text-sm font-semibold text-n-slate-11 hover:bg-n-alpha-2 transition-colors"
            @click="showDeleteDialog = false"
          >
            Cancelar
          </button>
          <button
            class="h-9 px-4 rounded-lg bg-ruby-9 text-white text-sm font-semibold hover:bg-ruby-10 transition-colors flex items-center gap-2"
            :disabled="uiFlags.isSaving"
            @click="confirmDeleteKB"
          >
            <span v-if="uiFlags.isSaving" class="i-lucide-loader-2 animate-spin text-sm" />
            Excluir permanentemente
          </button>
        </div>
      </div>
    </div>
  </Teleport>
</template>
