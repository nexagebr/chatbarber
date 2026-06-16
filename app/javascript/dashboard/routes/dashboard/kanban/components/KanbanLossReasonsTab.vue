<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import Button from 'dashboard/components-next/button/Button.vue';

const store = useStore();

const reasons = computed(() => store.getters['kanbanLossReasons/getLossReasons']);
const newName = ref('');
const editingId = ref(null);
const editingName = ref('');
const isSaving = ref(false);

onMounted(() => store.dispatch('kanbanLossReasons/get'));

const createReason = async () => {
  const name = newName.value.trim();
  if (!name) return;
  isSaving.value = true;
  try {
    await store.dispatch('kanbanLossReasons/create', { name, active: true });
    newName.value = '';
  } finally {
    isSaving.value = false;
  }
};

const startEdit = reason => {
  editingId.value = reason.id;
  editingName.value = reason.name;
};

const saveEdit = async () => {
  const name = editingName.value.trim();
  if (!name) return;
  await store.dispatch('kanbanLossReasons/update', { id: editingId.value, name });
  editingId.value = null;
};

const toggleActive = async reason => {
  await store.dispatch('kanbanLossReasons/update', { id: reason.id, active: !reason.active });
};

const deleteReason = async id => {
  if (!confirm('Excluir este motivo de perda?')) return;
  await store.dispatch('kanbanLossReasons/delete', id);
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <p class="text-xs text-n-slate-9 flex items-center gap-1.5">
      <i class="i-lucide-info" />
      Motivos usados ao mover um lead para o estágio <strong class="text-n-ruby-9">"Perdido"</strong>
    </p>

    <!-- Existing reasons -->
    <div v-if="reasons.length > 0" class="flex flex-col gap-1.5">
      <div
        v-for="reason in reasons"
        :key="reason.id"
        class="group flex items-center gap-3 px-3 py-2.5 rounded-xl border transition-all"
        :class="reason.active ? 'bg-n-surface-1 border-n-weak hover:border-n-ruby-9/30' : 'bg-n-alpha-1 border-n-weak/50 opacity-60'"
      >
        <i
          class="i-lucide-flag flex-shrink-0 text-sm"
          :class="reason.active ? 'text-n-ruby-9' : 'text-n-slate-9'"
        />

        <!-- Edit mode -->
        <template v-if="editingId === reason.id">
          <input
            v-model="editingName"
            class="flex-1 text-sm bg-n-surface-2 border border-n-weak rounded-lg px-2.5 py-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand/30 focus:border-n-brand"
            @keyup.enter="saveEdit"
            @keyup.escape="editingId = null"
          />
          <button class="text-n-brand hover:opacity-70 p-1" @click="saveEdit">
            <i class="i-lucide-check text-sm" />
          </button>
          <button class="text-n-slate-9 hover:text-n-slate-12 p-1" @click="editingId = null">
            <i class="i-lucide-x text-sm" />
          </button>
        </template>

        <!-- View mode -->
        <template v-else>
          <span class="flex-1 text-sm font-medium text-n-slate-12 truncate">{{ reason.name }}</span>

          <div class="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity flex-shrink-0">
            <button
              v-tooltip.top="reason.active ? 'Desativar' : 'Ativar'"
              class="p-1.5 rounded-lg text-n-slate-9 hover:text-n-slate-12 hover:bg-n-alpha-2 transition-colors"
              @click="toggleActive(reason)"
            >
              <i :class="reason.active ? 'i-lucide-eye-off' : 'i-lucide-eye'" class="text-sm" />
            </button>
            <button
              v-tooltip.top="'Editar'"
              class="p-1.5 rounded-lg text-n-slate-9 hover:text-n-slate-12 hover:bg-n-alpha-2 transition-colors"
              @click="startEdit(reason)"
            >
              <i class="i-lucide-pencil text-sm" />
            </button>
            <button
              v-tooltip.top="'Excluir'"
              class="p-1.5 rounded-lg text-n-slate-9 hover:text-n-ruby-9 hover:bg-n-ruby-9/10 transition-colors"
              @click="deleteReason(reason.id)"
            >
              <i class="i-lucide-trash-2 text-sm" />
            </button>
          </div>
        </template>
      </div>
    </div>

    <!-- Empty -->
    <div v-else class="flex flex-col items-center py-8 gap-3 text-center">
      <div class="w-10 h-10 rounded-xl bg-n-alpha-2 flex items-center justify-center">
        <i class="i-lucide-flag text-lg text-n-slate-9" />
      </div>
      <p class="text-sm text-n-slate-9">Nenhum motivo cadastrado ainda</p>
    </div>

    <!-- Add new -->
    <div class="flex items-center gap-2 pt-1 border-t border-n-weak">
      <input
        v-model="newName"
        type="text"
        placeholder="Novo motivo de perda…"
        class="flex-1 text-sm border border-n-weak rounded-lg px-3 py-2 bg-n-surface-1 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-brand/30 focus:border-n-brand"
        @keyup.enter="createReason"
      />
      <Button size="sm" :loading="isSaving" icon="i-lucide-plus" @click="createReason">
        Adicionar
      </Button>
    </div>
  </div>
</template>
