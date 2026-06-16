/* global axios */
import ApiClient from './ApiClient';

class KanbanStageItemsAPI extends ApiClient {
  constructor() {
    super('kanban_stage_items', { accountScoped: true });
  }

  funnelUrl(funnelId) {
    return this.url.replace(
      'kanban_stage_items',
      `kanban_funnels/${funnelId}/kanban_stage_items`
    );
  }

  list(funnelId) {
    return axios.get(this.funnelUrl(funnelId));
  }

  move(funnelId, { conversationId, stageId, dealValue, lossReason, outcomeNote }) {
    return axios.put(`${this.funnelUrl(funnelId)}/upsert`, {
      conversation_id: conversationId,
      stage_id: stageId,
      deal_value: dealValue,
      loss_reason: lossReason,
      outcome_note: outcomeNote,
    });
  }

  remove(funnelId, conversationId) {
    return axios.delete(`${this.funnelUrl(funnelId)}/${conversationId}`);
  }
}

export default new KanbanStageItemsAPI();
