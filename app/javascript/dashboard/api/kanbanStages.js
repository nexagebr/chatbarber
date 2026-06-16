/* global axios */
import ApiClient from './ApiClient';

class KanbanStagesAPI extends ApiClient {
  constructor() {
    super('kanban_stages', { accountScoped: true });
  }

  // Build URL scoped under the funnel
  funnelUrl(funnelId) {
    // Base url is like /api/v1/accounts/1/kanban_stages
    // We need /api/v1/accounts/1/kanban_funnels/:funnelId/kanban_stages
    return this.url.replace('kanban_stages', `kanban_funnels/${funnelId}/kanban_stages`);
  }

  get(funnelId) {
    return axios.get(this.funnelUrl(funnelId));
  }

  create(funnelId, data) {
    return axios.post(this.funnelUrl(funnelId), { kanban_stage: data });
  }

  update(funnelId, id, data) {
    return axios.patch(`${this.funnelUrl(funnelId)}/${id}`, { kanban_stage: data });
  }

  delete(funnelId, id) {
    return axios.delete(`${this.funnelUrl(funnelId)}/${id}`);
  }

  reorder(funnelId, stages) {
    return axios.post(`${this.funnelUrl(funnelId)}/reorder`, { stages });
  }
}

export default new KanbanStagesAPI();
