class UsersGroupsController < ApplicationController

  # 特定のユーザーが所属するグループ一覧を取得
  def user_groups
    user = User.find(params[:user_id])
    @groups = user.groups
    render json: @groups
  end

  # 特定のグループに所属するユーザー一覧を取得
  def group_users
    group_id = params[:group_id]
    
    # 方法1: Groupモデル経由でusersを取得（推奨）
    group = Group.find(group_id)
    @users = group.users
    
    # 方法2: 直接JOINを使用する場合
    # @users = User.joins(:group_users).where(group_users: { group_id: group_id })
    
    # 方法3: SimpleGroupUserテーブルを使用する場合
    # @users = User.joins("JOIN simple_group_users ON users.uid = simple_group_users.uid")
    #               .where("simple_group_users.group_id = ?", group_id)
    
    render json: @users
  end

  # 全てのユーザーとグループの関係を取得
  def index
    @users_groups = GroupUser.includes(:user, :group).all
    render json: @users_groups.map { |ug| 
      {
        user_id: ug.user.uid,
        group_id: ug.group.group_id,
        group_name: ug.group.name
      }
    }
  end

  def show 
    @users_group = GroupUser.pluck(:user_id, :group_id)
    render json: @users_group
  end

  def create
    @users_group = GroupUser.create(users_group_params)
    if @users_group.save
      render json: @users_group, status: :created
    else
      render json: @users_group.errors, status: :unprocessable_entity
    end
  end

  private

  def users_group_params
    params.require(:users_group).permit(:user_id, :group_id, :uuid)
  end
end