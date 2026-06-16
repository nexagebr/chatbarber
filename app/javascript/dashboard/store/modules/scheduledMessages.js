import types from '../mutation-types';
import ScheduledMessagesAPI from '../../api/scheduledMessages';

const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isCancelling: false,
  },
};

export const getters = {
  getScheduledMessages: $state => $state.records,
  getUIFlags: $state => $state.uiFlags,
};

export const actions = {
  async list({ commit }, conversationId) {
    commit(types.SET_SCHEDULED_MESSAGES_UI_FLAG, { isFetching: true });
    try {
      const { data } = await ScheduledMessagesAPI.list(conversationId);
      commit(types.SET_SCHEDULED_MESSAGES, data);
    } finally {
      commit(types.SET_SCHEDULED_MESSAGES_UI_FLAG, { isFetching: false });
    }
  },

  async create({ commit }, { conversationId, content, scheduledAt, isPrivate = false, signedIds = [] }) {
    commit(types.SET_SCHEDULED_MESSAGES_UI_FLAG, { isCreating: true });
    try {
      const { data } = await ScheduledMessagesAPI.create(conversationId, {
        content,
        scheduled_at: scheduledAt,
        is_private: isPrivate,
        signed_ids: signedIds,
      });
      commit(types.ADD_SCHEDULED_MESSAGE, data);
      return data;
    } finally {
      commit(types.SET_SCHEDULED_MESSAGES_UI_FLAG, { isCreating: false });
    }
  },

  async cancel({ commit }, { conversationId, id }) {
    commit(types.SET_SCHEDULED_MESSAGES_UI_FLAG, { isCancelling: true });
    try {
      await ScheduledMessagesAPI.cancel(conversationId, id);
      commit(types.REMOVE_SCHEDULED_MESSAGE, id);
    } finally {
      commit(types.SET_SCHEDULED_MESSAGES_UI_FLAG, { isCancelling: false });
    }
  },
};

export const mutations = {
  [types.SET_SCHEDULED_MESSAGES_UI_FLAG]($state, data) {
    $state.uiFlags = { ...$state.uiFlags, ...data };
  },
  [types.SET_SCHEDULED_MESSAGES]($state, data) {
    $state.records = data;
  },
  [types.ADD_SCHEDULED_MESSAGE]($state, data) {
    $state.records = [...$state.records, data].sort(
      (a, b) => new Date(a.scheduled_at) - new Date(b.scheduled_at)
    );
  },
  [types.REMOVE_SCHEDULED_MESSAGE]($state, id) {
    $state.records = $state.records.filter(r => r.id !== id);
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
