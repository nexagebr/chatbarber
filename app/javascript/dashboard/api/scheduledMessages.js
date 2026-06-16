/* global axios */
import ApiClient from './ApiClient';

class ScheduledMessagesAPI extends ApiClient {
  constructor() {
    super('scheduled_messages', { accountScoped: true });
  }

  convUrl(conversationId) {
    return this.url.replace('scheduled_messages', `conversations/${conversationId}/scheduled_messages`);
  }

  list(conversationId) {
    return axios.get(this.convUrl(conversationId));
  }

  create(conversationId, data) {
    return axios.post(this.convUrl(conversationId), { scheduled_message: data });
  }

  cancel(conversationId, id) {
    return axios.delete(`${this.convUrl(conversationId)}/${id}`);
  }
}

export default new ScheduledMessagesAPI();
