class UsersGroupsController < ApplicationController

  # 特定のユーザーが所属するグループ一覧を取得
  def user_groups
    user = User.find(params[:user_id])
    @groups = user.groups
    render json: {
      groups: 
        @groups.map { |group| {
        id: group.group_id,
        name: group.name
      } }
    }
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

    render json: {
      group: {
        id: group.group_id,
        name: group.name,
      },
      users: @users.map { |user| {
        id: user.firebase_uid,
        name: user.name
      } }
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
    @users_group = GroupUser.pluck(:user_id, :group_id)
    render json: @users_group
  end

  def create
    Rails.logger.info "Creating GroupUser with params: #{users_group_params}"

    # 既存の関係をチェック
    existing_relation = GroupUser.find_by(
      firebase_uid: users_group_params[:firebase_uid], 
      group_id: users_group_params[:group_id]
    )

    if existing_relation
      # 既に存在する場合は200で返す
      render json: existing_relation, status: :ok
    else
      # 新規作成
      @users_group = GroupUser.new(users_group_params)
      if @users_group.save
        render json: @users_group, status: :created
      else
        Rails.logger.error "GroupUser validation errors: #{@users_group.errors.full_messages}"
        render json: { errors: @users_group.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end

  private

  def users_group_params
    params.require(:users_group).permit(:firebase_uid, :group_id, :uuid)
  end
end