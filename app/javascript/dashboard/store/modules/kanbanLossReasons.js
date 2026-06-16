import types from '../mutation-types';
import KanbanLossReasonsAPI from '../../api/kanbanLossReasons';

export const state = {
  records: [],
};

export const getters = {
  getLossReasons: $state => $state.records,
  getActiveLossReasons: $state => $state.records.filter(r => r.active),
};

export const actions = {
  async get({ commit }) {
    try {
      const { data } = await KanbanLossReasonsAPI.list();
      commit(types.SET_KANBAN_LOSS_REASONS, data);
    } catch { /* ignore */ }
  },

  async create({ commit }, reason) {
    const { data } = await KanbanLossReasonsAPI.create(reason);
    commit(types.ADD_KANBAN_LOSS_REASON, data);
    return data;
  },

  async update({ commit }, { id, ...reason }) {
    const { data } = await KanbanLossReasonsAPI.update(id, reason);
    commit(types.UPDATE_KANBAN_LOSS_REASON, data);
    return data;
  },

  async delete({ commit }, id) {
    await KanbanLossReasonsAPI.delete(id);
    commit(types.REMOVE_KANBAN_LOSS_REASON, id);
  },
};

export const mutations = {
  [types.SET_KANBAN_LOSS_REASONS]($state, data) {
    $state.records = data;
  },
  [types.ADD_KANBAN_LOSS_REASON]($state, reason) {
    $state.records.push(reason);
  },
  [types.UPDATE_KANBAN_LOSS_REASON]($state, reason) {
    const idx = $state.records.findIndex(r => r.id === reason.id);
    if (idx >= 0) $state.records.splice(idx, 1, reason);
  },
  [types.REMOVE_KANBAN_LOSS_REASON]($state, id) {
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
