class CreateUserDevices < ActiveRecord::Migration[7.1]
  def change
    create_table :user_devices, id: false do |t|
      t.string :uid, null: false
      t.string :device_id, primary_key: true, null: false

      t.timestamps
    end
    
    add_index :user_devices, :device_id, unique: true
    add_index :user_devices, :uid
    add_foreign_key :user_devices, :users, column: :uid, primary_key: :uid
  end
end
