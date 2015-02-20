require 'omniauth/strategies/oauth2'

module OmniAuth
  module Strategies
    class MicrosoftLive < OmniAuth::Strategies::OAuth2
      DEFAULT_SCOPE = 'wl.basic,wl.emails'
      USER_DATA_URL = 'https://apis.live.net/v5.0/me'

      option :client_options, {
        :site => 'https://login.live.com',
        :authorize_url => '/oauth20_authorize.srf',
        :token_url => '/oauth20_token.srf'
      }

      option :authorize_params, {
        :response_type => 'code'
      }

      option :name, 'microsoft_live'

      uid { raw_info['id'] }

      info do
        {
          'id' => raw_info['id'],
          'email' => user_email,
          'emails' => user_emails,
          'name' => raw_info['name'],
          'first_name' => raw_info['first_name'],
          'last_name' => raw_info['last_name'],
          'gender' => raw_info['gender'],
          'link' => raw_info['link'],
          'locale' => raw_info['locale'],
          'updated_time' => raw_info['updated_time']
        }
      end

      extra do
        {
          'raw_info' => raw_info,
          'authentication_token' => access_token.params.fetch('authentication_token', '')
        }
      end

      def callback_phase
        options.provider_ignores_state = session['omniauth.state'].nil?
        #ignore strange request without code
        request.params['code'].nil? ? Rack::Response.new.finish : super
      end

      protected

      def build_access_token
        super.tap do |token|
          handle_cookie(token)
        end
      end

      def handle_cookie(access_token)
        old_cookie = request.cookies['wl_auth']
        new_cookie = Rack::Utils.parse_nested_query(old_cookie)
        new_cookie['access_token'] = CGI.escape(access_token.token)
        new_cookie['authentication_token'] = CGI.escape(access_token.params.fetch('authentication_token', ''))
        new_cookie['scope'] = URI.encode(access_token.params.fetch('scope', ''))
        new_cookie['expires_in'] = CGI.escape(access_token.expires_in.to_s)

        if !request.params['error'].nil?
          new_cookie['error'] = request.params['error']
        elsif !access_token.params['error'].nil?
          new_cookie['error'] = 'access_denied'
          new_cookie['error_description'] = URI.encode('Failed to retrieve user access token')
        end

        request.env['wl_auth'] = new_cookie.collect { |k,v| "#{k}=#{v}" }.join("&")
      end

      def user_emails
        email_types = %w(preferred account personal business other)
        emails = []
        email_types.each do |type|
          emails << { 'type' => type, 'value' => raw_info['emails'][type] }
        end
        emails
      end

      def user_email
        raw_info['emails']['preferred'] != '' ? raw_info['emails']['preferred'] : raw_info['emails'].values.select { |email| email != '' }.first
      end

      def raw_info
        @raw_info ||= access_token.get(USER_DATA_URL).parsed
      end
    end
  end
end
