class CreateTicketEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :ticket_events do |t|
      t.references :ticket, null: false, foreign_key: true
      # Optional: automatic changes (e.g. the 72 hour auto-close) have no signed-in user.
      t.references :user, null: true, foreign_key: true
      t.string :kind, null: false
      t.string :description, null: false

      # Events are never edited, so only the time they happened is stored.
      t.datetime :created_at, null: false
    end

    add_check_constraint :ticket_events, "kind IN ('created', 'assigned', 'status_changed')",
                         name: "ticket_events_kind_check"
  end
end
