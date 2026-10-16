require "test_helper"

class UserTest < ActiveSupport::TestCase
  def build_user(**attributes)
    User.new({
      name: "Deniz Destek",
      email_address: "deniz@example.com",
      password: "secret123",
      password_confirmation: "secret123"
    }.merge(attributes))
  end

  test "valid with name, email and password" do
    assert build_user.valid?
  end

  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "requires a name" do
    user = build_user(name: "  ")
    assert_not user.valid?
    assert_includes user.errors[:name], "can't be blank"
  end

  test "requires a valid, unique email address" do
    assert_not build_user(email_address: "not-an-email").valid?

    duplicate = build_user(email_address: users(:admin).email_address.upcase)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email_address], "has already been taken"
  end

  # --- roles ---

  test "role defaults to agent" do
    user = build_user
    assert user.agent?
    assert_not user.admin?
  end

  test "accepts the admin role" do
    assert build_user(role: "admin").valid?
  end

  test "rejects an unknown role with a validation error" do
    user = build_user(role: "superuser")
    assert_not user.valid?
    assert_includes user.errors[:role], "is not included in the list"
  end

  test "rejects a blank role" do
    assert_not build_user(role: nil).valid?
  end

  test "database refuses an unknown role even when validations are skipped" do
    assert_raises(ActiveRecord::StatementInvalid) do
      users(:agent).update_column(:role, "superuser")
    end
  end

  # --- passwords ---

  test "stores a bcrypt digest, never the plain password" do
    user = build_user
    user.save!

    assert_not_equal "secret123", user.password_digest
    assert user.password_digest.start_with?("$2")
    assert_not_includes User.column_names, "password"
  end

  test "requires a password when created" do
    user = build_user(password: nil, password_confirmation: nil)
    assert_not user.valid?
    assert_includes user.errors[:password], "can't be blank"
  end

  test "requires at least 8 characters" do
    user = build_user(password: "short1", password_confirmation: "short1")
    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 8 characters)"
  end

  test "requires the confirmation to match" do
    user = build_user(password_confirmation: "something-else")
    assert_not user.valid?
    assert_includes user.errors[:password_confirmation], "doesn't match Password"
  end

  test "can be updated without re-entering the password" do
    user = users(:agent)
    assert user.update(name: "New Name")
  end

  test "authenticate_by returns the user only for the correct password" do
    assert_equal users(:agent), User.authenticate_by(email_address: "agent@example.com", password: "password")
    assert_nil User.authenticate_by(email_address: "agent@example.com", password: "wrong-password")
  end
end
