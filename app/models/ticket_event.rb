# One line in a ticket's history: what happened, who did it, and when (created_at).
# Events are created by Ticket callbacks; see Ticket#record_creation_events.
class TicketEvent < ApplicationRecord
  belongs_to :ticket
  # nil when the change was made by the system (e.g. AutoCloseSolvedTicketsJob).
  belongs_to :user, optional: true

  enum :kind, { created: "created", assigned: "assigned", status_changed: "status_changed" },
       validate: true

  validates :description, presence: true

  def actor_name
    user&.name || "System"
  end
end
