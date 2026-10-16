class User < ApplicationRecord
  MINIMUM_PASSWORD_LENGTH = 8

  # Stores a bcrypt hash in password_digest; the plain password is never saved.
  # Also validates presence on create, a 72-byte maximum and password_confirmation.
  has_secure_password
  has_many :sessions, dependent: :destroy
  # If a user is deleted, their tickets stay and simply become unassigned.
  has_many :assigned_tickets, class_name: "Ticket", foreign_key: :assigned_to_id,
                              inverse_of: :assigned_to, dependent: :nullify
  # History stays if a user is deleted; those events then show "System".
  has_many :ticket_events, dependent: :nullify

  # Roles are stored as strings ("agent", "admin"). validate: true turns an
  # unknown role into a validation error instead of an ArgumentError.
  enum :role, { agent: "agent", admin: "admin" }, default: :agent, validate: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :name, with: ->(n) { n.strip }

  validates :name, presence: true, length: { maximum: 100 }
  validates :email_address, presence: true,
                            uniqueness: true,
                            format: { with: URI::MailTo::EMAIL_REGEXP }
  # allow_nil lets us update other fields without re-entering the password;
  # has_secure_password still requires a password when the user is created.
  validates :password, length: { minimum: MINIMUM_PASSWORD_LENGTH }, allow_nil: true
end
