user = User.create!(
  email: 'nexagebr@gmail.com',
  password: 'N3x@g3!2025#MkT',
  password_confirmation: 'N3x@g3!2025#MkT',
  name: 'Super Admin'
)

user.update!(confirmed_at: Time.now.utc)

account = Account.create!(name: 'Nexage')
AccountUser.create!(account: account, user: user, role: :administrator)

puts 'Super admin created successfully!'
puts "Email: #{user.email}"
puts "Account: #{account.name}"
puts "User ID: #{user.id}"
