import API from '../../api/products';

const state = {
  list: [],
  uiFlags: {
    isFetching: false,
    isSaving: false,
  },
};

const getters = {
  getList: s => s.list,
  getUIFlags: s => s.uiFlags,
};

const actions = {
  async fetchList({ commit }, search) {
    commit('SET_UI', { isFetching: true });
    try {
      const { data } = await API.list(search);
      commit('SET_LIST', data);
    } finally {
      commit('SET_UI', { isFetching: false });
    }
  },

  async createProduct({ commit }, payload) {
    commit('SET_UI', { isSaving: true });
    try {
      const { data } = await API.create(payload);
      commit('ADD_TO_LIST', data);
      return data;
    } finally {
      commit('SET_UI', { isSaving: false });
    }
  },

  async updateProduct({ commit }, { id, ...payload }) {
    commit('SET_UI', { isSaving: true });
    try {
      const { data } = await API.update(id, payload);
      commit('UPDATE_IN_LIST', data);
      return data;
    } finally {
      commit('SET_UI', { isSaving: false });
    }
  },

  async deleteProduct({ commit }, id) {
    await API.del(id);
    commit('REMOVE_FROM_LIST', id);
  },
};

const mutations = {
  SET_UI(s, flags) {
    s.uiFlags = { ...s.uiFlags, ...flags };
  },
  SET_LIST(s, data) {
    s.list = data;
  },
  ADD_TO_LIST(s, item) {
    s.list.push(item);
  },
  UPDATE_IN_LIST(s, item) {
    const idx = s.list.findIndex(r => r.id === item.id);
    if (idx >= 0) s.list.splice(idx, 1, item);
  },
  REMOVE_FROM_LIST(s, id) {
    s.list = s.list.filter(r => r.id !== id);
  },
};

export default { namespaced: true, state, getters, actions, mutations };
