class CreateSimpleUserDevices < ActiveRecord::Migration[7.1]
  def change
    create_table :simple_user_devices, id: false do |t|
      t.string :uid, null: false
      t.string :device_id, primary_key: true, null: false

      t.timestamps
    end
    
    add_index :simple_user_devices, :device_id, unique: true
    add_index :simple_user_devices, :uid
    add_foreign_key :simple_user_devices, :simple_users, column: :uid, primary_key: :uid
  end
end
