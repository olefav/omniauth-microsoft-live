# OmniAuth Microsoft Live Strategy

Microsoft (Windows) Live OAuth2 Strategy for OmniAuth.
Supports hybrid(client-side) and server-side flows.

## Installation

Add to your `Gemfile`:

```ruby
gem "omniauth-microsoft-live", :github => "9peso/omniauth-microsoft-live"
```

Then run `bundle install`.

## Obtaining application key and secret

* Go to 'https://account.live.com/developers/applications/'
* Select (or create) your project.
* Follow 'Edit Settings'
* Follow 'App Settings'

## Usage

If You are not using Devise then you can add provider as middleware.
An example for adding the middleware to a Rails app in `config/initializers/omniauth.rb` is below:

```ruby
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :microsoft_live, ENV["LIVE_KEY"], ENV["LIVE_CLIENT_SECRET"]
end
```

You can now access the OmniAuth Microsoft Live OAuth2 URL: `/auth/microsoft_live`

## Auth Hash

An example of an authentication hash available in the callback by accessing `request.env["omniauth.auth"]`:

```ruby
{
  "provider" => "microsoft_live",
  "uid" => "123459789uid",
  "info" =>  {
    "id" => "123459789uid",
    "email" => "mail@example.com",
    "emails" =>  [
      { "type" => "preferred", "value" => "mail@example.com"     },
      { "type" => "account",   "value" => "mail@example.com"     },
      { "type" => "personal",  "value" => nil                    },
      { "type" => "business",  "value" => "business@example.com" },
      { "type" => "other",     "value" => nil                    }
    ],
    "name" => "John Doe",
    "first_name" => "John",
    "last_name" => "Doe",
    "gender" => nil,
    "link" => "https://profile.live.com/",
    "locale" => "en_US",
    "updated_time" => "2015-02-24T07:00:00+0000"
  },
  "credentials" =>  {
    "token" => "token",
    "expires_at" => 1424005505,
    "expires" => true
  },
  "extra"  =>  {
    "raw_info" =>  {
      "id" => "123459789uid",
      "name" => "John Doe",
      "first_name" => "John",
      "last_name" => "Doe",
      "link" => "https://profile.live.com/",
      "gender" => nil,
      "emails" =>  {
        "preferred" => "mail@example.com",
        "account"   => "mail@example.com",
        "personal"  => nil,
        "business"  => "business@example.com"
      },
      "locale" => "en_US",
      "updated_time" => "2015-02-24T07:00:00+0000"
    },
    "authentication_token" => "auth_token"
  }
}
```

### Server-side flow (Devise)

Define your application id and secret in "config/initializers/devise.rb"

```ruby
config.omniauth :microsoft_live, "APP_ID", "APP_SECRET", { }
```

Add omniauth callbacks controller option to devise line in 'config/routes.rb' for the callback routes to be defined.

```ruby
devise_for :users, :controllers => { :omniauth_callbacks => "omniauth_callbacks" }
```

Make your model omniauthable. Generally the model resides in "/app/models/user.rb"

```ruby
devise :omniauthable, :omniauth_providers => [:microsoft_live]
```

Setup your callbacks controller.

```ruby
class OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def microsoft_live
    # You need to implement the method below in your model (e.g. app/models/user.rb)

    auth_attributes = request.env["omniauth.auth"]
    @user = User.find_for_omniauth(auth_attributes['provider'], auth_attributes['uid'])

    ...
  end
end
```

and bind to or create the user

```ruby
def self.find_for_omniauth(provider, uid)
  user = User.where(:provider => provider, :uid => uid).first
end
```

For your views you can login using:

```ruby
<%= link_to "Sign in with Live",
  user_omniauth_authorize_path(:microsoft_live) %>
```

An overview is available at https://github.com/plataformatec/devise/wiki/OmniAuth:-Overview

### One-time code flow (Hybrid Authentication) (and Devise)

This flow is described by microsoft [here](https://msdn.microsoft.com/en-us/library/hh243647.aspx#authcodegrant).
Hybrid authentication flow has significant functional and security advantages over a pure server-side or pure client-side flow.  The following steps occur in this flow:

1. The client (web browser) authenticates the user directly via WL JS SDK.  During this process assorted modals may be rendered by WL.
2. On successful authentication, WL server returns a one-time use code, which requires the client secret (which is only available server-side).
3. WL redirects user to the callback page with code in parameters.
4. The gem validates the code using a server-side request to WL servers.
If the code is valid then an access token will be returned. The gem then
forms a cookie needed for WL JS SDK and sets in into env.
5. Callback controller sets the cookie from env.
6. WL SDK validates the cookie and closes the popup.
7. Login success callback function is called.

This flow is immune to replay attacks, and conveys no useful information to a man in the middle.

For this flow to be functional you need to setup appropriate javascript
and change the callback controller code. The examples are provided
below.

```javascript
jQuery(function() {
  return $.ajax({
    url: '//js.live.net/v5.0/wl.js',
    dataType: 'script',
    cache: true
  });
});

window.wlAsyncInit = function() {
  WL.init({
    client_id: 'YOUR_MS_KEY',
    redirect_uri: 'YOUR_SERVER/users/auth/microsoft_live/callback',
    scope: ['wl.emails', 'wl.basic'],
    response_type: 'code',
  });

  var onLoginSuccess = function(data) {
    ...
  },

  onLoginFailure = function() {
    ...
  };

  $('.microsoft_live').click(function(e) {
    e.preventDefault();
    WL.login().then(onLoginSuccess, onLoginFailure);
  });
};
```

**IMPORTANT:** When using hybrid auth redirect page must include WL JS
SDK. This is a Microsoft requirement of such flow.

```ruby
class OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def microsoft_live
    # You need to implement the method below in your model (e.g. app/models/user.rb)

    auth_attributes = request.env["omniauth.auth"]
    @user = User.find_for_omniauth(auth_attributes['provider'], auth_attributes['uid'])

    #set unencoded cookie for WL.js
    response['set-cookie'] = "wl_auth=#{request.env.delete('wl_auth')}; domain=#{request.host}; path=/"
    ...

    redirect_to page_with_wl_js_path
  end
end
```
