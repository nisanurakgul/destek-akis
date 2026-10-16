class Ticket < ApplicationRecord
  # Allowed status changes: "from" => [statuses it may move to].
  # Anything not listed here is rejected by the validation below.
  #
  #   open    -> pending (waiting for the customer) or solved
  #   pending -> open (customer replied) or solved
  #   solved  -> open (problem came back) or closed
  #   closed  -> nothing; a closed ticket is final
  TRANSITIONS = {
    "open"    => %w[pending solved],
    "pending" => %w[open solved],
    "solved"  => %w[open closed],
    "closed"  => []
  }.freeze

  # A solved ticket that has not changed for this long is closed automatically
  # by AutoCloseSolvedTicketsJob. Any change (reopening, editing) moves
  # updated_at forward and so restarts the countdown.
  AUTO_CLOSE_AFTER = 72.hours

  belongs_to :assigned_to, class_name: "User", optional: true
  # History, oldest first. Ordered by id as well so events saved in the same second keep their order.
  has_many :events, -> { order(:created_at, :id) }, class_name: "TicketEvent", dependent: :destroy

  enum :priority, { low: "low", normal: "normal", high: "high", urgent: "urgent" },
       default: :normal, validate: true
  enum :status, { open: "open", pending: "pending", solved: "solved", closed: "closed" },
       default: :open, validate: true

  # Solved tickets whose last change is at least AUTO_CLOSE_AFTER ago.
  scope :ready_to_auto_close, ->(now = Time.current) { solved.where(updated_at: ..(now - AUTO_CLOSE_AFTER)) }

  normalizes :requester_email, with: ->(e) { e.strip.downcase }

  validates :subject, presence: true, length: { maximum: 200 }
  validates :description, presence: true
  validates :requester_name, presence: true, length: { maximum: 100 }
  validates :requester_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  # belongs_to optional: true does not check that the user exists; without this
  # a bad assigned_to_id would only fail at the database foreign key.
  validates :assigned_to, presence: { message: "must be an existing user" }, if: :assigned_to_id?
  validate :new_tickets_start_open, on: :create
  validate :status_change_is_allowed, on: :update

  # History is recorded in the same database transaction as the ticket change,
  # so a ticket is never saved without its event (or the other way round).
  after_create :record_creation_events
  after_update :record_change_events

  # Can this ticket move from its current (saved) status to new_status?
  def can_transition_to?(new_status)
    TRANSITIONS.fetch(status_in_database, []).include?(new_status.to_s)
  end

  # Changes the status and saves. Returns true on success, false (with
  # errors on :status) when the change is not allowed.
  def transition_to(new_status)
    self.status = new_status
    save
  end

  private
    def record_creation_events
      record_event :created, "Ticket created"
      record_event :assigned, "Assigned to #{assigned_to.name}" if assigned_to
    end

    def record_change_events
      if saved_change_to_status?
        from, to = saved_change_to_status
        record_event :status_changed, "Status changed from #{from} to #{to}"
      end

      if saved_change_to_assigned_to_id?
        from_id, to_id = saved_change_to_assigned_to_id
        record_event :assigned, "Assignee changed from #{assignee_label(from_id)} to #{assignee_label(to_id)}"
      end
    end

    # Current.user is the signed-in user (set by the Authentication concern);
    # it is nil in background jobs, which the history shows as "System".
    def record_event(kind, description)
      events.create!(kind: kind, description: description, user: Current.user)
    end

    def assignee_label(user_id)
      user_id ? User.find_by(id: user_id)&.name || "a deleted user" : "Unassigned"
    end

    # An unknown status (e.g. "archived") is already reported by the enum's
    # own validation, so the two checks below skip it to avoid a second message.
    def known_status?
      self.class.statuses.key?(status)
    end

    def new_tickets_start_open
      return unless known_status?

      errors.add(:status, "must be open for a new ticket") unless open?
    end

    def status_change_is_allowed
      return unless status_changed? && known_status?

      unless can_transition_to?(status)
        errors.add(:status, "cannot change from #{status_in_database} to #{status}")
      end
    end
end
