class ReplaceUidWithFirebaseUid < ActiveRecord::Migration[7.1]
  def change
    # 1. 外部キー制約を削除
    remove_foreign_key :user_devices, :users
    remove_foreign_key :group_users, :users
    
    # 2. 他のテーブルの uid カラムを firebase_uid に変更
    rename_column :user_devices, :uid, :firebase_uid
    rename_column :group_users, :uid, :firebase_uid
    
    # 3. users テーブルの uid インデックスを削除
    remove_index :users, :uid
    
    # 4. users テーブルのプライマリキーを firebase_uid に変更
    execute "ALTER TABLE users DROP CONSTRAINT users_pkey;"
    remove_column :users, :uid
    execute "ALTER TABLE users ADD PRIMARY KEY (firebase_uid);"
    
    # 5. 外部キー制約を firebase_uid で再追加
    add_foreign_key :user_devices, :users, column: :firebase_uid, primary_key: :firebase_uid
    add_foreign_key :group_users, :users, column: :firebase_uid, primary_key: :firebase_uid
  end
end
