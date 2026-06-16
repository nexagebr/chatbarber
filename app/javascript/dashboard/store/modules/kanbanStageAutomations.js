import types from '../mutation-types';
import KanbanStageAutomationsAPI from '../../api/kanbanStageAutomations';

export const state = {
  // keyed by stageId
  records: {},
  uiFlags: { isFetching: false, isSaving: false },
};

export const getters = {
  getAutomationsForStage: $state => stageId => $state.records[stageId] || [],
  getUIFlags: $state => $state.uiFlags,
};

export const actions = {
  async get({ commit }, { funnelId, stageId }) {
    try {
      const { data } = await KanbanStageAutomationsAPI.list(funnelId, stageId);
      commit(types.SET_KANBAN_STAGE_AUTOMATIONS, { stageId, data });
    } catch {
      // ignore
    }
  },

  async create({ commit }, { funnelId, stageId, automation }) {
    const { data } = await KanbanStageAutomationsAPI.create(funnelId, stageId, automation);
    commit(types.ADD_KANBAN_STAGE_AUTOMATION, { stageId, automation: data });
    return data;
  },

  async update({ commit }, { funnelId, stageId, id, automation }) {
    const { data } = await KanbanStageAutomationsAPI.update(funnelId, stageId, id, automation);
    commit(types.UPDATE_KANBAN_STAGE_AUTOMATION, { stageId, automation: data });
    return data;
  },

  async delete({ commit }, { funnelId, stageId, id }) {
    await KanbanStageAutomationsAPI.delete(funnelId, stageId, id);
    commit(types.REMOVE_KANBAN_STAGE_AUTOMATION, { stageId, id });
  },
};

export const mutations = {
  [types.SET_KANBAN_STAGE_AUTOMATIONS]($state, { stageId, data }) {
    $state.records = { ...$state.records, [stageId]: data };
  },
  [types.ADD_KANBAN_STAGE_AUTOMATION]($state, { stageId, automation }) {
    const existing = $state.records[stageId] || [];
    $state.records = { ...$state.records, [stageId]: [...existing, automation] };
  },
  [types.UPDATE_KANBAN_STAGE_AUTOMATION]($state, { stageId, automation }) {
    const existing = $state.records[stageId] || [];
    $state.records = {
      ...$state.records,
      [stageId]: existing.map(a => (a.id === automation.id ? automation : a)),
    };
  },
  [types.REMOVE_KANBAN_STAGE_AUTOMATION]($state, { stageId, id }) {
    const existing = $state.records[stageId] || [];
    $state.records = { ...$state.records, [stageId]: existing.filter(a => a.id !== id) };
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
