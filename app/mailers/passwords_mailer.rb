class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user
    mail subject: "DestekAkış parolanı sıfırla", to: user.email_address
  end
end
