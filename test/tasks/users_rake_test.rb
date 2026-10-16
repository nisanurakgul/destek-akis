require "test_helper"
require "rake"

class UsersRakeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    @task = Rake::Task["users:create_admin"]
    @task.reenable
  end

  def with_env(values)
    old = values.keys.to_h { |key| [ key, ENV[key] ] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    old.each { |key, value| ENV[key] = value }
  end

  test "creates an admin from environment variables" do
    with_env("NAME" => "First Admin", "EMAIL" => "first@example.com", "PASSWORD" => "secret123") do
      assert_output(/Admin first@example.com created/) { @task.invoke }
    end

    user = User.find_by!(email_address: "first@example.com")
    assert user.admin?
    assert user.authenticate("secret123")
  end

  test "aborts with the validation errors when input is invalid" do
    with_env("NAME" => "First Admin", "EMAIL" => "first@example.com", "PASSWORD" => "short") do
      assert_no_difference "User.count" do
        _out, err = capture_io do
          assert_raises(SystemExit) { @task.invoke }
        end
        assert_match(/Password is too short/, err)
      end
    end
  end
end
