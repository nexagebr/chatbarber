<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAccount } from 'dashboard/composables/useAccount';
import Draggable from 'vuedraggable';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Avatar from 'next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import KanbanSettingsModal from './KanbanSettingsModal.vue';

const { t } = useI18n();
const store = useStore();
const router = useRouter();
const { accountId } = useAccount();

const isLoading = ref(false);
const showSettings = ref(false);
const isDragging = ref(false);

const kanbanStages = computed(() => store.getters['kanbanStages/getKanbanStages']);
const allContacts = computed(() => store.getters['contacts/getContacts']);

// Build stages with their contacts - make reactive to changes
const stages = computed(() => {
  const currentStages = kanbanStages.value || [];
  const currentContacts = allContacts.value || [];
  
  return currentStages.map(stage => ({
    ...stage,
    contacts: currentContacts.filter(
      contact => {
        const stageId = contact.additional_attributes?.kanban_stage_id;
        return stageId === stage.id || (stageId === null && stage.id === null);
      }
    )
  }));
});

const loadData = async () => {
  isLoading.value = true;
  try {
    // Load kanban stages first
    await store.dispatch('kanbanStages/get');
    
    // Load all contacts with pagination
    await store.dispatch('contacts/get', { page: 1 });
    
    // Load labels (for settings modal)
    await store.dispatch('labels/get');
  } catch (error) {
    console.error('Error loading kanban data:', error);
  } finally {
    isLoading.value = false;
  }
};

const onContactMove = async (evt, stageId) => {
  const { added, moved } = evt;
  
  if (!added && !moved) return;

  const contact = added?.element || moved?.element;
  if (!contact) return;
  
  isDragging.value = true;
  
  // Update contact stage
  try {
    const updatedAttributes = {
      ...contact.additional_attributes,
      kanban_stage_id: stageId,
    };
    
    await store.dispatch('contacts/update', {
      id: contact.id,
      additional_attributes: updatedAttributes,
    });
    
    // Force refresh contacts to ensure UI is synced
    await store.dispatch('contacts/get', { page: 1 });
  } catch (error) {
    console.error('Error updating contact stage:', error);
    // Reload to revert the UI change
    await loadData();
  } finally {
    isDragging.value = false;
  }
};

const handleContactClick = contact => {
  if (isDragging.value) return;
  
  // Use router navigation instead of window.location
  router.push({
    name: 'contacts_edit',
    params: {
      accountId: accountId.value,
      contactId: contact.id,
    },
  });
};

const totalContactsByStage = computed(() => {
  const totals = {};
  stages.value.forEach(stage => {
    totals[stage.id] = stage.contacts?.length || 0;
  });
  return totals;
});

// Watch for contact updates to refresh the view
watch(() => allContacts.value.length, (newVal, oldVal) => {
  if (newVal !== oldVal && !isDragging.value) {
    console.log('Contacts updated, refreshing stages');
  }
});

onMounted(() => {
  loadData();
});
</script>

<template>
  <div class="flex flex-col w-full h-full bg-n-surface-1">
    <!-- Header -->
    <div class="flex items-center justify-between px-6 py-4 border-b border-n-weak">
      <div>
        <h1 class="text-2xl font-semibold text-n-surface-on-text-default">
          {{ $t('CONTACTS_KANBAN.TITLE') }}
        </h1>
        <p class="text-sm text-n-surface-on-text-subtle">
          {{ $t('CONTACTS_KANBAN.SUBTITLE') }}
        </p>
      </div>
      <div class="flex gap-2">
        <Button
          variant="secondary"
          size="medium"
          icon="i-lucide-settings"
          @click="showSettings = true"
        >
          {{ $t('CONTACTS_KANBAN.SETTINGS_BTN') }}
        </Button>
        <Button
          variant="secondary"
          size="medium"
          icon="i-lucide-refresh-cw"
          @click="loadData"
        >
          {{ $t('CONTACTS_KANBAN.REFRESH') }}
        </Button>
      </div>
    </div>

    <!-- Kanban Board -->
    <div v-if="isLoading" class="flex flex-1 gap-4 p-6 overflow-x-auto">
      <!-- Skeleton Columns -->
      <div
        v-for="i in 5"
        :key="`skeleton-${i}`"
        class="flex flex-col flex-shrink-0 w-80 bg-n-surface-2 rounded-lg border border-n-weak animate-pulse"
      >
        <!-- Skeleton Header -->
        <div class="flex items-center justify-between p-4 border-b border-n-weak">
          <div class="flex items-center gap-2">
            <div class="w-3 h-3 rounded-full bg-n-alpha-3" />
            <div class="w-24 h-5 rounded bg-n-alpha-3" />
            <div class="w-8 h-5 rounded-full bg-n-alpha-2" />
          </div>
        </div>
        
        <!-- Skeleton Cards -->
        <div class="flex flex-col gap-2 p-3">
          <div
            v-for="j in Math.floor(Math.random() * 3) + 2"
            :key="`skeleton-card-${j}`"
            class="flex items-center gap-3 p-3 bg-n-surface-1 rounded-lg border border-n-weak"
          >
            <div class="w-10 h-10 rounded-full bg-n-alpha-3 flex-shrink-0" />
            <div class="flex-1 space-y-2">
              <div class="h-4 rounded bg-n-alpha-3" :style="{ width: `${60 + Math.random() * 30}%` }" />
              <div class="h-3 rounded bg-n-alpha-2" :style="{ width: `${40 + Math.random() * 40}%` }" />
            </div>
          </div>
        </div>
      </div>
    </div>

    <div v-else class="flex flex-1 gap-4 p-6 overflow-x-auto">
      <div
        v-for="stage in stages"
        :key="stage.id"
        class="flex flex-col flex-shrink-0 w-80 bg-n-surface-2 rounded-lg border border-n-weak"
      >
        <!-- Stage Header -->
        <div class="flex items-center justify-between p-4 border-b border-n-weak">
          <div class="flex items-center gap-2">
            <div :class="['w-3 h-3 rounded-full', stage.color]" />
            <h3 class="font-semibold text-n-surface-on-text-default">
              {{ stage.name }}
            </h3>
            <span
              class="px-2 py-0.5 text-xs font-medium rounded-full bg-n-alpha-2 text-n-surface-on-text-subtle"
            >
              {{ totalContactsByStage[stage.id] }}
            </span>
          </div>
        </div>

        <!-- Contacts List -->
        <Draggable
          v-model="stage.contacts"
          group="contacts"
          item-key="id"
          class="flex flex-col flex-1 gap-2 p-3 overflow-y-auto min-h-[200px]"
          ghost-class="ghost"
          drag-class="dragging"
          :animation="200"
          @change="evt => onContactMove(evt, stage.id)"
          @start="isDragging = true"
          @end="isDragging = false"
        >
          <template #item="{ element: contact }">
            <div
              class="flex items-center gap-3 p-3 bg-n-surface-1 rounded-lg border border-n-weak cursor-grab active:cursor-grabbing hover:border-n-default hover:shadow-sm transition-all"
              @click.stop="handleContactClick(contact)"
            >
              <Avatar
                :username="contact.name || contact.email"
                :src="contact.thumbnail"
                size="small"
              />
              <div class="flex-1 min-w-0">
                <p class="font-medium text-sm text-n-surface-on-text-default truncate">
                  {{ contact.name || $t('CONTACTS_KANBAN.UNNAMED') }}
                </p>
                <p class="text-xs text-n-surface-on-text-subtle truncate">
                  {{ contact.email || contact.phone_number || '-' }}
                </p>
              </div>
            </div>
          </template>
        </Draggable>
      </div>
    </div>
  </div>

  <!-- Settings Modal -->
  <KanbanSettingsModal
    :show="showSettings"
    @close="showSettings = false"
    @update="loadData"
  />
</template>

<style scoped>
.ghost {
  opacity: 0.4;
  background: var(--n-alpha-2);
  border: 2px dashed var(--n-weak);
}

.dragging {
  opacity: 0.8;
  transform: rotate(2deg);
  box-shadow: 0 4px 8px rgba(0, 0, 0, 0.15);
}

.cursor-grab {
  cursor: grab;
}

.cursor-grabbing {
  cursor: grabbing;
}
</style>
