require "test_helper"

class TicketsControllerTest < ActionDispatch::IntegrationTest
  def valid_params
    { ticket: { subject: "VPN does not connect", description: "Error 809 since this morning.",
                requester_name: "Selin Koç", requester_email: "selin@example.com",
                priority: "high", assigned_to_id: users(:agent).id } }
  end

  # --- signed out ---

  test "signed-out visitors are sent to sign in for every ticket page" do
    ticket = tickets(:open_ticket)

    get tickets_path
    assert_redirected_to new_session_path
    get new_ticket_path
    assert_redirected_to new_session_path
    get ticket_path(ticket)
    assert_redirected_to new_session_path
    get edit_ticket_path(ticket)
    assert_redirected_to new_session_path
  end

  test "signed-out visitors cannot create or update tickets" do
    assert_no_difference "Ticket.count" do
      post tickets_path, params: valid_params
    end
    assert_redirected_to new_session_path

    patch ticket_path(tickets(:open_ticket)), params: { ticket: { subject: "Hacked" } }
    assert_redirected_to new_session_path
    assert_not_equal "Hacked", tickets(:open_ticket).reload.subject
  end

  # --- index / show ---

  test "index lists tickets with status, priority and assignee" do
    sign_in_as users(:agent)

    get tickets_path
    assert_response :success

    ticket = tickets(:open_ticket)
    assert_select "##{ActionView::RecordIdentifier.dom_id(ticket)}" do
      assert_select "a", ticket.subject
      assert_select ".badge.status-open", "Open"
      assert_select ".badge.priority-high", "High"
      assert_select "td", "Ali Agent"
    end
    assert_select "##{ActionView::RecordIdentifier.dom_id(tickets(:pending_ticket))} td", "Unassigned"
  end

  test "show displays the ticket details" do
    sign_in_as users(:agent)
    ticket = tickets(:closed_ticket)

    get ticket_path(ticket)
    assert_response :success
    assert_select "h1", "##{ticket.id} #{ticket.subject}"
    assert_select ".badge.status-closed", "Closed"
    assert_select ".badge.priority-urgent", "Urgent"
    assert_select "dd", "Ada Admin"
    assert_select ".description", /Outage resolved/
  end

  test "show offers only the status changes allowed from the current status" do
    sign_in_as users(:agent)

    get ticket_path(tickets(:open_ticket))
    assert_select ".status-actions button", count: 2
    assert_select ".status-actions button", "Mark as pending"
    assert_select ".status-actions button", "Mark as solved"

    get ticket_path(tickets(:closed_ticket))
    assert_select ".status-actions", count: 0
    assert_select "p", /Closed tickets cannot change status/
  end

  # --- create ---

  test "new shows the form with users to assign" do
    sign_in_as users(:agent)

    get new_ticket_path
    assert_response :success
    assert_select "select[name='ticket[assigned_to_id]'] option", "Unassigned"
    assert_select "select[name='ticket[assigned_to_id]'] option", "Ali Agent"
  end

  test "creates a ticket as open and shows it" do
    sign_in_as users(:agent)

    assert_difference "Ticket.count", 1 do
      post tickets_path, params: valid_params
    end

    ticket = Ticket.order(:id).last
    assert_redirected_to ticket_path(ticket)
    assert ticket.open?
    assert ticket.high?
    assert_equal users(:agent), ticket.assigned_to
  end

  test "status sent with the create form is ignored" do
    sign_in_as users(:agent)

    post tickets_path, params: valid_params.deep_merge(ticket: { status: "closed" })
    assert Ticket.order(:id).last.open?
  end

  test "invalid ticket shows validation errors" do
    sign_in_as users(:agent)

    assert_no_difference "Ticket.count" do
      post tickets_path, params: valid_params.deep_merge(ticket: { subject: "", requester_email: "bad" })
    end
    assert_response :unprocessable_entity
    assert_select ".errors li", "Subject can't be blank"
    assert_select ".errors li", "Requester email is invalid"
  end

  test "an assignee that does not exist shows an error instead of crashing" do
    sign_in_as users(:agent)

    assert_no_difference "Ticket.count" do
      post tickets_path, params: valid_params.deep_merge(ticket: { assigned_to_id: 999_999 })
    end
    assert_response :unprocessable_entity
    assert_select ".errors li", "Assigned to must be an existing user"
  end

  # --- edit / update ---

  test "edit shows the form filled in" do
    sign_in_as users(:agent)
    ticket = tickets(:open_ticket)

    get edit_ticket_path(ticket)
    assert_response :success
    assert_select "input[name='ticket[subject]'][value=?]", ticket.subject
  end

  test "updates ticket fields, priority and assignee" do
    sign_in_as users(:agent)
    ticket = tickets(:pending_ticket)

    patch ticket_path(ticket), params: { ticket: { subject: "New subject", priority: "urgent",
                                                   assigned_to_id: users(:admin).id } }
    assert_redirected_to ticket_path(ticket)

    ticket.reload
    assert_equal "New subject", ticket.subject
    assert ticket.urgent?
    assert_equal users(:admin), ticket.assigned_to
  end

  test "can unassign a ticket" do
    sign_in_as users(:agent)
    ticket = tickets(:open_ticket)

    patch ticket_path(ticket), params: { ticket: { assigned_to_id: "" } }
    assert_nil ticket.reload.assigned_to
  end

  test "invalid update shows errors and saves nothing" do
    sign_in_as users(:agent)
    ticket = tickets(:open_ticket)

    patch ticket_path(ticket), params: { ticket: { subject: "", priority: "critical" } }
    assert_response :unprocessable_entity
    assert_select ".errors li", "Subject can't be blank"
    assert_select ".errors li", "Priority is not included in the list"
    assert_equal "Cannot log in to the portal", ticket.reload.subject
  end

  test "status cannot be changed through the edit form" do
    sign_in_as users(:agent)
    ticket = tickets(:closed_ticket)

    patch ticket_path(ticket), params: { ticket: { status: "open", subject: "Still closed" } }
    ticket.reload
    assert ticket.closed?
    assert_equal "Still closed", ticket.subject
  end

  # --- history ---

  test "creating a ticket records who created and assigned it" do
    sign_in_as users(:admin)

    post tickets_path, params: valid_params
    events = Ticket.order(:id).last.events

    assert_equal %w[created assigned], events.map(&:kind)
    assert events.all? { |event| event.user == users(:admin) }
  end

  test "changing the assignee in the edit form records who did it" do
    sign_in_as users(:agent)
    ticket = tickets(:open_ticket)

    assert_difference "ticket.events.count", 1 do
      patch ticket_path(ticket), params: { ticket: { assigned_to_id: users(:admin).id } }
    end
    event = ticket.events.last
    assert_equal "Assignee changed from Ali Agent to Ada Admin", event.description
    assert_equal users(:agent), event.user
  end

  test "a failed update records no history" do
    sign_in_as users(:agent)

    assert_no_difference "TicketEvent.count" do
      patch ticket_path(tickets(:open_ticket)), params: { ticket: { subject: "", assigned_to_id: users(:admin).id } }
    end
  end

  test "show lists the history oldest first with user and time" do
    sign_in_as users(:agent)
    created_at = Time.zone.local(2026, 11, 2, 9, 0, 0)
    ticket = travel_to(created_at) do
      Ticket.create!(subject: "History test", description: "d", requester_name: "R", requester_email: "r@example.com")
    end
    travel_to(created_at + 1.hour) { ticket.transition_to("pending") }

    get ticket_path(ticket)
    assert_select ".history li", 2
    assert_select ".history li:nth-child(1) .event-description", "Ticket created"
    assert_select ".history li:nth-child(1) .actor", "Ali Agent"
    assert_select ".history li:nth-child(1) time[datetime=?]", created_at.iso8601
    assert_select ".history li:nth-child(2) .event-description", "Status changed from open to pending"
  end

  test "show says when there is no history" do
    sign_in_as users(:agent)

    get ticket_path(tickets(:open_ticket)) # fixtures have no events
    assert_select "p.empty", "No history yet."
  end
end
