/* global axios */
import ApiClient from './ApiClient';

class KanbanLossReasonsAPI extends ApiClient {
  constructor() {
    super('kanban_loss_reasons', { accountScoped: true });
  }

  list() {
    return axios.get(this.url);
  }

  create(data) {
    return axios.post(this.url, { kanban_loss_reason: data });
  }

  update(id, data) {
    return axios.patch(`${this.url}/${id}`, { kanban_loss_reason: data });
  }

  delete(id) {
    return axios.delete(`${this.url}/${id}`);
  }
}

export default new KanbanLossReasonsAPI();
