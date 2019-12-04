class UserProvidersController < ApplicationController
  require 'devise'
  include ApplicationHelper

  def new
    password = Devise.friendly_token[0, 16]

    unless params[:provider] == "twitter"
      @user = User.new(
        email: params[:info][:email],
        password: password,
        username:  params[:info][:name],
        provider: params[:provider],
        uid: params[:uid]
      )
    else
      @user = User.new(
        password: password,
        username: params[:info][:name],
        provider: params[:provider],
        uid: params[:uid]
      )
    end
    session[:new_user] = params
  end

  def create
    password = Devise.friendly_token[6,20]

    user = session[:new_user]
    @user = User.new(
      email: params[:user][:email],
      password: password,
      username: user["info"]["name"],
      provider: user["provider"],
      uid: user["uid"]
    )

    if user["info"]["email"] != params[:user][:email]
      Devise::Mailer.confirmation_instructions(@user, @user.confirmation_token).deliver_now
      flash_msg = I18n.t(:signed_up_but_inactive, scope: 'devise.registrations')
    else
      @user.skip_confirmation!
      flash_msg = I18n.t(:signed_in, scope: 'devise.sessions')
    end
    return render :new unless @user.valid?

    @user.save

    UserProvider.create(
      user_id: @user.id,
      provider: user["provider"],
      uid: user["uid"]
    )

    if user["info"]["email"] != params[:user][:email]
      flash[:notice] = flash_msg
      redirect_to new_user_registration_path
    else
      sign_in_and_redirect @user, event: :authentication
      flash[:notice] = flash_msg
    end
    $updated_at = DateTime.now().strftime("%Q")
  end
end
