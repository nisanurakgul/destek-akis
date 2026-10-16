class CreateTickets < ActiveRecord::Migration[8.1]
  def change
    create_table :tickets do |t|
      t.string :subject, null: false
      t.text :description, null: false
      t.string :requester_name, null: false
      t.string :requester_email, null: false
      t.string :priority, null: false, default: "normal"
      t.string :status, null: false, default: "open"
      # Optional: a new ticket may not be assigned to anyone yet.
      t.references :assigned_to, null: true, foreign_key: { to_table: :users }

      t.timestamps
    end
    add_index :tickets, :status

    # Same idea as users.role: the database itself rejects unknown values.
    add_check_constraint :tickets, "priority IN ('low', 'normal', 'high', 'urgent')", name: "tickets_priority_check"
    add_check_constraint :tickets, "status IN ('open', 'pending', 'solved', 'closed')", name: "tickets_status_check"
  end
end
