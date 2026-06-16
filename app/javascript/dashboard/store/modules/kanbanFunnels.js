import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import KanbanFunnelsAPI from '../../api/kanbanFunnels';

export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
    isDeleting: false,
  },
};

export const getters = {
  getKanbanFunnels(_state) {
    return _state.records;
  },
  getKanbanFunnelById: _state => id => {
    return _state.records.find(r => r.id === Number(id));
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};

export const actions = {
  get: async function getKanbanFunnels({ commit }) {
    commit(types.SET_KANBAN_FUNNEL_UI_FLAG, { isFetching: true });
    try {
      const response = await KanbanFunnelsAPI.get();
      commit(types.SET_KANBAN_FUNNELS, response.data);
    } catch (error) {
      // ignore
    } finally {
      commit(types.SET_KANBAN_FUNNEL_UI_FLAG, { isFetching: false });
    }
  },

  create: async function createKanbanFunnel({ commit }, data) {
    commit(types.SET_KANBAN_FUNNEL_UI_FLAG, { isCreating: true });
    try {
      const response = await KanbanFunnelsAPI.create(data);
      commit(types.ADD_KANBAN_FUNNEL, response.data);
      return response.data;
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_KANBAN_FUNNEL_UI_FLAG, { isCreating: false });
    }
  },

  update: async function updateKanbanFunnel({ commit }, { id, ...data }) {
    commit(types.SET_KANBAN_FUNNEL_UI_FLAG, { isUpdating: true });
    try {
      const response = await KanbanFunnelsAPI.update(id, data);
      commit(types.EDIT_KANBAN_FUNNEL, response.data);
      return response.data;
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_KANBAN_FUNNEL_UI_FLAG, { isUpdating: false });
    }
  },

  delete: async function deleteKanbanFunnel({ commit }, id) {
    commit(types.SET_KANBAN_FUNNEL_UI_FLAG, { isDeleting: true });
    try {
      await KanbanFunnelsAPI.delete(id);
      commit(types.DELETE_KANBAN_FUNNEL, id);
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_KANBAN_FUNNEL_UI_FLAG, { isDeleting: false });
    }
  },
};

export const mutations = {
  [types.SET_KANBAN_FUNNEL_UI_FLAG](_state, data) {
    _state.uiFlags = { ..._state.uiFlags, ...data };
  },
  [types.SET_KANBAN_FUNNELS]: MutationHelpers.set,
  [types.ADD_KANBAN_FUNNEL]: MutationHelpers.create,
  [types.EDIT_KANBAN_FUNNEL]: MutationHelpers.update,
  [types.DELETE_KANBAN_FUNNEL]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  actions,
  state,
  getters,
  mutations,
};
