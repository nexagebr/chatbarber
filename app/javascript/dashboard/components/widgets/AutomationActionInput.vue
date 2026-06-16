<script>
import AutomationActionTeamMessageInput from './AutomationActionTeamMessageInput.vue';
import AutomationActionFileInput from './AutomationFileInput.vue';
import WootMessageEditor from 'dashboard/components/widgets/WootWriter/Editor.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

export default {
  components: {
    AutomationActionTeamMessageInput,
    AutomationActionFileInput,
    WootMessageEditor,
    NextButton,
  },
  props: {
    modelValue: {
      type: Object,
      default: () => null,
    },
    actionTypes: {
      type: Array,
      default: () => [],
    },
    dropdownValues: {
      type: Array,
      default: () => [],
    },
    errorMessage: {
      type: String,
      default: '',
    },
    showActionInput: {
      type: Boolean,
      default: true,
    },
    initialFileName: {
      type: String,
      default: '',
    },
    isMacro: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['update:modelValue', 'input', 'removeAction', 'resetAction'],
  computed: {
    action_name: {
      get() {
        if (!this.modelValue) return null;
        return this.modelValue.action_name;
      },
      set(value) {
        const payload = this.modelValue || {};
        this.$emit('update:modelValue', { ...payload, action_name: value });
        this.$emit('input', { ...payload, action_name: value });
      },
    },
    action_params: {
      get() {
        if (!this.modelValue) return null;
        return this.modelValue.action_params;
      },
      set(value) {
        const payload = this.modelValue || {};
        this.$emit('update:modelValue', { ...payload, action_params: value });
        this.$emit('input', { ...payload, action_params: value });
      },
    },
    inputType() {
      return this.actionTypes.find(action => action.key === this.action_name)
        .inputType;
    },
    actionInputStyles() {
      return {
        'has-error': this.errorMessage,
        'is-a-macro': this.isMacro,
      };
    },
    castMessageVmodel: {
      get() {
        if (Array.isArray(this.action_params)) {
          return this.action_params[0];
        }
        return this.action_params;
      },
      set(value) {
        this.action_params = value;
      },
    },
    scheduledMessageContent: {
      get() {
        return Array.isArray(this.action_params) ? this.action_params[0] || '' : '';
      },
      set(value) {
        const delay = Array.isArray(this.action_params) ? (this.action_params[1] || '60') : '60';
        this.action_params = [value, delay];
      },
    },
    scheduledMessageDelay: {
      get() {
        return Array.isArray(this.action_params) ? (this.action_params[1] || '60') : '60';
      },
      set(value) {
        const content = Array.isArray(this.action_params) ? (this.action_params[0] || '') : '';
        this.action_params = [content, String(value)];
      },
    },
    scheduledMessagePresets() {
      return [
        { value: '15', label: this.$t('AUTOMATION.ACTION.SCHEDULED_PRESETS.MIN_15') },
        { value: '30', label: this.$t('AUTOMATION.ACTION.SCHEDULED_PRESETS.MIN_30') },
        { value: '60', label: this.$t('AUTOMATION.ACTION.SCHEDULED_PRESETS.HOUR_1') },
        { value: '240', label: this.$t('AUTOMATION.ACTION.SCHEDULED_PRESETS.HOUR_4') },
        { value: '1440', label: this.$t('AUTOMATION.ACTION.SCHEDULED_PRESETS.DAY_1') },
      ];
    },
  },
  methods: {
    removeAction() {
      this.$emit('removeAction');
    },
    resetAction() {
      this.$emit('resetAction');
    },
  },
};
</script>

<template>
  <div class="filter" :class="actionInputStyles">
    <div class="filter-inputs">
      <select
        v-model="action_name"
        class="action__question"
        :class="{ 'full-width': !showActionInput }"
        @change="resetAction()"
      >
        <option
          v-for="attribute in actionTypes"
          :key="attribute.key"
          :value="attribute.key"
        >
          {{ attribute.label }}
        </option>
      </select>
      <div v-if="showActionInput" class="filter__answer--wrap">
        <div v-if="inputType" class="w-full">
          <div
            v-if="inputType === 'search_select'"
            class="multiselect-wrap--small"
          >
            <multiselect
              v-model="action_params"
              track-by="id"
              label="name"
              :placeholder="$t('FORMS.MULTISELECT.SELECT')"
              selected-label
              :select-label="$t('FORMS.MULTISELECT.ENTER_TO_SELECT')"
              deselect-label=""
              :max-height="160"
              :options="dropdownValues"
              :allow-empty="false"
              :option-height="104"
            >
              <template #noOptions>
                {{ $t('FORMS.MULTISELECT.NO_OPTIONS') }}
              </template>
            </multiselect>
          </div>
          <div
            v-else-if="inputType === 'multi_select'"
            class="multiselect-wrap--small"
          >
            <multiselect
              v-model="action_params"
              track-by="id"
              label="name"
              :placeholder="$t('FORMS.MULTISELECT.SELECT')"
              multiple
              selected-label
              :select-label="$t('FORMS.MULTISELECT.ENTER_TO_SELECT')"
              deselect-label=""
              :max-height="160"
              :options="dropdownValues"
              :allow-empty="false"
              :option-height="104"
            >
              <template #noOptions>
                {{ $t('FORMS.MULTISELECT.NO_OPTIONS') }}
              </template>
            </multiselect>
          </div>
          <input
            v-else-if="inputType === 'email'"
            v-model="action_params"
            type="email"
            class="answer--text-input"
            :placeholder="$t('AUTOMATION.ACTION.EMAIL_INPUT_PLACEHOLDER')"
          />
          <input
            v-else-if="inputType === 'url'"
            v-model="action_params"
            type="url"
            class="answer--text-input"
            :placeholder="$t('AUTOMATION.ACTION.URL_INPUT_PLACEHOLDER')"
          />
          <AutomationActionFileInput
            v-if="inputType === 'attachment'"
            v-model="action_params"
            :initial-file-name="initialFileName"
          />
        </div>
      </div>
      <NextButton
        v-if="!isMacro"
        icon="i-lucide-x"
        slate
        ghost
        class="flex-shrink-0"
        @click="removeAction"
      />
    </div>
    <AutomationActionTeamMessageInput
      v-if="inputType === 'team_message'"
      v-model="action_params"
      :teams="dropdownValues"
    />
    <WootMessageEditor
      v-if="inputType === 'textarea'"
      v-model="castMessageVmodel"
      rows="4"
      enable-variables
      :placeholder="$t('AUTOMATION.ACTION.TEAM_MESSAGE_INPUT_PLACEHOLDER')"
      class="action-message"
    />
    <div v-if="inputType === 'scheduled_message'" class="mt-2 space-y-3">
      <WootMessageEditor
        v-model="scheduledMessageContent"
        rows="3"
        enable-variables
        :placeholder="$t('AUTOMATION.ACTION.TEAM_MESSAGE_INPUT_PLACEHOLDER')"
        class="action-message"
      />
      <div class="rounded-lg border border-n-weak bg-n-alpha-1 p-3 space-y-2">
        <p class="text-xs font-semibold text-n-slate-11 uppercase tracking-wide">
          {{ $t('AUTOMATION.ACTION.SCHEDULED_MESSAGE_DELAY_LABEL') }}
        </p>
        <div class="flex flex-wrap gap-1.5">
          <button
            v-for="preset in scheduledMessagePresets"
            :key="preset.value"
            type="button"
            class="px-2.5 py-1 rounded-md text-xs font-medium border transition-all"
            :class="String(scheduledMessageDelay) === String(preset.value)
              ? 'bg-n-brand/10 text-n-brand border-n-brand/30'
              : 'bg-n-alpha-1 text-n-slate-10 border-n-weak hover:text-n-slate-12 hover:border-n-slate-7'"
            @click="scheduledMessageDelay = String(preset.value)"
          >
            {{ preset.label }}
          </button>
        </div>
        <div class="flex items-center gap-2 pt-1">
          <span class="text-xs text-n-slate-10 flex-shrink-0">{{ $t('AUTOMATION.ACTION.SCHEDULED_MESSAGE_CUSTOM') }}</span>
          <input
            v-model="scheduledMessageDelay"
            type="number"
            min="1"
            max="43200"
            class="w-20 px-2 py-1 text-sm border border-n-weak rounded bg-n-surface-1 text-n-slate-12 focus:outline-none focus:ring-1 focus:ring-n-brand"
          />
          <span class="text-xs text-n-slate-10">min</span>
          <span
            v-if="scheduledMessageDelay && Number(scheduledMessageDelay) >= 60"
            class="text-xs text-n-slate-9"
          >
            ({{ (Number(scheduledMessageDelay) / 60).toFixed(Number(scheduledMessageDelay) % 60 === 0 ? 0 : 1) }}h)
          </span>
        </div>
      </div>
    </div>
    <p v-if="errorMessage" class="filter-error">
      {{ errorMessage }}
    </p>
  </div>
</template>

<style lang="scss" scoped>
.filter {
  @apply bg-n-background p-2 border border-solid border-n-strong dark:border-n-strong rounded-lg mb-2;

  &.is-a-macro {
    @apply mb-0 bg-n-background dark:bg-n-solid-1 p-0 border-0 rounded-none;
  }
}

.no-margin-bottom {
  @apply mb-0;
}

.filter.has-error {
  @apply bg-n-ruby-8/20 border-n-ruby-5 dark:border-n-ruby-5;

  &.is-a-macro {
    @apply bg-transparent;
  }
}

.filter-inputs {
  @apply flex gap-1;
}

.filter-error {
  @apply text-n-ruby-9 dark:text-n-ruby-9 block my-1 mx-0;
}

.action__question,
.filter__operator {
  @apply mb-0 mr-1;
}

.action__question {
  @apply max-w-[50%];
}

.action__question.full-width {
  @apply max-w-full;
}

.filter__answer--wrap {
  @apply max-w-[50%] flex-grow mr-1 flex w-full items-center justify-start;

  input {
    @apply mb-0;
  }
}
.filter__answer {
  &.answer--text-input {
    @apply mb-0;
  }
}

.filter__join-operator-wrap {
  @apply relative z-20 m-0;
}

.filter__join-operator {
  @apply flex items-center justify-center relative my-2.5 mx-0;

  .operator__line {
    @apply absolute w-full border-b border-solid border-n-weak;
  }

  .operator__select {
    margin-bottom: 0 !important;
    @apply relative w-auto;
  }
}

.multiselect {
  @apply mb-0;
}
.action-message {
  @apply mt-2 mx-0 mb-0;
}
// Prosemirror does not have a native way of hiding the menu bar, hence
::v-deep .ProseMirror-menubar {
  @apply hidden;
}
</style>
