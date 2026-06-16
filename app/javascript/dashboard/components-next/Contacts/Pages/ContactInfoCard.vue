<script setup>
import { computed } from 'vue';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import ContactLabels from 'dashboard/components-next/Contacts/ContactLabels/ContactLabels.vue';

const props = defineProps({
  contact: { type: Object, required: true },
});

const additional = computed(() => props.contact?.additional_attributes || {});

const rows = computed(() => [
  { icon: 'i-lucide-mail',       label: 'Email',       value: props.contact?.email },
  { icon: 'i-lucide-phone',      label: 'Telefone',    value: props.contact?.phone_number },
  { icon: 'i-lucide-fingerprint',label: 'Identificador', value: props.contact?.identifier },
  { icon: 'i-lucide-building-2', label: 'Empresa',     value: additional.value.company_name },
  { icon: 'i-lucide-map-pin',    label: 'Cidade',      value: additional.value.city },
  { icon: 'i-lucide-globe',      label: 'País',        value: additional.value.country },
  { icon: 'i-lucide-info',       label: 'Descrição',   value: additional.value.description },
].filter(r => r.value));
</script>

<template>
  <div class="flex flex-col gap-4">
    <!-- Avatar + name -->
    <div class="flex flex-col items-center gap-3 pb-4 border-b border-n-weak">
      <Avatar
        :src="contact.thumbnail"
        :name="contact.name"
        :size="64"
        rounded-full
      />
      <div class="text-center min-w-0 w-full">
        <h2 class="text-base font-semibold text-n-slate-12 break-words leading-snug">
          {{ contact.name }}
        </h2>
        <p v-if="additional.description" class="mt-0.5 text-xs text-n-slate-9 line-clamp-2">
          {{ additional.description }}
        </p>
      </div>
      <ContactLabels :contact-id="contact.id" class="justify-center" />
    </div>

    <!-- Info rows -->
    <div v-if="rows.length" class="flex flex-col">
      <div
        v-for="row in rows"
        :key="row.label"
        class="flex items-start gap-3 py-2.5 border-b border-n-weak last:border-0"
      >
        <span :class="[row.icon, 'text-sm text-n-slate-8 flex-shrink-0 mt-0.5']" />
        <div class="flex flex-col min-w-0 flex-1">
          <span class="text-[11px] font-medium text-n-slate-8 leading-none mb-0.5">
            {{ row.label }}
          </span>
          <span class="text-sm text-n-slate-12 break-words leading-snug">
            {{ row.value }}
          </span>
        </div>
      </div>
    </div>
  </div>
</template>
