/* global axios */
import ApiClient from './ApiClient';

class KanbanPlacementsAPI extends ApiClient {
  constructor() {
    super('kanban_placements', { accountScoped: true });
  }

  getForConversation(conversationId) {
    return axios.get(this.url, { params: { conversation_id: conversationId } });
  }

  getBulkForConversations(conversationIds) {
    return axios.get(this.url, { params: { conversation_ids: conversationIds } });
  }

  getForContact(contactId) {
    return axios.get(this.url, { params: { contact_id: contactId } });
  }
}

export default new KanbanPlacementsAPI();
