class CreateSimpleGroupUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :simple_group_users, id: false do |t|
      t.string :uuid, primary_key: true, null: false
      t.string :group_id, null: false
      t.string :uid, null: false

      t.timestamps
    end
    
    add_index :simple_group_users, :uuid, unique: true
    add_index :simple_group_users, [:group_id, :uid], unique: true, name: 'index_simple_group_users_on_group_and_user'
    add_index :simple_group_users, :group_id
    add_index :simple_group_users, :uid
    
    add_foreign_key :simple_group_users, :simple_groups, column: :group_id, primary_key: :group_id
    add_foreign_key :simple_group_users, :simple_users, column: :uid, primary_key: :uid
  end
end
