/* global axios */
import ApiClient from './ApiClient';

class ConversationApi extends ApiClient {
  constructor() {
    super('conversations', { accountScoped: true });
  }

  getLabels(conversationID) {
    return axios.get(`${this.url}/${conversationID}/labels`);
  }

  updateLabels(conversationID, labels) {
    return axios.post(`${this.url}/${conversationID}/labels`, { labels });
  }

  updateLeadSource(conversationID, leadSource) {
    return axios.post(`${this.url}/${conversationID}/lead_source`, {
      lead_source: leadSource,
    });
  }
}

export default new ConversationApi();
