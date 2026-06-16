json.placements @placements do |item|
  conv = item.conversation
  stage = item.stage
  funnel = item.funnel

  json.id item.id
  json.funnel_id item.funnel_id
  json.funnel_name funnel&.name
  json.conversation_id conv&.display_id
  json.conversation_label conv&.contact&.name
  json.stage_id item.stage_id
  json.stage_name stage&.name
  json.stage_color stage&.color
  json.stage_type stage&.stage_type
  json.deal_value item.deal_value
  json.loss_reason item.loss_reason
  json.outcome_note item.outcome_note
  json.entered_at item.entered_at
  json.outcome_at item.outcome_at
end

json.funnels @funnels do |funnel|
  json.id funnel.id
  json.name funnel.name
  json.inbox_ids funnel.kanban_funnel_inboxes.pluck(:inbox_id)
  json.stages funnel.kanban_stages.order(:position) do |stage|
    json.id stage.id
    json.name stage.name
    json.stage_type stage.stage_type
    json.color stage.color
    json.position stage.position
  end
end
