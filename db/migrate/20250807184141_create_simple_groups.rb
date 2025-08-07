class CreateSimpleGroups < ActiveRecord::Migration[7.1]
  def change
    create_table :simple_groups, id: false do |t|
      t.string :group_id, primary_key: true, null: false
      t.string :name

      t.timestamps
    end
    
    add_index :simple_groups, :group_id, unique: true
  end
end
