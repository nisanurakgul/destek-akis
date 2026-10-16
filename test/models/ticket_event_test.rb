require "test_helper"

class TicketEventTest < ActiveSupport::TestCase
  NOW = Time.zone.local(2026, 11, 2, 9, 30, 0)

  setup do
    # Simulates a signed-in user, as the Authentication concern does for requests.
    Current.session = users(:agent).sessions.create!
  end

  def create_ticket(**attributes)
    Ticket.create!({ subject: "VPN does not connect", description: "Error 809.",
                     requester_name: "Selin Koç", requester_email: "selin@example.com" }.merge(attributes))
  end

  # --- creation ---

  test "creating a ticket records a created event with user and time" do
    ticket = travel_to(NOW) { create_ticket }

    assert_equal 1, ticket.events.count
    event = ticket.events.first
    assert event.created?
    assert_equal "Ticket created", event.description
    assert_equal users(:agent), event.user
    assert_equal NOW, event.created_at
  end

  test "creating an assigned ticket also records the assignment" do
    ticket = create_ticket(assigned_to: users(:admin))

    assert_equal %w[created assigned], ticket.events.map(&:kind)
    assert_equal "Assigned to Ada Admin", ticket.events.last.description
  end

  test "a ticket that fails validation records no event" do
    assert_no_difference "TicketEvent.count" do
      Ticket.create(subject: "")
    end
  end

  # --- status changes ---

  test "a status change records an event" do
    ticket = create_ticket

    travel_to(NOW) { assert ticket.transition_to("solved") }

    event = ticket.events.last
    assert event.status_changed?
    assert_equal "Status changed from open to solved", event.description
    assert_equal users(:agent), event.user
    assert_equal NOW, event.created_at
  end

  test "a rejected status change records nothing" do
    ticket = tickets(:closed_ticket)

    assert_no_difference "TicketEvent.count" do
      assert_not ticket.transition_to("open")
    end
  end

  test "moving to the same status records nothing" do
    ticket = tickets(:closed_ticket)

    assert_no_difference "TicketEvent.count" do
      assert ticket.transition_to("closed")
    end
  end

  # --- assignment changes ---

  test "assigning, reassigning and unassigning each record an event" do
    ticket = tickets(:pending_ticket) # starts unassigned

    ticket.update!(assigned_to: users(:agent))
    ticket.update!(assigned_to: users(:admin))
    ticket.update!(assigned_to: nil)

    assert_equal [
      "Assignee changed from Unassigned to Ali Agent",
      "Assignee changed from Ali Agent to Ada Admin",
      "Assignee changed from Ada Admin to Unassigned"
    ], ticket.events.map(&:description)
    assert ticket.events.all?(&:assigned?)
  end

  test "editing other fields records no event" do
    ticket = tickets(:open_ticket)

    assert_no_difference "TicketEvent.count" do
      ticket.update!(subject: "New subject", priority: "low")
    end
  end

  test "changing status and assignee in one save records both" do
    ticket = tickets(:open_ticket)

    ticket.update!(status: "pending", assigned_to: users(:admin))
    assert_equal %w[status_changed assigned], ticket.events.map(&:kind)
  end

  # --- order, actor and constraints ---

  test "events are listed oldest first" do
    ticket = travel_to(NOW) { create_ticket }
    travel_to(NOW + 2.hours) { ticket.transition_to("pending") }
    travel_to(NOW + 1.day) { ticket.update!(assigned_to: users(:admin)) }

    events = ticket.events.reload
    assert_equal [ NOW, NOW + 2.hours, NOW + 1.day ], events.map(&:created_at)
    assert_equal %w[created status_changed assigned], events.map(&:kind)
  end

  test "without a signed-in user the event is recorded as System" do
    Current.reset
    ticket = create_ticket

    event = ticket.events.first
    assert_nil event.user
    assert_equal "System", event.actor_name
  end

  test "rejects an unknown kind and a blank description" do
    event = TicketEvent.new(ticket: tickets(:open_ticket), kind: "deleted", description: "")
    assert_not event.valid?
    assert_includes event.errors[:kind], "is not included in the list"
    assert_includes event.errors[:description], "can't be blank"

    assert_raises(ActiveRecord::StatementInvalid) do
      create_ticket.events.first.update_column(:kind, "deleted")
    end
  end

  test "deleting a user keeps their events and shows System" do
    ticket = create_ticket
    users(:agent).destroy

    event = ticket.events.reload.first
    assert_nil event.user
    assert_equal "System", event.actor_name
  end
end
