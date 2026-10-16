require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  def valid_params
    { user: { name: "Yeni Ajan", email_address: "new@example.com", role: "agent",
              password: "secret123", password_confirmation: "secret123" } }
  end

  # --- signed out ---

  test "signed-out visitors cannot see the new user form" do
    get new_user_path
    assert_redirected_to new_session_path
  end

  test "signed-out visitors cannot create users" do
    assert_no_difference "User.count" do
      post users_path, params: valid_params
    end
    assert_redirected_to new_session_path
  end

  # --- agent ---

  test "agents cannot open the user pages" do
    sign_in_as users(:agent)

    get users_path
    assert_redirected_to root_path

    get new_user_path
    assert_redirected_to root_path
  end

  test "agents cannot create users, including admins" do
    sign_in_as users(:agent)

    assert_no_difference "User.count" do
      post users_path, params: valid_params.deep_merge(user: { role: "admin" })
    end
    assert_redirected_to root_path
  end

  # --- admin ---

  test "admins can list users and open the form" do
    sign_in_as users(:admin)

    get users_path
    assert_response :success
    assert_select "td", "Ali Agent"

    get new_user_path
    assert_response :success
  end

  test "admins can create an agent" do
    sign_in_as users(:admin)

    assert_difference "User.count", 1 do
      post users_path, params: valid_params
    end
    assert_redirected_to users_path
    assert User.find_by(email_address: "new@example.com").agent?
  end

  test "admins can create another admin" do
    sign_in_as users(:admin)

    post users_path, params: valid_params.deep_merge(user: { role: "admin" })
    assert User.find_by(email_address: "new@example.com").admin?
  end

  test "invalid role is rejected and the form is shown again" do
    sign_in_as users(:admin)

    assert_no_difference "User.count" do
      post users_path, params: valid_params.deep_merge(user: { role: "superuser" })
    end
    assert_response :unprocessable_entity
    assert_select "li", "Role is not included in the list"
  end

  test "too short password is rejected" do
    sign_in_as users(:admin)

    assert_no_difference "User.count" do
      post users_path, params: valid_params.deep_merge(user: { password: "short", password_confirmation: "short" })
    end
    assert_response :unprocessable_entity
  end
end
