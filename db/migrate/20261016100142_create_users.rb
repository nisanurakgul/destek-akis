class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :email_address, null: false
      t.string :password_digest, null: false
      t.string :role, null: false, default: "agent"

      t.timestamps
    end
    add_index :users, :email_address, unique: true

    # Second line of defence: even code that skips model validations
    # (e.g. update_column) cannot store an unknown role.
    add_check_constraint :users, "role IN ('agent', 'admin')", name: "users_role_check"
  end
end
