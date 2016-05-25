require 'pathname'
require 'open-uri'
require 'yaml'
require 'erb'

class CloudConfigGenerator
  extend Forwardable

  YAML_FILE = Pathname.new(__FILE__).dirname.join('cloud-config.yml.erb')
  def self.call(settings)
    new(settings).call
  end

  attr_reader :settings

  def_delegators :settings, :owner_email, :vhosts, :postgres_db, :postgres_password,
    :postgres_user, :aws_id, :aws_secret, :aws_region, :nginx_confd_version, :fulcrum_app_version,
    :discovery_url

  def initialize(settings)
    @settings = settings
  end

  def call
    render_erb
  end

  def render_erb
    erb = ERB.new(File.read(YAML_FILE))
    erb.result(binding)
  end

  def fulcrum_run_file
    indent(6, File.open('./fulcrum_run.sh'))
  end

  def fulcrum_initializer
    indent(6, File.open('./initializer.sh'))
  end

  def top_domain
    settings.vhosts.first
  end

  def other_domains
    settings.vhosts.join(',')
  end

  def postgres_info
    "#{postgres_user}:#{postgres_password}:#{postgres_db}"
  end

  def docker_config_json
    indent(6, File.open("#{ENV['HOME']}/.docker/config.json"))
  end

  def indent(amount, io)
    lines = []
    indent = " " * amount
    io.each_line {|l| lines << "#{indent}#{l}"}
    lines.compact.join()
  end
end
