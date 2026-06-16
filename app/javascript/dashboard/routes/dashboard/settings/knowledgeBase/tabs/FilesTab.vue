<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import CardLayout from 'dashboard/components-next/CardLayout.vue';

const props = defineProps({
  kbId: { type: [String, Number], required: true },
});

const store = useStore();
const files = computed(() => store.getters['knowledgeBases/getFiles']);
const uiFlags = computed(() => store.getters['knowledgeBases/getUIFlags']);

onMounted(() => {
  store.dispatch('knowledgeBases/fetchFiles', props.kbId);
});

// ── file input ────────────────────────────────────────────────────────────────
const fileInput = ref(null);
const isDragging = ref(false);

const openPicker = () => {
  fileInput.value?.click();
};

const formatSize = bytes => {
  if (!bytes || bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return `${parseFloat((bytes / Math.pow(k, i)).toFixed(1))} ${sizes[i]}`;
};

const getFileIcon = contentType => {
  if (!contentType) return 'i-lucide-file';
  if (contentType.startsWith('image/')) return 'i-lucide-image';
  if (contentType.includes('pdf')) return 'i-lucide-file-text';
  if (contentType.includes('word') || contentType.includes('document'))
    return 'i-lucide-file-text';
  if (
    contentType.includes('sheet') ||
    contentType.includes('excel') ||
    contentType.includes('csv')
  )
    return 'i-lucide-file-spreadsheet';
  if (contentType.includes('zip') || contentType.includes('archive'))
    return 'i-lucide-file-archive';
  return 'i-lucide-file';
};

const handleFiles = async fileList => {
  for (const file of Array.from(fileList)) {
    try {
      await store.dispatch('knowledgeBases/createFile', {
        kbId: props.kbId,
        original_filename: file.name,
        file_size: file.size,
        content_type: file.type || '',
        status: 'pending',
      });
    } catch {
      useAlert(`Erro ao adicionar arquivo: ${file.name}`);
    }
  }
  useAlert(`${fileList.length} arquivo(s) adicionado(s).`);
};

const onFileChange = e => {
  if (e.target.files.length) {
    handleFiles(e.target.files);
    e.target.value = '';
  }
};

const onDrop = e => {
  isDragging.value = false;
  e.preventDefault();
  if (e.dataTransfer.files.length) {
    handleFiles(e.dataTransfer.files);
  }
};

const onDragOver = e => {
  e.preventDefault();
  isDragging.value = true;
};

const onDragLeave = () => {
  isDragging.value = false;
};

// ── delete ────────────────────────────────────────────────────────────────────
const deleteTarget = ref(null);

const openDelete = file => {
  deleteTarget.value = file;
};

const cancelDelete = () => {
  deleteTarget.value = null;
};

const confirmDelete = async () => {
  try {
    await store.dispatch('knowledgeBases/deleteFile', {
      kbId: props.kbId,
      id: deleteTarget.value.id,
    });
    useAlert('Arquivo removido.');
  } catch {
    useAlert('Erro ao remover arquivo.');
  }
  cancelDelete();
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <!-- Upload area -->
    <div
      class="border-2 border-dashed rounded-xl p-8 flex flex-col items-center justify-center gap-3 cursor-pointer transition-colors"
      :class="
        isDragging
          ? 'border-n-brand bg-n-brand/5'
          : 'border-n-weak hover:border-n-brand/50 hover:bg-n-alpha-1'
      "
      @click="openPicker"
      @drop="onDrop"
      @dragover="onDragOver"
      @dragleave="onDragLeave"
    >
      <div
        class="w-12 h-12 rounded-xl bg-n-alpha-black2 flex items-center justify-center"
      >
        <span class="i-lucide-upload-cloud text-2xl text-n-slate-8" />
      </div>
      <div class="text-center">
        <p class="text-sm font-medium text-n-slate-11">
          Arraste arquivos aqui ou clique para selecionar
        </p>
        <p class="text-xs text-n-slate-9 mt-0.5">
          PDF, Word, Excel, imagens e mais
        </p>
      </div>
      <input
        ref="fileInput"
        type="file"
        multiple
        class="hidden"
        @change="onFileChange"
      />
    </div>

    <!-- Info note -->
    <div
      class="flex items-center gap-2 px-3 py-2 rounded-lg bg-n-alpha-black2 border border-n-weak"
    >
      <span class="i-lucide-info text-n-slate-8 text-sm flex-shrink-0" />
      <p class="text-xs text-n-slate-9">
        Os arquivos são armazenados como metadados. O processamento de conteúdo
        será adicionado em breve.
      </p>
    </div>

    <!-- Loading -->
    <div
      v-if="uiFlags.isFetching"
      class="flex items-center justify-center py-8 text-n-slate-11"
    >
      <Spinner />
    </div>

    <!-- Empty state -->
    <div
      v-else-if="files.length === 0"
      class="flex flex-col items-center justify-center py-10 gap-3"
    >
      <div
        class="w-12 h-12 rounded-2xl bg-n-alpha-black2 flex items-center justify-center"
      >
        <span class="i-lucide-files text-2xl text-n-slate-8" />
      </div>
      <p class="text-sm text-n-slate-9">Nenhum arquivo adicionado ainda</p>
    </div>

    <!-- File list -->
    <div v-else class="flex flex-col gap-4">
      <CardLayout
        v-for="file in files"
        :key="file.id"
        layout="row"
      >
        <div class="flex items-center gap-3 flex-1 min-w-0">
          <div
            class="w-9 h-9 rounded-lg bg-n-alpha-black2 flex items-center justify-center flex-shrink-0"
          >
            <span
              :class="[getFileIcon(file.content_type), 'text-n-slate-8 text-base']"
            />
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-base text-n-slate-12 truncate">
              {{ file.original_filename }}
            </p>
            <p class="text-sm text-n-slate-11">
              {{ formatSize(file.file_size) }}
            </p>
          </div>
        </div>
        <div class="flex items-center gap-3 shrink-0">
          <span
            class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium"
            :class="
              file.status === 'indexed'
                ? 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400'
                : 'bg-n-alpha-black2 text-n-slate-9'
            "
          >
            <span
              :class="
                file.status === 'indexed'
                  ? 'i-lucide-check-circle text-green-600 dark:text-green-400'
                  : 'i-lucide-clock text-n-slate-8'
              "
              class="text-xs"
            />
            {{ file.status === 'indexed' ? 'Indexado' : 'Pendente' }}
          </span>
          <Button
            icon="i-lucide-trash-2"
            color="ruby"
            size="xs"
            class="rounded-md"
            @click="openDelete(file)"
          />
        </div>
      </CardLayout>
    </div>

    <!-- DELETE CONFIRMATION -->
    <Teleport to="body">
      <div
        v-if="deleteTarget"
        class="fixed inset-0 z-50 flex items-center justify-center p-4"
      >
        <div class="absolute inset-0 bg-black/50" @click="cancelDelete" />
        <div
          class="relative w-full max-w-sm bg-n-solid-1 rounded-2xl shadow-2xl border border-n-weak p-6 flex flex-col gap-4"
        >
          <div class="flex items-start gap-3">
            <div
              class="w-10 h-10 rounded-full bg-ruby-3 flex items-center justify-center flex-shrink-0"
            >
              <span class="i-lucide-trash-2 text-ruby-11 text-lg" />
            </div>
            <div>
              <h3 class="text-base font-semibold text-n-slate-12">
                Remover arquivo
              </h3>
              <p class="text-sm text-n-slate-10 mt-1 truncate">
                {{ deleteTarget?.original_filename }}
              </p>
            </div>
          </div>
          <div class="flex items-center justify-end gap-3">
            <button
              class="h-9 px-4 rounded-lg border border-n-weak text-sm font-semibold text-n-slate-11 hover:bg-n-alpha-2 transition-colors"
              @click="cancelDelete"
            >
              Cancelar
            </button>
            <button
              class="h-9 px-4 rounded-lg bg-ruby-9 text-white text-sm font-semibold hover:bg-ruby-10 transition-colors"
              @click="confirmDelete"
            >
              Remover
            </button>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>
