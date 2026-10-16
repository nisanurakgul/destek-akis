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

  belongs_to :assigned_to, class_name: "User", optional: true

  enum :priority, { low: "low", normal: "normal", high: "high", urgent: "urgent" },
       default: :normal, validate: true
  enum :status, { open: "open", pending: "pending", solved: "solved", closed: "closed" },
       default: :open, validate: true

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
