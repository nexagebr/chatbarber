<script setup>
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SectionLayout from './components/SectionLayout.vue';
import AppearanceSettings from './components/AppearanceSettings.vue';
</script>

<template>
  <div class="flex flex-col gap-3 p-6 overflow-y-auto h-full">
    <BaseSettingsHeader
      :title="$t('APPEARANCE_SETTINGS.TITLE')"
      :description="$t('APPEARANCE_SETTINGS.DESCRIPTION')"
      :link-text="''"
      :back-button-label="$t('GENERAL_SETTINGS.BACK')"
    />
    <SectionLayout
      :title="$t('APPEARANCE_SETTINGS.BRAND.TITLE')"
      :description="$t('APPEARANCE_SETTINGS.BRAND.DESCRIPTION')"
    >
      <AppearanceSettings />
    </SectionLayout>
  </div>
</template>
