module TicketsHelper
  # Turkish labels for the stored values. The stored values themselves
  # ("open", "high", ...) do not change.
  STATUS_LABELS = { "open" => "Açık", "pending" => "Beklemede", "solved" => "Çözüldü", "closed" => "Kapalı" }.freeze
  PRIORITY_LABELS = { "low" => "Düşük", "normal" => "Normal", "high" => "Yüksek", "urgent" => "Acil" }.freeze
  # Button text for moving a ticket *to* a status (see Ticket::TRANSITIONS).
  TRANSITION_LABELS = { "open" => "Yeniden aç", "pending" => "Beklemeye al",
                        "solved" => "Çözüldü olarak işaretle", "closed" => "Kapat" }.freeze
  EVENT_ICONS = { "created" => "plus-circle", "assigned" => "user-check", "status_changed" => "refresh" }.freeze

  def status_label(status)
    STATUS_LABELS.fetch(status.to_s, status.to_s.humanize)
  end

  def priority_label(priority)
    PRIORITY_LABELS.fetch(priority.to_s, priority.to_s.humanize)
  end

  def transition_label(status)
    TRANSITION_LABELS.fetch(status.to_s, status_label(status))
  end

  # Small coloured label, e.g. <span class="badge status-open">Açık</span>
  def status_badge(ticket)
    tag.span(status_label(ticket.status), class: "badge status-#{ticket.status}")
  end

  def priority_badge(ticket)
    tag.span(priority_label(ticket.priority), class: "badge priority-#{ticket.priority}")
  end

  def assignee_name(ticket)
    ticket.assigned_to&.name || "Atanmamış"
  end

  # Avatar and name of the assignee, or a muted "Atanmamış".
  def assignee_with_avatar(ticket)
    if ticket.assigned_to
      tag.span(class: "person") { safe_join([ avatar(ticket.assigned_to.name, size: :sm), tag.span(ticket.assigned_to.name, class: "person-name") ]) }
    else
      tag.span(assignee_name(ticket), class: "person person-empty")
    end
  end

  # Who made a history change; events without a user were made by the system.
  def event_actor_name(event)
    event.user&.name || "Sistem"
  end

  def event_icon(event)
    icon(EVENT_ICONS.fetch(event.kind, "clock"), size: 14)
  end
end
