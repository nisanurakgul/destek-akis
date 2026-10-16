# Creates the first admin, since there is no public sign-up page.
#
#   bin/rails users:create_admin NAME="Ada Admin" EMAIL=admin@example.com PASSWORD=secret123
namespace :users do
  desc "Create an admin user from NAME, EMAIL and PASSWORD environment variables"
  task create_admin: :environment do
    user = User.new(
      name: ENV["NAME"],
      email_address: ENV["EMAIL"],
      password: ENV["PASSWORD"],
      password_confirmation: ENV["PASSWORD"],
      role: :admin
    )

    if user.save
      puts "Admin #{user.email_address} created."
    else
      abort "Could not create admin: #{user.errors.full_messages.to_sentence}"
    end
  end
end
