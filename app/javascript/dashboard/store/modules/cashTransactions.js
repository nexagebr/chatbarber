import { cashTransactionsAPI, commissionsAPI } from '../../api/cashTransactions';

const state = {
  transactions: [],
  summary: null,
  commissions: [],
  commissionSummary: null,
  uiFlags: { isFetching: false, isSaving: false },
};

const getters = {
  getTransactions: s => s.transactions,
  getSummary:      s => s.summary,
  getCommissions:  s => s.commissions,
  getCommissionSummary: s => s.commissionSummary,
  getUIFlags:      s => s.uiFlags,
};

const actions = {
  async fetchTransactions({ commit }, params = {}) {
    commit('SET_UI', { isFetching: true });
    try {
      const { data } = await cashTransactionsAPI.list(params);
      commit('SET_TRANSACTIONS', Array.isArray(data) ? data : []);
    } catch (e) {
      console.error('[cashTransactions] fetch failed:', e);
    } finally {
      commit('SET_UI', { isFetching: false });
    }
  },

  async fetchSummary({ commit }, params = {}) {
    try {
      const { data } = await cashTransactionsAPI.summary(params);
      commit('SET_SUMMARY', data);
    } catch (e) {
      console.error('[cashTransactions] summary failed:', e);
    }
  },

  async createTransaction({ commit }, payload) {
    commit('SET_UI', { isSaving: true });
    try {
      const { data } = await cashTransactionsAPI.create(payload);
      commit('ADD_TRANSACTION', data);
      return data;
    } finally {
      commit('SET_UI', { isSaving: false });
    }
  },

  async deleteTransaction({ commit }, id) {
    await cashTransactionsAPI.del(id);
    commit('REMOVE_TRANSACTION', id);
  },

  async fetchCommissions({ commit }, params = {}) {
    try {
      const { data } = await commissionsAPI.list(params);
      commit('SET_COMMISSIONS', Array.isArray(data) ? data : []);
    } catch (e) {
      console.error('[commissions] fetch failed:', e);
    }
  },

  async fetchCommissionSummary({ commit }, params = {}) {
    try {
      const { data } = await commissionsAPI.summary(params);
      commit('SET_COMMISSION_SUMMARY', data);
    } catch (e) {
      console.error('[commissions] summary failed:', e);
    }
  },

  async updateCommission({ commit }, { id, ...payload }) {
    const { data } = await commissionsAPI.update(id, payload);
    commit('UPDATE_COMMISSION', data);
    return data;
  },
};

const mutations = {
  SET_UI(s, f)               { s.uiFlags = { ...s.uiFlags, ...f }; },
  SET_TRANSACTIONS(s, d)     { s.transactions = d; },
  SET_SUMMARY(s, d)          { s.summary = d; },
  ADD_TRANSACTION(s, t)      { s.transactions.unshift(t); },
  REMOVE_TRANSACTION(s, id)  { s.transactions = s.transactions.filter(t => t.id !== id); },
  SET_COMMISSIONS(s, d)      { s.commissions = d; },
  SET_COMMISSION_SUMMARY(s, d) { s.commissionSummary = d; },
  UPDATE_COMMISSION(s, c) {
    const i = s.commissions.findIndex(r => r.id === c.id);
    if (i >= 0) s.commissions.splice(i, 1, c);
    // update in summary
    if (s.commissionSummary) {
      const bp = s.commissionSummary.by_professional?.find(p => p.professional_id === c.professional_id);
      if (bp && c.paid) {
        bp.paid_amount = (parseFloat(bp.paid_amount) + parseFloat(c.amount)).toFixed(2);
        bp.unpaid_amount = Math.max(0, parseFloat(bp.unpaid_amount) - parseFloat(c.amount)).toFixed(2);
      }
    }
  },
};

export default { namespaced: true, state, getters, actions, mutations };
