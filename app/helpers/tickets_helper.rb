module TicketsHelper
  # Small coloured label, e.g. <span class="badge status-open">Open</span>
  def status_badge(ticket)
    tag.span(ticket.status.humanize, class: "badge status-#{ticket.status}")
  end

  def priority_badge(ticket)
    tag.span(ticket.priority.humanize, class: "badge priority-#{ticket.priority}")
  end

  def assignee_name(ticket)
    ticket.assigned_to&.name || "Unassigned"
  end
end
