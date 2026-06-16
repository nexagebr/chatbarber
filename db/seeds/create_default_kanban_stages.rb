# frozen_string_literal: true

# Create default kanban stages for each account that doesn't have any
Account.find_each do |account|
  next if account.kanban_stages.exists?

  puts "Creating default kanban stages for account: #{account.name} (ID: #{account.id})"

  default_stages = [
    { name: 'Novo', color: 'bg-blue-500', position: 0 },
    { name: 'Contatado', color: 'bg-yellow-500', position: 1 },
    { name: 'Qualificado', color: 'bg-purple-500', position: 2 },
    { name: 'Engajado', color: 'bg-green-500', position: 3 },
    { name: 'Inativo', color: 'bg-gray-500', position: 4 }
  ]

  default_stages.each do |stage_attrs|
    account.kanban_stages.create!(stage_attrs)
  end

  puts "  ✓ Created #{default_stages.size} stages"
end

puts "\nDone! Created default kanban stages for all accounts."
