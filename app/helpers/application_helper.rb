module ApplicationHelper
  ROLE_LABELS = { "agent" => "Destek temsilcisi", "admin" => "Yönetici" }.freeze

  # Inner SVG markup for the small line icons used in the interface.
  # These are fixed strings written here, never user input.
  ICONS = {
    "home" => '<path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><path d="M9 22V12h6v10"/>',
    "inbox" => '<path d="M22 12h-6l-2 3h-4l-2-3H2"/><path d="M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z"/>',
    "users" => '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>',
    "user-plus" => '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M19 8v6"/><path d="M22 11h-6"/>',
    "user-check" => '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="m16 11 2 2 4-4"/>',
    "plus" => '<path d="M12 5v14"/><path d="M5 12h14"/>',
    "plus-circle" => '<circle cx="12" cy="12" r="10"/><path d="M12 8v8"/><path d="M8 12h8"/>',
    "pencil" => '<path d="M17 3a2.85 2.85 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z"/>',
    "log-out" => '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><path d="m16 17 5-5-5-5"/><path d="M21 12H9"/>',
    "arrow-left" => '<path d="m12 19-7-7 7-7"/><path d="M19 12H5"/>',
    "arrow-right" => '<path d="M5 12h14"/><path d="m12 5 7 7-7 7"/>',
    "check-circle" => '<circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-4"/>',
    "alert-circle" => '<circle cx="12" cy="12" r="10"/><path d="M12 8v4"/><path d="M12 16h.01"/>',
    "clock" => '<circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/>',
    "lock" => '<rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>',
    "refresh" => '<path d="M21 12a9 9 0 0 0-9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/><path d="M3 12a9 9 0 0 0 9 9 9.75 9.75 0 0 0 6.74-2.74L21 16"/><path d="M16 16h5v5"/>',
    "mail" => '<rect x="2" y="4" width="20" height="16" rx="2"/><path d="m22 7-10 6L2 7"/>',
    "chevron-right" => '<path d="m9 18 6-6-6-6"/>',
    "flow" => '<path d="M3 12h4l3-7 4 14 3-7h4"/>'
  }.freeze

  # Inline SVG icon, e.g. icon("inbox"). Decorative: hidden from screen readers.
  def icon(name, size: 18, css_class: nil)
    tag.svg(ICONS.fetch(name).html_safe,
            class: [ "icon", css_class ], width: size, height: size, viewBox: "0 0 24 24",
            fill: "none", stroke: "currentColor", "stroke-width": 2,
            "stroke-linecap": "round", "stroke-linejoin": "round",
            "aria-hidden": true, focusable: false)
  end

  # Round avatar with the user's initials. The initials come from a data
  # attribute (shown with CSS), so they are not part of the element's text.
  def avatar(name, size: :md)
    initials = name.to_s.split.first(2).map { |part| part[0] }.join.upcase
    tag.span(class: "avatar avatar-#{size}", data: { initials: initials }, "aria-hidden": true)
  end

  def role_label(role)
    ROLE_LABELS.fetch(role.to_s, role.to_s.humanize)
  end

  # 16.10.2026 14:30
  def format_datetime(time)
    time.strftime("%d.%m.%Y %H:%M")
  end

  # Sidebar link; marks the current section with aria-current for styling and screen readers.
  def nav_link(label, path, icon_name, active:)
    link_to path, class: "nav-link", "aria-current": (active ? "page" : nil) do
      safe_join([ icon(icon_name), tag.span(label) ])
    end
  end
end
