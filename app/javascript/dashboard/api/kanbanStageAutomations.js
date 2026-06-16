/* global axios */
import ApiClient from './ApiClient';

class KanbanStageAutomationsAPI extends ApiClient {
  constructor() {
    super('kanban_stage_automations', { accountScoped: true });
  }

  stageUrl(funnelId, stageId) {
    return this.url.replace(
      'kanban_stage_automations',
      `kanban_funnels/${funnelId}/kanban_stages/${stageId}/kanban_stage_automations`
    );
  }

  list(funnelId, stageId) {
    return axios.get(this.stageUrl(funnelId, stageId));
  }

  create(funnelId, stageId, data) {
    return axios.post(this.stageUrl(funnelId, stageId), { kanban_stage_automation: data });
  }

  update(funnelId, stageId, id, data) {
    return axios.patch(`${this.stageUrl(funnelId, stageId)}/${id}`, { kanban_stage_automation: data });
  }

  delete(funnelId, stageId, id) {
    return axios.delete(`${this.stageUrl(funnelId, stageId)}/${id}`);
  }
}

export default new KanbanStageAutomationsAPI();
