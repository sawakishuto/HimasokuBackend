class UserDevice < ApplicationRecord
  belongs_to :user, foreign_key: 'firebase_uid', primary_key: 'firebase_uid'
  
  validates :device_id, presence: true, uniqueness: true
  validates :firebase_uid, presence: true
  
  # device_idはAPNSデバイストークンとして使用
  alias_attribute :apns_token, :device_id
end
