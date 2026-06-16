/* global axios */
import ApiClient from './ApiClient';

class KnowledgeBasesAPI extends ApiClient {
  constructor() {
    super('knowledge_bases', { accountScoped: true });
  }

  list() {
    return axios.get(this.url);
  }

  getOne(id) {
    return axios.get(`${this.url}/${id}`);
  }

  create(data) {
    return axios.post(this.url, { knowledge_base: data });
  }

  update(id, data) {
    return axios.patch(`${this.url}/${id}`, { knowledge_base: data });
  }

  del(id) {
    return axios.delete(`${this.url}/${id}`);
  }

  // FAQs
  getFaqs(kbId, search) {
    return axios.get(`${this.url}/${kbId}/knowledge_base_faqs`, {
      params: search ? { search } : {},
    });
  }

  createFaq(kbId, data) {
    return axios.post(`${this.url}/${kbId}/knowledge_base_faqs`, {
      knowledge_base_faq: data,
    });
  }

  updateFaq(kbId, id, data) {
    return axios.patch(`${this.url}/${kbId}/knowledge_base_faqs/${id}`, {
      knowledge_base_faq: data,
    });
  }

  deleteFaq(kbId, id) {
    return axios.delete(`${this.url}/${kbId}/knowledge_base_faqs/${id}`);
  }

  // Sites
  getSites(kbId) {
    return axios.get(`${this.url}/${kbId}/knowledge_base_sites`);
  }

  createSite(kbId, data) {
    return axios.post(`${this.url}/${kbId}/knowledge_base_sites`, {
      knowledge_base_site: data,
    });
  }

  deleteSite(kbId, id) {
    return axios.delete(`${this.url}/${kbId}/knowledge_base_sites/${id}`);
  }

  // Files
  getFiles(kbId) {
    return axios.get(`${this.url}/${kbId}/knowledge_base_files`);
  }

  createFile(kbId, data) {
    return axios.post(`${this.url}/${kbId}/knowledge_base_files`, {
      knowledge_base_file: data,
    });
  }

  deleteFile(kbId, id) {
    return axios.delete(`${this.url}/${kbId}/knowledge_base_files/${id}`);
  }

  // Inboxes
  getInboxes(kbId) {
    return axios.get(`${this.url}/${kbId}/knowledge_base_inboxes`);
  }

  updateInboxes(kbId, ids) {
    return axios.patch(`${this.url}/${kbId}/knowledge_base_inboxes`, {
      inbox_ids: ids,
    });
  }
}

export default new KnowledgeBasesAPI();
