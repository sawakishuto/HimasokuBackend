class GroupsController < ApplicationController
  def index
    render json: { groups: Group.all.map(&:summary) }
  end

  def show
    @group = Group.find(params[:id])
    render json: @group.summary
  end

  def create
    @group = Group.find_or_create_by(group_id: params[:group_id]) do |group|
      group.name = params[:name]
    end

    if @group.persisted?
      render json: @group, status: :created
    else
      render json: { errors: @group.errors.full_messages }, status: :unprocessable_entity
    end
  end
end
