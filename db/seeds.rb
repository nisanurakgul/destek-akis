# Creates the first admin from environment variables, because there is no public
# sign-up page and Render's free plan has no shell to run users:create_admin.
#
# `bin/rails db:prepare` (run by bin/docker-entrypoint on every boot) runs this file
# only when it creates a brand-new database. It is safe to run again: an existing
# user with the same email is left unchanged.
#
#   ADMIN_NAME="Ada Admin" ADMIN_EMAIL=admin@example.com ADMIN_PASSWORD=secret123 bin/rails db:seed
if ENV["ADMIN_EMAIL"].present? && ENV["ADMIN_PASSWORD"].present?
  admin = User.find_or_create_by!(email_address: ENV["ADMIN_EMAIL"]) do |user|
    user.name = ENV.fetch("ADMIN_NAME", "Admin")
    user.password = ENV["ADMIN_PASSWORD"]
    user.role = :admin
  end
  puts "Admin user ready: #{admin.email_address}"
else
  puts "Skipping admin seed: set ADMIN_EMAIL and ADMIN_PASSWORD to create one."
end
