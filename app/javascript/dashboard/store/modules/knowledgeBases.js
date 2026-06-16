import API from '../../api/knowledgeBases';

const state = {
  list: [],
  active: null,
  faqs: [],
  sites: [],
  files: [],
  inboxIds: [],
  uiFlags: {
    isFetching: false,
    isSaving: false,
  },
};

const getters = {
  getList: s => s.list,
  getActive: s => s.active,
  getFaqs: s => s.faqs,
  getSites: s => s.sites,
  getFiles: s => s.files,
  getInboxIds: s => s.inboxIds,
  getUIFlags: s => s.uiFlags,
};

const actions = {
  async fetchList({ commit }) {
    commit('SET_UI', { isFetching: true });
    try {
      const { data } = await API.list();
      commit('SET_LIST', data);
    } finally {
      commit('SET_UI', { isFetching: false });
    }
  },

  async fetchOne({ commit }, id) {
    commit('SET_UI', { isFetching: true });
    try {
      const { data } = await API.getOne(id);
      commit('SET_ACTIVE', data);
      commit('SET_INBOX_IDS', data.inbox_ids || []);
      return data;
    } finally {
      commit('SET_UI', { isFetching: false });
    }
  },

  async createKB({ commit }, payload) {
    commit('SET_UI', { isSaving: true });
    try {
      const { data } = await API.create(payload);
      commit('ADD_TO_LIST', data);
      return data;
    } finally {
      commit('SET_UI', { isSaving: false });
    }
  },

  async updateKB({ commit }, { id, ...payload }) {
    commit('SET_UI', { isSaving: true });
    try {
      const { data } = await API.update(id, payload);
      commit('UPDATE_IN_LIST', data);
      commit('SET_ACTIVE', data);
      return data;
    } finally {
      commit('SET_UI', { isSaving: false });
    }
  },

  async deleteKB({ commit }, id) {
    await API.del(id);
    commit('REMOVE_FROM_LIST', id);
  },

  // FAQs
  async fetchFaqs({ commit }, { kbId, search } = {}) {
    commit('SET_UI', { isFetching: true });
    try {
      const { data } = await API.getFaqs(kbId, search);
      commit('SET_FAQS', data);
    } finally {
      commit('SET_UI', { isFetching: false });
    }
  },

  async createFaq({ commit }, { kbId, ...payload }) {
    commit('SET_UI', { isSaving: true });
    try {
      const { data } = await API.createFaq(kbId, payload);
      commit('ADD_FAQ', data);
      return data;
    } finally {
      commit('SET_UI', { isSaving: false });
    }
  },

  async updateFaq({ commit }, { kbId, id, ...payload }) {
    commit('SET_UI', { isSaving: true });
    try {
      const { data } = await API.updateFaq(kbId, id, payload);
      commit('UPDATE_FAQ', data);
      return data;
    } finally {
      commit('SET_UI', { isSaving: false });
    }
  },

  async deleteFaq({ commit }, { kbId, id }) {
    await API.deleteFaq(kbId, id);
    commit('REMOVE_FAQ', id);
  },

  // Sites
  async fetchSites({ commit }, kbId) {
    commit('SET_UI', { isFetching: true });
    try {
      const { data } = await API.getSites(kbId);
      commit('SET_SITES', data);
    } finally {
      commit('SET_UI', { isFetching: false });
    }
  },

  async createSite({ commit }, { kbId, ...payload }) {
    commit('SET_UI', { isSaving: true });
    try {
      const { data } = await API.createSite(kbId, payload);
      commit('ADD_SITE', data);
      return data;
    } finally {
      commit('SET_UI', { isSaving: false });
    }
  },

  async deleteSite({ commit }, { kbId, id }) {
    await API.deleteSite(kbId, id);
    commit('REMOVE_SITE', id);
  },

  // Files
  async fetchFiles({ commit }, kbId) {
    commit('SET_UI', { isFetching: true });
    try {
      const { data } = await API.getFiles(kbId);
      commit('SET_FILES', data);
    } finally {
      commit('SET_UI', { isFetching: false });
    }
  },

  async createFile({ commit }, { kbId, ...payload }) {
    commit('SET_UI', { isSaving: true });
    try {
      const { data } = await API.createFile(kbId, payload);
      commit('ADD_FILE', data);
      return data;
    } finally {
      commit('SET_UI', { isSaving: false });
    }
  },

  async deleteFile({ commit }, { kbId, id }) {
    await API.deleteFile(kbId, id);
    commit('REMOVE_FILE', id);
  },

  // Inboxes
  async fetchInboxIds({ commit }, kbId) {
    const { data } = await API.getInboxes(kbId);
    commit('SET_INBOX_IDS', data);
  },

  async updateInboxIds({ commit }, { kbId, ids }) {
    commit('SET_UI', { isSaving: true });
    try {
      const { data } = await API.updateInboxes(kbId, ids);
      commit('SET_INBOX_IDS', data);
      return data;
    } finally {
      commit('SET_UI', { isSaving: false });
    }
  },
};

const mutations = {
  SET_UI(s, flags) {
    s.uiFlags = { ...s.uiFlags, ...flags };
  },
  SET_LIST(s, data) {
    s.list = data;
  },
  SET_ACTIVE(s, kb) {
    s.active = kb;
  },
  ADD_TO_LIST(s, kb) {
    s.list.push(kb);
  },
  UPDATE_IN_LIST(s, kb) {
    const idx = s.list.findIndex(r => r.id === kb.id);
    if (idx >= 0) s.list.splice(idx, 1, kb);
  },
  REMOVE_FROM_LIST(s, id) {
    s.list = s.list.filter(r => r.id !== id);
  },
  SET_FAQS(s, data) {
    s.faqs = data;
  },
  ADD_FAQ(s, faq) {
    s.faqs.push(faq);
  },
  UPDATE_FAQ(s, faq) {
    const idx = s.faqs.findIndex(r => r.id === faq.id);
    if (idx >= 0) s.faqs.splice(idx, 1, faq);
  },
  REMOVE_FAQ(s, id) {
    s.faqs = s.faqs.filter(r => r.id !== id);
  },
  SET_SITES(s, data) {
    s.sites = data;
  },
  ADD_SITE(s, site) {
    s.sites.push(site);
  },
  REMOVE_SITE(s, id) {
    s.sites = s.sites.filter(r => r.id !== id);
  },
  SET_FILES(s, data) {
    s.files = data;
  },
  ADD_FILE(s, file) {
    s.files.push(file);
  },
  REMOVE_FILE(s, id) {
    s.files = s.files.filter(r => r.id !== id);
  },
  SET_INBOX_IDS(s, ids) {
    s.inboxIds = ids;
  },
};

export default { namespaced: true, state, getters, actions, mutations };
