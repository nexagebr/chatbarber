<script setup>
import { ref, computed, watch } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import Draggable from 'vuedraggable';

import Modal from 'dashboard/components/Modal.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';

const props = defineProps({
  show: { type: Boolean, default: false },
});

const emit = defineEmits(['close', 'update']);

const { t } = useI18n();
const store = useStore();

const localStages = ref([]);
const editingStage = ref(null);
const showEditModal = ref(false);
const isLoadingStages = ref(false);

const kanbanStages = computed(() => store.getters['kanbanStages/getKanbanStages']);
const labels = computed(() => store.getters['labels/getLabels']);
const uiFlags = computed(() => store.getters['kanbanStages/getUIFlags']);

const availableColors = [
  { value: 'bg-blue-500', label: t('CONTACTS_KANBAN.COLORS.BLUE') },
  { value: 'bg-green-500', label: t('CONTACTS_KANBAN.COLORS.GREEN') },
  { value: 'bg-yellow-500', label: t('CONTACTS_KANBAN.COLORS.YELLOW') },
  { value: 'bg-red-500', label: t('CONTACTS_KANBAN.COLORS.RED') },
  { value: 'bg-purple-500', label: t('CONTACTS_KANBAN.COLORS.PURPLE') },
  { value: 'bg-pink-500', label: t('CONTACTS_KANBAN.COLORS.PINK') },
  { value: 'bg-indigo-500', label: t('CONTACTS_KANBAN.COLORS.INDIGO') },
  { value: 'bg-gray-500', label: t('CONTACTS_KANBAN.COLORS.GRAY') },
];

const loadStages = async () => {
  isLoadingStages.value = true;
  try {
    await store.dispatch('kanbanStages/get');
    localStages.value = kanbanStages.value ? [...kanbanStages.value] : [];
  } catch (error) {
    console.error('Error loading stages:', error);
    useAlert(t('CONTACTS_KANBAN.SETTINGS.LOAD_ERROR') || 'Erro ao carregar estágios');
    localStages.value = [];
  } finally {
    isLoadingStages.value = false;
  }
};

watch(() => props.show, (newVal) => {
  if (newVal) {
    loadStages();
  }
});

const addNewStage = () => {
  editingStage.value = {
    id: null,
    name: '',
    color: 'bg-blue-500',
    label_id: null,
    position: localStages.value.length,
  };
  showEditModal.value = true;
};

const editStage = stage => {
  editingStage.value = { ...stage };
  showEditModal.value = true;
};

const saveStage = async () => {
  if (!editingStage.value.name || !editingStage.value.name.trim()) {
    useAlert(t('CONTACTS_KANBAN.SETTINGS.NAME_REQUIRED') || 'Nome é obrigatório');
    return;
  }

  try {
    if (editingStage.value.id) {
      // Update existing
      await store.dispatch('kanbanStages/update', editingStage.value);
      useAlert(t('CONTACTS_KANBAN.SETTINGS.STAGE_UPDATED') || 'Estágio atualizado');
    } else {
      // Create new
      await store.dispatch('kanbanStages/create', editingStage.value);
      useAlert(t('CONTACTS_KANBAN.SETTINGS.STAGE_CREATED') || 'Estágio criado');
    }
    await loadStages();
    showEditModal.value = false;
    editingStage.value = null;
    emit('update');
  } catch (error) {
    console.error('Error saving stage:', error);
    useAlert(t('CONTACTS_KANBAN.SETTINGS.STAGE_ERROR') || 'Erro ao salvar estágio');
  }
};

const deleteStage = async id => {
  if (!confirm(t('CONTACTS_KANBAN.SETTINGS.DELETE_CONFIRM') || 'Tem certeza que deseja excluir este estágio?')) return;
  
  try {
    await store.dispatch('kanbanStages/delete', id);
    await loadStages();
    useAlert(t('CONTACTS_KANBAN.SETTINGS.STAGE_DELETED') || 'Estágio excluído');
    emit('update');
  } catch (error) {
    console.error('Error deleting stage:', error);
    useAlert(t('CONTACTS_KANBAN.SETTINGS.DELETE_ERROR') || 'Erro ao excluir estágio');
  }
};

const onDragEnd = async () => {
  try {
    const reorderedStages = localStages.value.map((stage, index) => ({
      id: stage.id,
      position: index,
    }));
    await store.dispatch('kanbanStages/reorder', reorderedStages);
    useAlert(t('CONTACTS_KANBAN.SETTINGS.ORDER_SAVED') || 'Ordem salva');
    emit('update');
  } catch (error) {
    console.error('Error reordering stages:', error);
    useAlert(t('CONTACTS_KANBAN.SETTINGS.ORDER_ERROR') || 'Erro ao reordenar');
    await loadStages();
  }
};

const close = () => {
  showEditModal.value = false;
  editingStage.value = null;
  emit('close');
};
</script>

<template>
  <Modal :show="show" :on-close="close" size="large">
    <template #header>
      <h2 class="text-xl font-semibold text-n-slate-12">
        {{ $t('CONTACTS_KANBAN.SETTINGS.TITLE') }}
      </h2>
      <p class="mt-1 text-sm text-n-slate-11">
        {{ $t('CONTACTS_KANBAN.SETTINGS.DESCRIPTION') }}
      </p>
    </template>

    <div class="space-y-4">
      <!-- Stages List -->
      <div class="space-y-2">
        <div class="flex items-center justify-between">
          <h3 class="text-sm font-medium text-n-slate-12">
            {{ $t('CONTACTS_KANBAN.SETTINGS.STAGES_LIST') }}
          </h3>
          <Button
            size="sm"
            icon="i-lucide-plus"
            @click="addNewStage"
          >
            {{ $t('CONTACTS_KANBAN.SETTINGS.ADD_STAGE') }}
          </Button>
        </div>

        <div v-if="isLoadingStages" class="flex items-center justify-center py-8">
          <div class="flex items-center gap-2 text-n-slate-11">
            <i class="i-lucide-loader-2 animate-spin text-lg" />
            <span class="text-sm">{{ $t('CONTACTS_KANBAN.SETTINGS.LOADING') || 'Carregando...' }}</span>
          </div>
        </div>

        <div v-else-if="!localStages.length" class="flex flex-col items-center justify-center py-8 text-center">
          <i class="i-lucide-layout-list text-4xl text-n-slate-9 mb-2" />
          <p class="text-sm text-n-slate-11 mb-4">
            {{ $t('CONTACTS_KANBAN.SETTINGS.NO_STAGES') || 'Nenhum estágio criado ainda' }}
          </p>
          <Button
            size="sm"
            icon="i-lucide-plus"
            @click="addNewStage"
          >
            {{ $t('CONTACTS_KANBAN.SETTINGS.ADD_FIRST_STAGE') || 'Criar primeiro estágio' }}
          </Button>
        </div>

        <Draggable
          v-else
          v-model="localStages"
          item-key="id"
          class="space-y-2"
          handle=".drag-handle"
          @end="onDragEnd"
        >
          <template #item="{ element: stage }">
            <div
              class="flex items-center gap-3 p-3 bg-n-surface-2 rounded-lg border border-n-weak"
            >
              <div class="drag-handle cursor-move text-n-slate-11">
                <i class="i-lucide-grip-vertical text-lg" />
              </div>
              
              <div :class="['w-3 h-3 rounded-full', stage.color]" />
              
              <div class="flex-1">
                <p class="font-medium text-sm text-n-slate-12">
                  {{ stage.name }}
                </p>
                <p v-if="stage.label" class="text-xs text-n-slate-11">
                  Tag: {{ stage.label.title }}
                </p>
                <p v-else class="text-xs text-n-slate-11">
                  {{ $t('CONTACTS_KANBAN.SETTINGS.NO_TAG') }}
                </p>
              </div>

              <div class="flex gap-2">
                <Button
                  ghost
                  slate
                  size="sm"
                  icon="i-lucide-pencil"
                  @click="editStage(stage)"
                />
                <Button
                  ghost
                  slate
                  size="sm"
                  icon="i-lucide-trash-2"
                  @click="deleteStage(stage.id)"
                />
              </div>
            </div>
          </template>
        </Draggable>
      </div>
    </div>

    <template #footer>
      <div class="flex justify-end gap-2">
        <Button
          variant="secondary"
          @click="close"
        >
          {{ $t('CONTACTS_KANBAN.SETTINGS.CLOSE') }}
        </Button>
      </div>
    </template>
  </Modal>

  <!-- Edit/Create Stage Modal -->
  <Modal :show="showEditModal" :on-close="() => showEditModal = false">
    <template #header>
      <h2 class="text-lg font-semibold text-n-slate-12">
        {{ editingStage?.id ? $t('CONTACTS_KANBAN.SETTINGS.EDIT_STAGE') : $t('CONTACTS_KANBAN.SETTINGS.NEW_STAGE') }}
      </h2>
    </template>

    <div v-if="editingStage" class="space-y-4">
      <Input
        v-model="editingStage.name"
        :label="$t('CONTACTS_KANBAN.SETTINGS.STAGE_NAME')"
        :placeholder="$t('CONTACTS_KANBAN.SETTINGS.STAGE_NAME_PLACEHOLDER')"
      />

      <div>
        <label class="block text-sm font-medium text-n-slate-12 mb-2">
          {{ $t('CONTACTS_KANBAN.SETTINGS.STAGE_COLOR') }}
        </label>
        <div class="flex flex-wrap gap-2">
          <button
            v-for="color in availableColors"
            :key="color.value"
            type="button"
            :class="[
              'w-8 h-8 rounded-full border-2 transition-all',
              color.value,
              editingStage.color === color.value
                ? 'border-n-slate-12 scale-110'
                : 'border-transparent hover:border-n-slate-11'
            ]"
            @click="editingStage.color = color.value"
          />
        </div>
      </div>

      <div>
        <label class="block text-sm font-medium text-n-slate-12 mb-2">
          {{ $t('CONTACTS_KANBAN.SETTINGS.LINKED_TAG') }}
        </label>
        <select
          v-model="editingStage.label_id"
          class="block w-full px-3 py-2 text-sm border border-n-weak rounded-lg bg-n-surface-2 text-n-slate-12 focus:outline-none focus:ring-2 focus:ring-n-slate-8"
        >
          <option :value="null">{{ $t('CONTACTS_KANBAN.SETTINGS.SELECT_TAG') }}</option>
          <option v-for="label in labels" :key="label.id" :value="label.id">
            {{ label.title }}
          </option>
        </select>
        <p class="mt-1 text-xs text-n-slate-11">
          {{ $t('CONTACTS_KANBAN.SETTINGS.TAG_DESCRIPTION') }}
        </p>
      </div>
    </div>

    <template #footer>
      <div class="flex justify-end gap-2">
        <Button
          variant="secondary"
          @click="showEditModal = false"
        >
          {{ $t('CONTACTS_KANBAN.SETTINGS.CANCEL') }}
        </Button>
        <Button
          :loading="uiFlags.isCreating || uiFlags.isUpdating"
          @click="saveStage"
        >
          {{ $t('CONTACTS_KANBAN.SETTINGS.SAVE') }}
        </Button>
      </div>
    </template>
  </Modal>
</template>
