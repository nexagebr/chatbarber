Rails.cache.clear
InstallationConfig.where(locked: false).destroy_all
ConfigLoader.new.process

config = InstallationConfig.find_by(name: 'INSTALLATION_NAME')
puts "Config synced!"
puts "INSTALLATION_NAME: #{config.value}"
