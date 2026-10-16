require "test_helper"

# End-to-end sign in / sign out through real HTTP requests (no sign_in_as shortcut).
class AuthenticationFlowTest < ActionDispatch::IntegrationTest
  test "protected page redirects to sign in when signed out" do
    get root_path
    assert_redirected_to new_session_path
  end

  test "health check stays public" do
    get rails_health_check_path
    assert_response :success
  end

  test "there is no public sign-up route" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/signup")
    end
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/registrations/new")
    end
  end

  test "sign in, see the home page, sign out, and lose access" do
    post session_path, params: { email_address: "agent@example.com", password: "password" }
    assert_redirected_to root_path

    follow_redirect!
    assert_response :success
    assert_select "h1", "Hoş geldin, Ali Agent"
    assert_select "button", "Çıkış yap"

    delete session_path
    assert_redirected_to new_session_path

    get root_path
    assert_redirected_to new_session_path
  end

  test "sign in with mixed-case email works" do
    post session_path, params: { email_address: " Agent@Example.COM ", password: "password" }
    assert_redirected_to root_path
  end

  test "wrong password shows an error and creates no session" do
    assert_no_difference "Session.count" do
      post session_path, params: { email_address: "agent@example.com", password: "wrong-password" }
    end
    assert_redirected_to new_session_path

    follow_redirect!
    assert_select ".flash.alert", "E-posta adresi veya parola hatalı."
  end

  test "after signing in the user returns to the page they first asked for" do
    sign_in_as users(:admin)
    delete session_path

    get new_user_path
    assert_redirected_to new_session_path

    post session_path, params: { email_address: "admin@example.com", password: "password" }
    assert_redirected_to new_user_url
  end

  test "signing out deletes the session record" do
    post session_path, params: { email_address: "agent@example.com", password: "password" }

    assert_difference "Session.count", -1 do
      delete session_path
    end
  end
end
