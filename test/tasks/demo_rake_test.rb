require "test_helper"
require "rake"

class DemoRakeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    @task = Rake::Task["demo:seed"]
    @task.reenable
    @second_agent = User.create!(name: "Defne Demo", email_address: "defne@example.com",
                                 password: "password", role: :agent)
  end

  def seed(now = Time.current)
    DemoTickets.seed(now: now, out: StringIO.new)
  end

  def demo_tickets
    DemoTickets::TICKETS.map do |data|
      Ticket.find_by!(subject: data[:subject], requester_email: data[:requester_email])
    end
  end

  test "the task creates every demo ticket and reports it" do
    assert_difference "Ticket.count", DemoTickets::TICKETS.size do
      assert_output(/#{DemoTickets::TICKETS.size} demo ticket\(s\) created/) { @task.invoke }
    end
  end

  test "demo tickets cover every status and priority and use only existing users" do
    seed
    tickets = demo_tickets

    assert_equal Ticket.statuses.keys.sort, tickets.map(&:status).uniq.sort
    assert_equal Ticket.priorities.keys.sort, tickets.map(&:priority).uniq.sort
    assert tickets.all? { |t| t.assigned_to.nil? || User.exists?(t.assigned_to_id) }
    assert_includes tickets.map(&:assigned_to), @second_agent
  end

  test "each step is recorded in the history by the normal callbacks" do
    seed

    DemoTickets::TICKETS.zip(demo_tickets).each do |data, ticket|
      create_step = data[:steps].first
      expected = data[:steps].size + (create_step[3] ? 1 : 0)
      assert_equal expected, ticket.events.count, data[:subject]
      assert_equal "created", ticket.events.first.kind
      assert_equal (data[:steps].reverse.find { |s| s[2] == :status }&.dig(3) || :open).to_s, ticket.status
    end
  end

  test "history times are in the past and in order" do
    now = Time.current
    seed(now)

    demo_tickets.each do |ticket|
      times = ticket.events.map(&:created_at)
      assert_equal times.sort, times
      assert times.all? { |t| t < now }
    end
  end

  test "solved demo tickets are not due for auto-close right after seeding" do
    seed
    solved = demo_tickets.select(&:solved?)

    assert solved.any?
    assert_empty Ticket.ready_to_auto_close.where(id: solved.map(&:id))
  end

  test "tickets closed by System were closed 72 hours after they were solved" do
    seed
    system_closed = demo_tickets.select { |t| t.closed? && t.events.last.user.nil? }

    assert system_closed.any?
    system_closed.each do |ticket|
      solved_at = ticket.events.find { |e| e.description == "Status changed from open to solved" }.created_at
      assert_equal solved_at + Ticket::AUTO_CLOSE_AFTER, ticket.events.last.created_at
      assert_equal "System", ticket.events.last.actor_name
    end
  end

  test "running again adds nothing and leaves existing tickets alone" do
    existing = tickets(:open_ticket)
    before = existing.attributes

    seed
    assert_no_difference [ "Ticket.count", "TicketEvent.count" ] do
      assert_equal 0, seed
    end
    assert_equal before, existing.reload.attributes
  end

  test "refuses to run without any users" do
    User.destroy_all

    assert_raises(DemoTickets::NoUsersError) { seed }
    assert_equal 0, Ticket.where(requester_email: DemoTickets::TICKETS.first[:requester_email]).count
  end
end
