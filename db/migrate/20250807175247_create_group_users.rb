class CreateGroupUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :group_users, id: false do |t|
      t.string :uuid, primary_key: true, null: false
      t.string :group_id, null: false
      t.string :uid, null: false

      t.timestamps
    end
    
    add_index :group_users, :uuid, unique: true
    add_index :group_users, [:group_id, :uid], unique: true, name: 'index_group_users_on_group_and_user'
    add_index :group_users, :group_id
    add_index :group_users, :uid
    
    add_foreign_key :group_users, :groups, column: :group_id, primary_key: :group_id
    add_foreign_key :group_users, :users, column: :uid, primary_key: :uid
  end
end
