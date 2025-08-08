class AddFirebaseFieldsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :firebase_uid, :string
    add_column :users, :email, :string
    
    add_index :users, :firebase_uid, unique: true
    add_index :users, :email
  end
end
