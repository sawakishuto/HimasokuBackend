class UserDevice < ApplicationRecord
  belongs_to :user, foreign_key: 'firebase_uid', primary_key: 'firebase_uid'
end
