Rails.cache.clear

config = InstallationConfig.find_by(name: 'INSTALLATION_NAME')
if config
  config.update!(value: 'Chatbarber')
  puts "✅ Updated INSTALLATION_NAME to: #{config.value}"
else
  InstallationConfig.create!(name: 'INSTALLATION_NAME', value: 'Chatbarber')
  puts "✅ Created INSTALLATION_NAME: Chatbarber"
end

GlobalConfig.clear_cache
puts "✅ Cache cleared"
