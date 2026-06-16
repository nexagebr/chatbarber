import types from '../mutation-types';
import KanbanPlacementsAPI from '../../api/kanbanPlacements';

function buildCacheEntry(placements, funnels) {
  const p = placements[0] ?? null;
  if (!p) return { funnelName: null, stageType: null, stageIndex: 0, totalStages: 0 };
  const funnel = funnels.find(f => f.id === p.funnel_id);
  let stageIndex = 0, totalStages = 0;
  if (funnel) {
    const regular = (funnel.stages || [])
      .filter(s => !s.stage_type || s.stage_type === 'regular')
      .sort((a, b) => (a.position ?? 0) - (b.position ?? 0));
    totalStages = regular.length;
    const idx = regular.findIndex(s => s.id === p.stage_id);
    stageIndex = idx >= 0 ? idx + 1 : 0;
  }
  return { funnelName: p.funnel_name ?? null, stageType: p.stage_type ?? null, stageIndex, totalStages };
}

export const state = {
  placements: [],
  funnels: [],
  uiFlags: { isFetching: false, isMoving: false },
  conversationFunnelCache: {},
  fetchedConversationIds: {},
};

export const getters = {
  getPlacements: $state => $state.placements,
  getFunnels: $state => $state.funnels,
  getUIFlags: $state => $state.uiFlags,
  getPlacementsByFunnel: $state => funnelId =>
    $state.placements.filter(p => p.funnel_id === funnelId),
  getFunnelNameForConversation: $state => conversationId =>
    $state.conversationFunnelCache[conversationId]?.funnelName ?? null,
  getKanbanInfoForConversation: $state => conversationId =>
    $state.conversationFunnelCache[conversationId] ?? null,
};

export const actions = {
  async fetchForConversation({ commit }, conversationId) {
    commit(types.SET_KANBAN_PLACEMENTS_UI_FLAGS, { isFetching: true });
    try {
      const { data } = await KanbanPlacementsAPI.getForConversation(conversationId);
      const placements = data.placements || [];
      const funnels   = data.funnels   || [];
      commit(types.SET_KANBAN_PLACEMENTS, placements);
      commit(types.SET_KANBAN_PLACEMENTS_FUNNELS, funnels);
      commit(types.CACHE_KANBAN_CONVERSATION_FUNNEL, {
        conversationId,
        ...buildCacheEntry(placements, funnels),
      });
    } catch {
      commit(types.SET_KANBAN_PLACEMENTS, []);
      commit(types.SET_KANBAN_PLACEMENTS_FUNNELS, []);
    } finally {
      commit(types.SET_KANBAN_PLACEMENTS_UI_FLAGS, { isFetching: false });
    }
  },

  async fetchBulkForConversations({ commit, state: $state }, conversationIds) {
    if (!conversationIds?.length) return;
    const unfetched = conversationIds.filter(id => !$state.fetchedConversationIds[id]);
    if (!unfetched.length) return;
    // Mark as fetched immediately to avoid duplicate in-flight requests
    commit(types.MARK_KANBAN_CONVERSATIONS_FETCHED, unfetched);
    try {
      const { data } = await KanbanPlacementsAPI.getBulkForConversations(unfetched);
      const placements = data.placements || [];
      const funnels    = data.funnels    || [];
      if (funnels.length) commit(types.SET_KANBAN_PLACEMENTS_FUNNELS, funnels);
      unfetched.forEach(conversationId => {
        const convPlacements = placements.filter(p => p.conversation_id === conversationId);
        commit(types.CACHE_KANBAN_CONVERSATION_FUNNEL, {
          conversationId,
          ...buildCacheEntry(convPlacements, funnels),
        });
      });
    } catch {
      // fail silently — cards will show empty state
    }
  },

  async fetchForContact({ commit }, contactId) {
    commit(types.SET_KANBAN_PLACEMENTS_UI_FLAGS, { isFetching: true });
    try {
      const { data } = await KanbanPlacementsAPI.getForContact(contactId);
      commit(types.SET_KANBAN_PLACEMENTS, data.placements || []);
      commit(types.SET_KANBAN_PLACEMENTS_FUNNELS, data.funnels || []);
    } catch {
      commit(types.SET_KANBAN_PLACEMENTS, []);
      commit(types.SET_KANBAN_PLACEMENTS_FUNNELS, []);
    } finally {
      commit(types.SET_KANBAN_PLACEMENTS_UI_FLAGS, { isFetching: false });
    }
  },

  upsertPlacement({ commit }, placement) {
    commit(types.UPSERT_KANBAN_PLACEMENT, placement);
  },

  removePlacement({ commit }, { funnelId, conversationDisplayId }) {
    commit(types.REMOVE_KANBAN_PLACEMENT, { funnelId, conversationDisplayId });
  },
};

export const mutations = {
  [types.SET_KANBAN_PLACEMENTS]($state, data) {
    $state.placements = data;
  },
  [types.SET_KANBAN_PLACEMENTS_FUNNELS]($state, data) {
    $state.funnels = data;
  },
  [types.SET_KANBAN_PLACEMENTS_UI_FLAGS]($state, flags) {
    $state.uiFlags = { ...$state.uiFlags, ...flags };
  },
  [types.CACHE_KANBAN_CONVERSATION_FUNNEL]($state, { conversationId, funnelName, stageType, stageIndex, totalStages }) {
    $state.conversationFunnelCache = {
      ...$state.conversationFunnelCache,
      [conversationId]: { funnelName, stageType, stageIndex, totalStages },
    };
  },
  [types.MARK_KANBAN_CONVERSATIONS_FETCHED]($state, ids) {
    const updated = { ...$state.fetchedConversationIds };
    ids.forEach(id => { updated[id] = true; });
    $state.fetchedConversationIds = updated;
  },
  [types.UPSERT_KANBAN_PLACEMENT]($state, placement) {
    const idx = $state.placements.findIndex(
      p => p.funnel_id === placement.funnel_id && p.conversation_id === placement.conversation_id
    );
    if (idx >= 0) $state.placements.splice(idx, 1, placement);
    else $state.placements.push(placement);
  },
  [types.REMOVE_KANBAN_PLACEMENT]($state, { funnelId, conversationDisplayId }) {
    $state.placements = $state.placements.filter(
      p => !(p.funnel_id === funnelId && p.conversation_id === conversationDisplayId)
    );
  },
};

export default { namespaced: true, state, getters, actions, mutations };
