require 'net/ldap'
require 'devise/strategies/authenticatable'

module Devise
  module Strategies
    class LdapAuthenticatable < Devise::Strategies::Base
      # def valid?
      #   binding.pry
      #   super
      # end

      def authenticate!
        if params[:user]
          ldap = Net::LDAP.new
          ldap.host = "oldap.elementums.com"
          ldap.port = "389"
          ldap.auth base_user, password

          if ldap.bind
            user = User.find_or_create_by(user_data)
            success! user
          else
            fail(:invalid_login)
          end
        end
      end

      def base_user
        "uid=#{params[:user][:username]},ou=People,dc=elementums,dc=com"
      end

      def password
        params[:user][:password]
      end

      def user_data
        {:username => params[:user][:username], :password => password, :password_confirmation => password}
      end
    end
     Warden::Strategies.add(:ldap_authenticatable, Devise::Strategies::LdapAuthenticatable)

  end
end

# Warden::Strategies.add(:ldap_authenticatable, Devise::Strategies::LdapAuthenticatable)
 
# ldap = Net::LDAP.new(
#     host: 'oldap.elementums.com',
#     auth: { method: :simple, username: "uid=ndemeshchenko,ou=People,dc=elementums,dc=com", password:'rpiffwhz' }
#   )                      