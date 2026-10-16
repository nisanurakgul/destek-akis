require "test_helper"

class TicketTest < ActiveSupport::TestCase
  def build_ticket(**attributes)
    Ticket.new({
      subject: "Printer is not working",
      description: "The office printer shows a paper jam error.",
      requester_name: "Zeynep Arslan",
      requester_email: "zeynep@example.com"
    }.merge(attributes))
  end

  # --- creating tickets ---

  test "valid with the required fields" do
    assert build_ticket.valid?
  end

  test "new tickets start open with normal priority and no assignee" do
    ticket = build_ticket
    ticket.save!

    assert ticket.open?
    assert ticket.normal?
    assert_nil ticket.assigned_to
  end

  test "requires subject, description, requester name and requester email" do
    ticket = Ticket.new
    assert_not ticket.valid?

    %i[subject description requester_name requester_email].each do |field|
      assert_includes ticket.errors[field], "can't be blank", "#{field} should be required"
    end
  end

  test "limits subject and requester name length" do
    assert_not build_ticket(subject: "a" * 201).valid?
    assert_not build_ticket(requester_name: "a" * 101).valid?
  end

  test "requires a valid requester email and normalizes it" do
    assert_not build_ticket(requester_email: "not-an-email").valid?
    assert_equal "zeynep@example.com", build_ticket(requester_email: " Zeynep@Example.COM ").requester_email
  end

  test "a new ticket cannot be created in another status" do
    ticket = build_ticket(status: "solved")
    assert_not ticket.valid?
    assert_includes ticket.errors[:status], "must be open for a new ticket"
  end

  # --- priority ---

  test "accepts every priority" do
    %w[low normal high urgent].each do |priority|
      assert build_ticket(priority: priority).valid?, "#{priority} should be valid"
    end
  end

  test "rejects an unknown priority" do
    ticket = build_ticket(priority: "critical")
    assert_not ticket.valid?
    assert_equal [ "is not included in the list" ], ticket.errors[:priority]
  end

  # --- assignment ---

  test "can be assigned to a user" do
    ticket = build_ticket(assigned_to: users(:agent))
    ticket.save!

    assert_equal users(:agent), ticket.reload.assigned_to
    assert_includes users(:agent).assigned_tickets, ticket
  end

  test "assignee must be an existing user" do
    ticket = build_ticket(assigned_to_id: 999_999)
    assert_not ticket.valid?
    assert_includes ticket.errors[:assigned_to], "must be an existing user"

    assert build_ticket(assigned_to_id: nil).valid?, "unassigned is still allowed"
  end

  test "deleting a user leaves their tickets unassigned" do
    ticket = tickets(:open_ticket)
    users(:agent).destroy

    assert_nil ticket.reload.assigned_to_id
  end

  # --- helpers for status transitions ---

  # Reads the saved status straight from the database, without using
  # (or refreshing) the Ruby object we are testing.
  def db_status(ticket)
    Ticket.where(id: ticket.id).pick(:status)
  end

  # Moves the ticket one step and checks the step really was saved.
  def assert_transition(ticket, new_status)
    assert ticket.transition_to(new_status),
           "#{ticket.status_in_database} -> #{new_status} should be allowed, errors: #{ticket.errors.full_messages}"
    assert_equal new_status, db_status(ticket), "database should now say #{new_status}"
  end

  # Tries a forbidden change and checks nothing was saved, then reloads the
  # object and checks it is back to the saved status. Returns the status error
  # messages, copied before the reload, so callers can inspect them further.
  def assert_rejected(ticket, new_status, message: nil)
    saved_status = db_status(ticket)

    assert_equal false, ticket.transition_to(new_status), "#{saved_status} -> #{new_status} should be rejected"

    # Check error messages before reload.
    status_errors = ticket.errors[:status].dup
    assert_not_empty status_errors
    assert_includes status_errors, message if message

    assert_equal saved_status, db_status(ticket), "database must still say #{saved_status}"

    # After reload the object must match the old saved status again.
    ticket.reload
    assert_equal saved_status, ticket.status, "after reload the object must be back to #{saved_status}"
    assert_not ticket.changed?, "after reload there must be no unsaved changes"

    status_errors
  end

  # --- status transitions: allowed ---

  test "open can move to pending" do
    assert_transition tickets(:open_ticket), "pending"
  end

  test "open can move to solved" do
    assert_transition tickets(:open_ticket), "solved"
  end

  test "pending can move back to open" do
    assert_transition tickets(:pending_ticket), "open"
  end

  test "pending can move to solved" do
    assert_transition tickets(:pending_ticket), "solved"
  end

  test "solved can be reopened" do
    assert_transition tickets(:solved_ticket), "open"
  end

  test "solved can be closed" do
    assert_transition tickets(:solved_ticket), "closed"
  end

  test "a full life cycle, checking every step" do
    ticket = build_ticket
    ticket.save!
    assert_equal "open", db_status(ticket)

    assert_transition ticket, "pending"
    assert_transition ticket, "open"
    assert_transition ticket, "solved"
    assert_transition ticket, "open"    # reopened
    assert_transition ticket, "solved"
    assert_transition ticket, "closed"
    assert_rejected ticket, "open"      # closed is final
  end

  test "a rejected step in the middle of a sequence does not move the ticket" do
    ticket = tickets(:open_ticket)

    assert_transition ticket, "pending"
    assert_rejected ticket, "closed"
    ticket.reload
    assert_transition ticket, "solved"
    assert_transition ticket, "closed"
  end

  # --- status transitions: rejected ---

  test "closed cannot move to open" do
    assert_rejected tickets(:closed_ticket), "open", message: "cannot change from closed to open"
  end

  test "closed cannot move to any other status" do
    %w[open pending solved].each do |new_status|
      # Fresh object each time: a failed attempt leaves its value in memory.
      assert_rejected Ticket.find(tickets(:closed_ticket).id), new_status,
                      message: "cannot change from closed to #{new_status}"
    end
  end

  test "open cannot skip straight to closed" do
    assert_rejected tickets(:open_ticket), "closed", message: "cannot change from open to closed"
  end

  test "pending cannot skip straight to closed" do
    assert_rejected tickets(:pending_ticket), "closed", message: "cannot change from pending to closed"
  end

  test "solved cannot move to pending" do
    assert_rejected tickets(:solved_ticket), "pending", message: "cannot change from solved to pending"
  end

  test "every transition not in the table is rejected" do
    Ticket::TRANSITIONS.each do |from, allowed|
      (Ticket.statuses.keys - allowed - [ from ]).each do |to|
        ticket = build_ticket
        ticket.save!
        ticket.update_column(:status, from) # put it in the starting status directly

        assert_rejected ticket, to
      end
    end
  end

  test "an unknown status is rejected with a single error" do
    ticket = tickets(:open_ticket)

    status_errors = assert_rejected(ticket, "archived")
    assert_equal [ "is not included in the list" ], status_errors
  end

  test "the rule also applies to a plain update" do
    ticket = tickets(:closed_ticket)

    assert_equal false, ticket.update(status: "open")
    assert_equal "closed", db_status(ticket)
  end

  test "the bang method raises and saves nothing" do
    ticket = tickets(:closed_ticket)

    assert_raises(ActiveRecord::RecordInvalid) { ticket.open! }
    assert_equal "closed", db_status(ticket)
  end

  # --- what the object looks like after a rejected change ---

  test "after a rejected change memory shows the new value until reload" do
    ticket = tickets(:closed_ticket)

    assert_equal false, ticket.transition_to("open")

    # Before reload: the Ruby object still holds the rejected value...
    assert_equal "open", ticket.status
    assert ticket.status_changed?
    assert_equal [ "closed", "open" ], ticket.changes["status"]
    # ...but the database (read independently, two ways) does not.
    assert_equal "closed", db_status(ticket)
    assert Ticket.find(ticket.id).closed?

    # After reload: the object is back to the saved status with no pending change.
    ticket.reload
    assert_equal "closed", ticket.status
    assert_not ticket.changed?

    # Note: reload refreshes attributes but does NOT clear old error messages;
    # they stay until the next validation run.
    assert_not_empty ticket.errors
    assert ticket.valid?
    assert_empty ticket.errors
  end

  test "a rejected change does not touch updated_at" do
    ticket = tickets(:closed_ticket)
    updated_at = Ticket.where(id: ticket.id).pick(:updated_at)

    travel 1.hour do
      assert_rejected ticket, "open"
    end
    assert_equal updated_at, Ticket.where(id: ticket.id).pick(:updated_at)
  end

  # --- same status ---

  test "moving to the status it already has succeeds but saves nothing" do
    Ticket.statuses.each_key do |status|
      ticket = build_ticket
      ticket.save!
      ticket.update_column(:status, status)
      ticket.reload
      updated_at = ticket.updated_at

      travel 1.hour do
        assert ticket.transition_to(status), "#{status} -> #{status} should be a harmless no-op"
      end
      assert_empty ticket.errors
      assert_equal status, db_status(ticket)
      assert_equal updated_at, ticket.reload.updated_at, "no change means no UPDATE"
    end
  end

  test "saving other fields without changing the status is always fine" do
    ticket = tickets(:closed_ticket)

    assert ticket.update(priority: "low")
    assert_equal "closed", db_status(ticket)
    assert_equal "low", Ticket.where(id: ticket.id).pick(:priority)
  end

  test "every status in the transition table is a real status" do
    assert_equal Ticket.statuses.keys.sort, Ticket::TRANSITIONS.keys.sort
    Ticket::TRANSITIONS.values.flatten.each do |target|
      assert_includes Ticket.statuses.keys, target
    end
  end

  test "can_transition_to? follows the table" do
    assert tickets(:open_ticket).can_transition_to?("pending")
    assert tickets(:solved_ticket).can_transition_to?(:closed)
    assert_not tickets(:closed_ticket).can_transition_to?("open")
  end

  # --- database constraints ---

  test "database refuses an unknown status or priority even when validations are skipped" do
    ticket = tickets(:open_ticket)

    assert_raises(ActiveRecord::StatementInvalid) { ticket.update_column(:status, "archived") }
    assert_raises(ActiveRecord::StatementInvalid) { ticket.update_column(:priority, "critical") }
  end

  test "database refuses an assignee that does not exist" do
    assert_raises(ActiveRecord::InvalidForeignKey) do
      tickets(:open_ticket).update_column(:assigned_to_id, 999_999)
    end
  end
end
