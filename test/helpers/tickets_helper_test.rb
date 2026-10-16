require "test_helper"

class TicketsHelperTest < ActionView::TestCase
  test "every status and priority has a Turkish label" do
    Ticket.statuses.each_key { |status| assert TicketsHelper::STATUS_LABELS.key?(status), status }
    Ticket.priorities.each_key { |priority| assert TicketsHelper::PRIORITY_LABELS.key?(priority), priority }
  end

  test "every allowed transition has a button label" do
    Ticket::TRANSITIONS.values.flatten.uniq.each do |status|
      assert TicketsHelper::TRANSITION_LABELS.key?(status), status
    end
  end

  test "badges keep the stored value in the class and show the Turkish label" do
    ticket = tickets(:open_ticket)

    assert_dom_equal %(<span class="badge status-open">Açık</span>), status_badge(ticket)
    assert_dom_equal %(<span class="badge priority-high">Yüksek</span>), priority_badge(ticket)
  end

  test "assignee name falls back to Atanmamış" do
    assert_equal "Ali Agent", assignee_name(tickets(:open_ticket))
    assert_equal "Atanmamış", assignee_name(tickets(:pending_ticket))
  end

  test "events without a user are shown as Sistem" do
    assert_equal "Sistem", event_actor_name(TicketEvent.new(user: nil))
    assert_equal "Ada Admin", event_actor_name(TicketEvent.new(user: users(:admin)))
  end
end
