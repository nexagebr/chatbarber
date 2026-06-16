json.array! @kanban_stages do |stage|
  json.id stage.id
  json.name stage.name
  json.position stage.position
  json.color stage.color
  json.label_id stage.label_id
  json.stage_type stage.stage_type
  json.funnel_id stage.funnel_id
  json.label do
    if stage.label
      json.id stage.label.id
      json.title stage.label.title
      json.color stage.label.color
    end
  end
end
