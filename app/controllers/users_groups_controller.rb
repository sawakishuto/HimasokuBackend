class UsersGroupsController < ApplicationController
  # 特定のユーザーが所属するグループ一覧を取得
  def user_groups
    user = User.find(params[:user_id])
    render json: { groups: user.groups.map(&:summary) }
  end

  # 特定のグループに所属するユーザー一覧を取得
  def group_users
    group = Group.find(params[:group_id])
    render json: {
      group: group.summary,
      users: group.users.map(&:summary)
    }
  end

  # 全てのユーザーとグループの関係を取得
  def index
    @users_groups = GroupUser.includes(:user, :group).all
    render json: @users_groups.map { |ug|
      {
        user_id: ug.user.firebase_uid,
        group_id: ug.group.group_id,
        group_name: ug.group.name
      }
    }
  end

  def show
    render json: GroupUser.pluck(:user_id, :group_id)
  end

  def create
    existing_relation = GroupUser.find_by(
      firebase_uid: users_group_params[:firebase_uid],
      group_id: users_group_params[:group_id]
    )

    if existing_relation
      render json: existing_relation, status: :ok
      return
    end

    @users_group = GroupUser.new(users_group_params)
    if @users_group.save
      render json: @users_group, status: :created
    else
      Rails.logger.error "GroupUser validation errors: #{@users_group.errors.full_messages}"
      render json: { errors: @users_group.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def users_group_params
    params.require(:users_group).permit(:firebase_uid, :group_id, :uuid)
  end
end
