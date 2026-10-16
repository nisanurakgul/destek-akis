# There is no public sign-up page. Only a signed-in admin can create users.
class UsersController < ApplicationController
  before_action :require_admin

  def index
    @users = User.order(:name)
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      redirect_to users_path, notice: "User #{@user.name} was created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def user_params
      params.expect(user: [ :name, :email_address, :role, :password, :password_confirmation ])
    end

    def require_admin
      redirect_to root_path, alert: "Only admins can manage users." unless Current.user.admin?
    end
end
