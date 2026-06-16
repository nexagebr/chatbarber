import API from '../../api/inboxKnowledgeItems';

const state = {
  records: [],
  uiFlags: { isFetching: false, isSaving: false },
};

const getters = {
  allItems: s => s.records,
  uiFlags:  s => s.uiFlags,
};

const actions = {
  async fetch({ commit }, params = {}) {
    commit('SET_UI', { isFetching: true });
    try {
      const { data } = await API.getAll(params);
      commit('SET_RECORDS', data);
    } finally {
      commit('SET_UI', { isFetching: false });
    }
  },
  async create({ commit }, payload) {
    commit('SET_UI', { isSaving: true });
    try {
      const { data } = await API.create({ inbox_knowledge_item: payload });
      commit('ADD_RECORD', data);
      return data;
    } finally {
      commit('SET_UI', { isSaving: false });
    }
  },
  async update({ commit }, { id, ...payload }) {
    commit('SET_UI', { isSaving: true });
    try {
      const { data } = await API.update(id, { inbox_knowledge_item: payload });
      commit('UPDATE_RECORD', data);
      return data;
    } finally {
      commit('SET_UI', { isSaving: false });
    }
  },
  async destroy({ commit }, id) {
    await API.delete(id);
    commit('REMOVE_RECORD', id);
  },
};

const mutations = {
  SET_UI(s, flags) { s.uiFlags = { ...s.uiFlags, ...flags }; },
  SET_RECORDS(s, data) { s.records = data; },
  ADD_RECORD(s, item) { s.records.push(item); },
  UPDATE_RECORD(s, item) {
    const idx = s.records.findIndex(r => r.id === item.id);
    if (idx >= 0) s.records.splice(idx, 1, item);
  },
  REMOVE_RECORD(s, id) { s.records = s.records.filter(r => r.id !== id); },
};

export default { namespaced: true, state, getters, actions, mutations };
