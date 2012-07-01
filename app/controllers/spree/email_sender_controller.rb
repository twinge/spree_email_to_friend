# Spree namespacing requires moving this file into the spree folder.
# also current spree_email_to_friend gem implements the same
# namespace file structure.
# 
# https://github.com/spree/spree_email_to_friend/blob/914f88e95fc08965bef4d97b44079f0e56f40eca/app/controllers/spree/email_sender_controller.rb

module Spree
  class EmailSenderController < Spree::BaseController
    before_filter :find_object

    def send_mail
      if request.get?
        @mail_to_friend = MailToFriend.new(:sender_email => current_user.try(:email))
      else
        mail_to_friend
      end
    end

    private

    def mail_to_friend
      @mail_to_friend = MailToFriend.new(params[:mail_to_friend])
      respond_to do |format|
        format.html do
          captcha_passed = !Spree::Captcha::Config[:use_captcha] || verify_recaptcha(:private_key => Spree::Captcha::Config[:private_key])
          if @mail_to_friend.valid? && captcha_passed
            flash[:notice] = I18n.t('email_to_friend.mail_sent_to', :email => @mail_to_friend.recipient_email).html_safe
            flash[:notice] << ActionController::Base.helpers.link_to(I18n.t('email_to_friend.send_to_other'), email_to_friend_path(@object.class.name.downcase, @object)).html_safe

            send_message(@object, @mail_to_friend)

            method_name = "after_delivering_#{@object.class.name.downcase}_mail"
            send(method_name) if respond_to?(method_name, true)

            redirect_to @object
          else
            render :action => :send_mail
          end
        end
      end
    end

    #extract send message to make easier to override
    def send_message(object, mail_to_friend)
      ToFriendMailer.deliver_mail_to_friend(object,mail_to_friend)
    end

    def find_object
      # in light of spree namepacing
      class_name = "Spree::#{(params[:type].titleize)}".constantize
      return false if params[:id].blank?
      @object = class_name.find_by_id(params[:id])
      if class_name.respond_to?('find_by_permalink')
        @object ||= class_name.find_by_permalink(params[:id])
      end
      if class_name.respond_to?('get_by_param')
        @object ||= class_name.get_by_param(params[:id])
      end
    end

  end
end
