class User < ApplicationRecord
  self.primary_key = 'firebase_uid'
  
  has_many :group_users, foreign_key: 'firebase_uid'
  has_many :groups, through: :group_users
  has_many :user_devices, foreign_key: 'firebase_uid'

  # API レスポンス用の軽量表現
  def summary
    { id: firebase_uid, name: name }
  end
end
