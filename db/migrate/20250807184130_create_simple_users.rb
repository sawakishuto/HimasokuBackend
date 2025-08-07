class CreateSimpleUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :simple_users, id: false do |t|
      t.string :uid, primary_key: true, null: false

      t.timestamps
    end
    
    add_index :simple_users, :uid, unique: true
  end
end
