class GroupUser < ApplicationRecord
  belongs_to :group, foreign_key: 'group_id', primary_key: 'group_id'
  belongs_to :user, foreign_key: 'firebase_uid', primary_key: 'firebase_uid'
end
