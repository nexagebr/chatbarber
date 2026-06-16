import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import KanbanStagesAPI from '../../api/kanbanStages';

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
  getKanbanStages(_state) {
    return _state.records;
  },
  getKanbanStageById: _state => id => {
    return _state.records.find(record => record.id === Number(id));
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};

export const actions = {
  get: async function getKanbanStages({ commit }, funnelId) {
    commit(types.SET_KANBAN_STAGE_UI_FLAG, { isFetching: true });
    try {
      const response = await KanbanStagesAPI.get(funnelId);
      commit(types.SET_KANBAN_STAGES, response.data);
    } catch (error) {
      // ignore
    } finally {
      commit(types.SET_KANBAN_STAGE_UI_FLAG, { isFetching: false });
    }
  },

  create: async function createKanbanStage({ commit }, { funnelId, ...stageData }) {
    commit(types.SET_KANBAN_STAGE_UI_FLAG, { isCreating: true });
    try {
      const response = await KanbanStagesAPI.create(funnelId, stageData);
      commit(types.ADD_KANBAN_STAGE, response.data);
      return response.data;
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_KANBAN_STAGE_UI_FLAG, { isCreating: false });
    }
  },

  update: async function updateKanbanStage({ commit }, { funnelId, id, ...stageData }) {
    commit(types.SET_KANBAN_STAGE_UI_FLAG, { isUpdating: true });
    try {
      const response = await KanbanStagesAPI.update(funnelId, id, stageData);
      commit(types.EDIT_KANBAN_STAGE, response.data);
      return response.data;
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_KANBAN_STAGE_UI_FLAG, { isUpdating: false });
    }
  },

  delete: async function deleteKanbanStage({ commit }, { funnelId, id }) {
    commit(types.SET_KANBAN_STAGE_UI_FLAG, { isDeleting: true });
    try {
      await KanbanStagesAPI.delete(funnelId, id);
      commit(types.DELETE_KANBAN_STAGE, id);
    } catch (error) {
      throw new Error(error);
    } finally {
      commit(types.SET_KANBAN_STAGE_UI_FLAG, { isDeleting: false });
    }
  },

  reorder: async function reorderKanbanStages({ commit }, { funnelId, stages }) {
    try {
      const response = await KanbanStagesAPI.reorder(funnelId, stages);
      commit(types.SET_KANBAN_STAGES, response.data);
    } catch (error) {
      throw new Error(error);
    }
  },
};

export const mutations = {
  [types.SET_KANBAN_STAGE_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },
  [types.SET_KANBAN_STAGES]: MutationHelpers.set,
  [types.ADD_KANBAN_STAGE]: MutationHelpers.create,
  [types.EDIT_KANBAN_STAGE]: MutationHelpers.update,
  [types.DELETE_KANBAN_STAGE]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  actions,
  state,
  getters,
  mutations,
};
