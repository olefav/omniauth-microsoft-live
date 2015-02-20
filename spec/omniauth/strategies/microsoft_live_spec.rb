require 'spec_helper'
require 'omniauth/strategies/microsoft_live'

describe OmniAuth::Strategies::MicrosoftLive do
  let(:request) { double('Request', :params => {}, :cookies => {}, :env => {}) }
  let(:app) {
    lambda do
      [200, {}, ["Hello."]]
    end
  }

  subject do
    OmniAuth::Strategies::MicrosoftLive.new(app, 'appid', 'secret', @options || {}).tap do |strategy|
      allow(strategy).to receive(:request) {
        request
      }
    end
  end

  describe '#client' do
    it 'should have the correct Windowslive site' do
      subject.client.site.should eq("https://login.live.com")
    end
    it 'should have the correct authorization url' do
      subject.client.options[:authorize_url].should eq("/oauth20_authorize.srf")
    end
    it 'should have the correct token url' do
      subject.client.options[:token_url].should eq('/oauth20_token.srf')
    end
  end

  describe "wl_auth cookie handler" do
    let(:cookie_value) { "client_id=0000000000000001&status=not_connected" }
    let(:request) { double('Request', :params => {}, :cookies => { 'wl_auth' => cookie_value }, :env => {}, :session => {}) }
    let(:access_token) { double('access_token', :token => 'access_token', :params => { 'authentication_token' => 'auth_token', 'scope' => 'wl.emails wl.basic'}, :expires_in => 3600 ) }

    it "should not remove provided values from cookie" do
      subject.send(:handle_cookie, access_token)

      request.env['wl_auth'].should match(/client_id\=0000000000000001/)
      request.env['wl_auth'].should match(/status\=not_connected/)
    end

    it "should add tokens to session" do
      subject.send(:handle_cookie, access_token)

      request.env['wl_auth'].should match(/access_token\=access_token/)
      request.env['wl_auth'].should match(/authentication_token\=auth_token/)
    end

    it "should add scope" do
      subject.send(:handle_cookie, access_token)

      request.env['wl_auth'].should match(/scope\=#{URI.encode('wl.emails wl.basic')}/)
    end

    it "should add expires_in" do
      subject.send(:handle_cookie, access_token)

      request.env['wl_auth'].should match(/expires_in\=3600/)
    end

    context "when errors present" do
      it "should set error from params to cookie" do
        request.params['error'] = 'error'

        subject.send(:handle_cookie, access_token)

        request.env['wl_auth'].should match(/error=error/)
      end

      it "should set WL specified error from token error" do
        access_token.params['error'] = 'some error'

        subject.send(:handle_cookie, access_token)

        request.env['wl_auth'].should match(/error=access_denied&error_description=#{URI.encode('Failed to retrieve user access token')}/)
      end
    end
  end

  describe "#callback_phase" do
    it "should ignore state if it is absent in session" do
      subject.stub(:session).and_return({})

      subject.send(:callback_phase)

      subject.options.provider_ignores_state.should == true
    end

    it "should check state if it is present in session" do
      subject.stub(:session).and_return({ 'omniauth.state' => 'somestate' })

      subject.send(:callback_phase)

      subject.options.provider_ignores_state.should == false
    end
  end

  describe "user emails" do
    it "should get all specified email types" do
      emails = {
        'preferred' => 'preferred@example.com',
        'account' => 'account@example.com',
        'personal' => 'personal@example.com',
        'business' => 'business@example.com',
        'other' => 'other@example.com'
      }

      subject.stub(:raw_info).and_return({ 'emails' => emails })

      parsed_emails = subject.send(:user_emails)

      emails_equal = []
      %w(preferred account personal business other).each do |email_type|
        email = parsed_emails.find { |e| e['type'] == email_type }
        emails_equal << email['value'] == emails[email_type]
      end
      emails_equal.all?.should be true
    end

    it "should ignore unknown email types" do
      subject.stub(:raw_info).and_return( { 'emails' => { 'unknown' => 'unknown@example.com' } })

      parsed_emails = subject.send(:user_emails)
      parsed_emails.find { |e| e['type'] == 'unknown' }.should be_nil
    end
  end

  describe "user email" do
    it "should get preferred if it is present" do
      emails = {
        'preferred' => 'preferred@example.com',
        'account' => '',
        'personal' => '',
        'business' => 'business@example.com',
        'other' => 'other@example.com'
      }

      subject.stub(:raw_info).and_return({ 'emails' => emails })

      email = subject.send(:user_email)

      email.should == 'preferred@example.com'
    end

    it "should get first non-blank value otherways" do
      emails = {
        'preferred' => '',
        'account' => '',
        'personal' => '',
        'business' => 'business@example.com',
        'other' => 'other@example.com'
      }

      subject.stub(:raw_info).and_return({ 'emails' => emails })

      email = subject.send(:user_email)

      email.should == 'business@example.com'
    end
  end
end
