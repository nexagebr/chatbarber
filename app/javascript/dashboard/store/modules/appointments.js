import { appointmentsAPI, servicesAPI } from '../../api/appointments';

const state = {
  list: [],
  services: [],
  uiFlags: { isFetching: false, isSaving: false },
};

const getters = {
  getList: s => s.list,
  getServices: s => s.services,
  getUIFlags: s => s.uiFlags,
};

const actions = {
  async fetchAppointments({ commit }, params = {}) {
    commit('SET_UI', { isFetching: true });
    const timer = setTimeout(() => commit('SET_UI', { isFetching: false }), 8000);
    try {
      const { data } = await appointmentsAPI.list(params);
      commit('SET_LIST', Array.isArray(data) ? data : []);
    } catch(e) {
      console.error('[appointments] fetchAppointments failed:', e);
    } finally {
      clearTimeout(timer);
      commit('SET_UI', { isFetching: false });
    }
  },

  async fetchServices({ commit }) {
    const { data } = await servicesAPI.list();
    commit('SET_SERVICES', data);
  },

  async createAppointment({ commit }, payload) {
    commit('SET_UI', { isSaving: true });
    try {
      const { data } = await appointmentsAPI.create(payload);
      commit('ADD_APPOINTMENT', data);
      return data;
    } finally {
      commit('SET_UI', { isSaving: false });
    }
  },

  async updateAppointment({ commit }, { id, ...payload }) {
    commit('SET_UI', { isSaving: true });
    try {
      const { data } = await appointmentsAPI.update(id, payload);
      commit('UPDATE_APPOINTMENT', data);
      return data;
    } finally {
      commit('SET_UI', { isSaving: false });
    }
  },

  async deleteAppointment({ commit }, id) {
    await appointmentsAPI.del(id);
    commit('REMOVE_APPOINTMENT', id);
  },

  async createService({ commit }, payload) {
    commit('SET_UI', { isSaving: true });
    try {
      const { data } = await servicesAPI.create(payload);
      commit('ADD_SERVICE', data);
      return data;
    } finally {
      commit('SET_UI', { isSaving: false });
    }
  },

  async deleteService({ commit }, id) {
    await servicesAPI.del(id);
    commit('REMOVE_SERVICE', id);
  },
};

const mutations = {
  SET_UI(s, f) { s.uiFlags = { ...s.uiFlags, ...f }; },
  SET_LIST(s, d) { s.list = d; },
  SET_SERVICES(s, d) { s.services = d; },
  ADD_APPOINTMENT(s, a) { s.list.push(a); },
  UPDATE_APPOINTMENT(s, a) {
    const i = s.list.findIndex(r => r.id === a.id);
    if (i >= 0) s.list.splice(i, 1, a);
  },
  REMOVE_APPOINTMENT(s, id) { s.list = s.list.filter(r => r.id !== id); },
  ADD_SERVICE(s, sv) { s.services.push(sv); },
  REMOVE_SERVICE(s, id) { s.services = s.services.filter(r => r.id !== id); },
};

export default { namespaced: true, state, getters, actions, mutations };
