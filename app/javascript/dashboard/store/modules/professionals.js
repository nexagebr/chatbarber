import { professionalsAPI, branchesAPI } from '../../api/professionals';

const state = {
  professionals: [],
  branches: [],
  uiFlags: { isFetching: false, isSaving: false },
};

const getters = {
  getProfessionals: s => s.professionals,
  getBranches: s => s.branches,
  getUIFlags: s => s.uiFlags,
};

const actions = {
  async fetchProfessionals({ commit }) {
    commit('SET_UI', { isFetching: true });
    try {
      const { data } = await professionalsAPI.list();
      commit('SET_PROFESSIONALS', data);
    } finally { commit('SET_UI', { isFetching: false }); }
  },
  async activateAgent({ commit, dispatch }, { agentId, active }) {
    const { data } = await professionalsAPI.activateAgent(agentId, active);
    await dispatch('fetchProfessionals');
    return data;
  },
  async createProfessional({ commit }, payload) {
    commit('SET_UI', { isSaving: true });
    try {
      const { data } = await professionalsAPI.create(payload);
      commit('ADD_PROFESSIONAL', data); return data;
    } finally { commit('SET_UI', { isSaving: false }); }
  },
  async updateProfessional({ commit }, { id, ...payload }) {
    commit('SET_UI', { isSaving: true });
    try {
      const { data } = await professionalsAPI.update(id, payload);
      commit('UPDATE_PROFESSIONAL', data); return data;
    } finally { commit('SET_UI', { isSaving: false }); }
  },
  async deleteProfessional({ commit }, id) {
    await professionalsAPI.del(id);
    commit('REMOVE_PROFESSIONAL', id);
  },
  async setSchedules({ dispatch }, { id, schedules }) {
    await professionalsAPI.setSchedules(id, schedules);
    await dispatch('fetchProfessionals');
  },
  async addBlockedDate(_, { id, ...payload }) {
    const { data } = await professionalsAPI.addBlockedDate(id, payload);
    return data;
  },
  async deleteBlockedDate(_, { profId, id }) {
    await professionalsAPI.delBlockedDate(profId, id);
  },

  async fetchBranches({ commit }) {
    commit('SET_UI', { isFetching: true });
    try {
      const { data } = await branchesAPI.list();
      commit('SET_BRANCHES', data);
    } finally { commit('SET_UI', { isFetching: false }); }
  },
  async createBranch({ commit }, payload) {
    commit('SET_UI', { isSaving: true });
    try {
      const { data } = await branchesAPI.create(payload);
      commit('ADD_BRANCH', data); return data;
    } finally { commit('SET_UI', { isSaving: false }); }
  },
  async updateBranch({ commit }, { id, ...payload }) {
    commit('SET_UI', { isSaving: true });
    try {
      const { data } = await branchesAPI.update(id, payload);
      commit('UPDATE_BRANCH', data); return data;
    } finally { commit('SET_UI', { isSaving: false }); }
  },
  async deleteBranch({ commit }, id) {
    await branchesAPI.del(id);
    commit('REMOVE_BRANCH', id);
  },
  async setBranchSchedules(_, { id, schedules }) {
    const { data } = await branchesAPI.setSchedules(id, schedules);
    return data;
  },
};

const mutations = {
  SET_UI(s, f) { s.uiFlags = { ...s.uiFlags, ...f }; },
  SET_PROFESSIONALS(s, d) { s.professionals = d; },
  ADD_PROFESSIONAL(s, p) { s.professionals.push(p); },
  UPDATE_PROFESSIONAL(s, p) {
    const i = s.professionals.findIndex(r => r.id === p.id);
    if (i >= 0) s.professionals.splice(i, 1, p);
  },
  REMOVE_PROFESSIONAL(s, id) { s.professionals = s.professionals.filter(r => r.id !== id); },
  SET_BRANCHES(s, d) { s.branches = d; },
  ADD_BRANCH(s, b) { s.branches.push(b); },
  UPDATE_BRANCH(s, b) {
    const i = s.branches.findIndex(r => r.id === b.id);
    if (i >= 0) s.branches.splice(i, 1, b);
  },
  REMOVE_BRANCH(s, id) { s.branches = s.branches.filter(r => r.id !== id); },
};

export default { namespaced: true, state, getters, actions, mutations };
