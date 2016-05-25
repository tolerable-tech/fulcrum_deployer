require 'bundler/setup'
require 'sinatra/base'
require 'tilt/erb'
require 'rack/protection'
require 'omniauth-digitalocean'

require './droplet.rb'
require './form.rb'
require './settings.rb'

class FulcrumDeployer < Sinatra::Base
  use Rack::Session::Cookie, secure: true, secret: ENV['SECRET_TOKEN'], domain: ENV['DEPLOYER_DOMAIN']
  use Rack::Protection

  set :erb, format: :html5

  helpers do
    def authenticated_with_do?;  session.has_key?('token'); end

    def user_do_client
      DropletKit::Client.new(access_token: session['token'])
    end

    def user_do_ssh_keys
      user_do_client.ssh_keys.all
    end

    def user_do_sizes
      user_do_client.sizes.all.find_all {|s| s.available}
    end

    def user_do_regions
      user_do_client.regions.all
    end

    def user_do_floating_ips
      user_do_client.floating_ips.all.find_all {|f| f.droplet.nil?}
    end

    def generated_droplet_name
      "fulcrum-deployer-1"
    end
  end

  get '/' do
    erb :landing
  end

  get '/new' do
    erb :new, locals: {form: Form.new}, format: :html5
  end

  get '/remove' do
    if session['token']
      erb :remove
    else
      session['remove'] = true
      redirect to('/auth/digitalocean')
    end
  end

  post '/create' do
    form = if params.has_key?('etcd_discovery')
      Form.from_accepted_params(params)
    else
      Form.from_params(params)
    end

    droplet = Droplet.create(form, session['token'])

    erb :droplet, locals: {form: form, droplet: droplet}, format: :html5
  end

  post '/generate' do
    form = Form.from_params(params)

    droplet = Droplet.generate(form)

    erb :generated_config, locals: {form: form, droplet: droplet}, format: :html5
  end

  post '/delete' do
    info = Droplet.delete_all(session['token'])
    erb :deleted_droplets, locals: {info: info}
  end

  get '/auth/:provider/callback' do
    request.env['omniauth.auth'].to_hash.inspect rescue "No Data"

    session['token'] = request.env['omniauth.auth'].credentials.token

    if session['remove']
      redirect to('/remove')
    else
      redirect to('/new')
    end
  end
  post '/auth/:provider/callback' do
    request.env['omniauth.auth'].to_hash.inspect rescue "No Data"

    session['token'] = request.env['omniauth.auth'].credentials.token

    if session['remove']
      redirect to('/remove')
    else
      redirect to('/new')
    end
  end

  get '/auth/failure' do
    p request.env['omniauth.auth'].to_hash.inspect rescue "No Data"
  end

  use OmniAuth::Builder do
    provider :digitalocean, ENV["DIGITALOCEAN_APP_ID"], ENV["DIGITALOCEAN_SECRET"], scope: "read write"
  end
end
