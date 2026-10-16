require "test_helper"

class TicketStatusesControllerTest < ActionDispatch::IntegrationTest
  test "signed-out visitors cannot change a status" do
    patch ticket_status_path(tickets(:open_ticket)), params: { status: "solved" }

    assert_redirected_to new_session_path
    assert tickets(:open_ticket).reload.open?
  end

  test "an allowed change is saved and reported" do
    sign_in_as users(:agent)
    ticket = tickets(:open_ticket)

    patch ticket_status_path(ticket), params: { status: "solved" }
    assert_redirected_to ticket_path(ticket)
    assert ticket.reload.solved?

    follow_redirect!
    assert_select ".flash.notice", "Status changed from open to solved."
    assert_select ".badge.status-solved", "Solved"
  end

  test "a closed ticket cannot be reopened" do
    sign_in_as users(:agent)
    ticket = tickets(:closed_ticket)

    patch ticket_status_path(ticket), params: { status: "open" }
    assert_redirected_to ticket_path(ticket)
    assert ticket.reload.closed?

    follow_redirect!
    assert_select ".flash.alert", "Status cannot change from closed to open"
    assert_select ".badge.status-closed", "Closed"
  end

  test "skipping a step is rejected" do
    sign_in_as users(:agent)
    ticket = tickets(:open_ticket)

    patch ticket_status_path(ticket), params: { status: "closed" }
    assert ticket.reload.open?
    follow_redirect!
    assert_select ".flash.alert", "Status cannot change from open to closed"
  end

  test "an unknown status is rejected" do
    sign_in_as users(:agent)
    ticket = tickets(:open_ticket)

    patch ticket_status_path(ticket), params: { status: "archived" }
    assert ticket.reload.open?
    follow_redirect!
    assert_select ".flash.alert", "Status is not included in the list"
  end

  test "a missing status parameter is a bad request" do
    sign_in_as users(:agent)

    patch ticket_status_path(tickets(:open_ticket))
    assert_response :bad_request
    assert tickets(:open_ticket).reload.open?
  end
end
