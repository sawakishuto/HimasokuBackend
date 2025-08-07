class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users, id: false do |t|
      t.string :uid, primary_key: true, null: false

      t.timestamps
    end
    
    add_index :users, :uid, unique: true
  end
end
