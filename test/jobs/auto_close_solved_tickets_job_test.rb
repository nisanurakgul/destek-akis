require "test_helper"

class AutoCloseSolvedTicketsJobTest < ActiveJob::TestCase
  SOLVED_AT = Time.zone.local(2026, 11, 2, 9, 0, 0)

  setup do
    # Fixture timestamps depend on when fixtures were loaded; use only tickets
    # created in each test so the times are exact.
    Ticket.delete_all
  end

  def create_ticket(subject = "Printer is not working")
    Ticket.create!(subject: subject, description: "Paper jam.",
                   requester_name: "Zeynep Arslan", requester_email: "zeynep@example.com")
  end

  # Creates a ticket and marks it solved at the given time.
  def solved_ticket_at(time, subject = "Printer is not working")
    travel_to(time) do
      ticket = create_ticket(subject)
      assert ticket.transition_to("solved")
      ticket
    end
  end

  def run_job_at(time)
    travel_to(time) { AutoCloseSolvedTicketsJob.perform_now }
  end

  # --- the 72 hour boundary ---

  test "a solved ticket is NOT closed after 71 hours 59 minutes" do
    ticket = solved_ticket_at(SOLVED_AT)

    assert_equal 0, run_job_at(SOLVED_AT + 71.hours + 59.minutes)
    assert ticket.reload.solved?
  end

  test "a solved ticket is closed after exactly 72 hours" do
    ticket = solved_ticket_at(SOLVED_AT)

    assert_equal 1, run_job_at(SOLVED_AT + 72.hours)
    assert ticket.reload.closed?
  end

  test "a solved ticket is closed when the job runs later than 72 hours" do
    ticket = solved_ticket_at(SOLVED_AT)

    run_job_at(SOLVED_AT + 100.hours)
    assert ticket.reload.closed?
  end

  test "running the job before and after the boundary closes it only once the time is up" do
    ticket = solved_ticket_at(SOLVED_AT)

    run_job_at(SOLVED_AT + 71.hours + 59.minutes)
    assert ticket.reload.solved?

    run_job_at(SOLVED_AT + 72.hours)
    assert ticket.reload.closed?
  end

  # --- changes within the 72 hours ---

  test "a ticket reopened before 72 hours is not closed" do
    ticket = solved_ticket_at(SOLVED_AT)
    travel_to(SOLVED_AT + 10.hours) { assert ticket.transition_to("open") }

    assert_equal 0, run_job_at(SOLVED_AT + 72.hours)
    assert ticket.reload.open?

    assert_equal 0, run_job_at(SOLVED_AT + 500.hours)
    assert ticket.reload.open?, "an open ticket is never auto-closed"
  end

  test "reopening and solving again restarts the 72 hours" do
    ticket = solved_ticket_at(SOLVED_AT)
    travel_to(SOLVED_AT + 10.hours) do
      assert ticket.transition_to("open")
      assert ticket.transition_to("solved")
    end

    run_job_at(SOLVED_AT + 72.hours)
    assert ticket.reload.solved?, "only 62 hours since it was solved again"

    run_job_at(SOLVED_AT + 10.hours + 71.hours + 59.minutes)
    assert ticket.reload.solved?

    run_job_at(SOLVED_AT + 10.hours + 72.hours)
    assert ticket.reload.closed?
  end

  test "editing a solved ticket restarts the 72 hours" do
    ticket = solved_ticket_at(SOLVED_AT)
    travel_to(SOLVED_AT + 48.hours) { assert ticket.update(priority: "high") }

    run_job_at(SOLVED_AT + 72.hours)
    assert ticket.reload.solved?

    run_job_at(SOLVED_AT + 48.hours + 72.hours)
    assert ticket.reload.closed?
  end

  # --- other statuses ---

  test "open, pending and closed tickets are left alone however old they are" do
    open_ticket, pending_ticket, closed_ticket = travel_to(SOLVED_AT) do
      open_ticket = create_ticket("open")
      pending_ticket = create_ticket("pending")
      pending_ticket.transition_to("pending")
      closed_ticket = create_ticket("closed")
      closed_ticket.transition_to("solved")
      closed_ticket.transition_to("closed")
      [ open_ticket, pending_ticket, closed_ticket ]
    end
    closed_updated_at = closed_ticket.reload.updated_at

    assert_equal 0, run_job_at(SOLVED_AT + 1000.hours)
    assert open_ticket.reload.open?
    assert pending_ticket.reload.pending?
    assert closed_ticket.reload.closed?
    assert_equal closed_updated_at, closed_ticket.updated_at, "closed ticket must not be saved again"
  end

  test "closes only the tickets whose time is up and returns how many" do
    old_one = solved_ticket_at(SOLVED_AT, "old one")
    old_two = solved_ticket_at(SOLVED_AT + 1.hour, "old two")
    recent = solved_ticket_at(SOLVED_AT + 30.hours, "recent")

    assert_equal 2, run_job_at(SOLVED_AT + 1.hour + 72.hours)
    assert old_one.reload.closed?
    assert old_two.reload.closed?
    assert recent.reload.solved?
  end

  test "the closed ticket's updated_at is the time it was auto-closed" do
    ticket = solved_ticket_at(SOLVED_AT)

    run_job_at(SOLVED_AT + 72.hours)
    assert_equal SOLVED_AT + 72.hours, ticket.reload.updated_at
  end

  # --- safety re-check ---

  # Simulates a ticket that was found by the query but reopened by someone
  # before the job got to it.
  class StaleCandidatesJob < AutoCloseSolvedTicketsJob
    cattr_accessor :ticket_ids

    private
      def candidates(_now)
        Ticket.where(id: ticket_ids)
      end
  end

  test "a ticket reopened after the query but before closing is left open" do
    ticket = solved_ticket_at(SOLVED_AT)
    travel_to(SOLVED_AT + 71.hours) { ticket.transition_to("open") }
    StaleCandidatesJob.ticket_ids = [ ticket.id ]

    closed_count = travel_to(SOLVED_AT + 72.hours) { StaleCandidatesJob.perform_now }

    assert_equal 0, closed_count
    assert ticket.reload.open?
  end

  # The case the re-check inside the lock is really for: the ticket is solved
  # again, so closing would be an allowed transition, but its 72 hours restarted.
  test "a ticket reopened and solved again after the query is not closed early" do
    ticket = solved_ticket_at(SOLVED_AT)
    travel_to(SOLVED_AT + 71.hours) do
      ticket.transition_to("open")
      ticket.transition_to("solved")
    end
    StaleCandidatesJob.ticket_ids = [ ticket.id ]

    closed_count = travel_to(SOLVED_AT + 72.hours) { StaleCandidatesJob.perform_now }

    assert_equal 0, closed_count
    assert ticket.reload.solved?
  end

  # --- scheduling ---

  test "the job is scheduled hourly in production" do
    config = YAML.load_file(Rails.root.join("config/recurring.yml"))
    task = config.dig("production", "auto_close_solved_tickets")

    assert_equal "AutoCloseSolvedTicketsJob", task["class"]
    assert_equal "every hour", task["schedule"]
    assert_equal AutoCloseSolvedTicketsJob, task["class"].constantize
  end

  test "the job can be enqueued" do
    assert_enqueued_with(job: AutoCloseSolvedTicketsJob) do
      AutoCloseSolvedTicketsJob.perform_later
    end
  end
end
