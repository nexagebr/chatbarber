/* global axios */
import ApiClient from './ApiClient';

class InboxKnowledgeItemsAPI extends ApiClient {
  constructor() {
    super('inbox_knowledge_items', { accountScoped: true });
  }

  getAll({ inboxId, search } = {}) {
    const params = {};
    if (inboxId) params.inbox_id = inboxId;
    if (search) params.search = search;
    return axios.get(this.url, { params });
  }
}

export default new InboxKnowledgeItemsAPI();
