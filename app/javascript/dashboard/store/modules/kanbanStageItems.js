import types from '../mutation-types';
import KanbanStageItemsAPI from '../../api/kanbanStageItems';

export const state = {
  records: [], // [{ funnel_id, conversation_id, stage_id, entered_at }]
  uiFlags: {
    isFetching: false,
    isMoving: false,
  },
};

export const getters = {
  getKanbanStageItems: $state => $state.records,
  getStageItemByConversationId: $state => conversationId =>
    $state.records.find(r => r.conversation_id === conversationId),
  getUIFlags: $state => $state.uiFlags,
};

export const actions = {
  async get({ commit }, funnelId) {
    commit(types.SET_KANBAN_STAGE_ITEMS, []);
    try {
      const { data } = await KanbanStageItemsAPI.list(funnelId);
      commit(types.SET_KANBAN_STAGE_ITEMS, data);
    } catch {
      // ignore — store stays empty
    }
  },

  async move({ commit }, { funnelId, conversationId, stageId, dealValue, lossReason, outcomeNote }) {
    try {
      const { data } = await KanbanStageItemsAPI.move(funnelId, {
        conversationId,
        stageId,
        dealValue,
        lossReason,
        outcomeNote,
      });
      commit(types.UPSERT_KANBAN_STAGE_ITEM, data);
      return data;
    } catch (e) {
      throw new Error(e);
    }
  },

  async remove({ commit }, { funnelId, conversationId }) {
    try {
      await KanbanStageItemsAPI.remove(funnelId, conversationId);
      commit(types.REMOVE_KANBAN_STAGE_ITEM, conversationId);
    } catch (e) {
      throw new Error(e);
    }
  },
};

export const mutations = {
  [types.SET_KANBAN_STAGE_ITEMS]($state, data) {
    $state.records = data;
  },
  [types.UPSERT_KANBAN_STAGE_ITEM]($state, item) {
    const idx = $state.records.findIndex(
      r => r.conversation_id === item.conversation_id
    );
    if (idx >= 0) {
      $state.records.splice(idx, 1, item);
    } else {
      $state.records.push(item);
    }
  },
  [types.REMOVE_KANBAN_STAGE_ITEM]($state, conversationId) {
    $state.records = $state.records.filter(
      r => r.conversation_id !== conversationId
    );
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
