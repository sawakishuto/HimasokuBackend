class CreateGroups < ActiveRecord::Migration[7.1]
  def change
    create_table :groups, id: false do |t|
      t.string :group_id, primary_key: true, null: false
      t.string :name

      t.timestamps
    end
    
    add_index :groups, :group_id, unique: true
  end
end
