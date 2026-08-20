class Group < ApplicationRecord
  self.primary_key = 'group_id'
  
  has_many :group_users, foreign_key: 'group_id'
  has_many :users, through: :group_users

  # API レスポンス用の軽量表現
  def summary
    { id: group_id, name: name }
  end
end
