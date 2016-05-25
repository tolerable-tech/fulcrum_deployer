require './secrets.rb'
require './cloud_config_generator.rb'

SETTINGS_ATTRS = %i|floating_ip droplet_name region size image ssh_key ipv6 user_data
  private_networking owner_email hostnames vhosts postgres_db postgres_password postgres_user
  aws_id aws_secret aws_region nginx_confd_version fulcrum_app_version discovery_url|

Settings = Struct.new(*SETTINGS_ATTRS) do

  COREOS_BETA_ID = -> (client) { client.images.all.find {|i| i.slug == 'coreos-beta'}.id }

  DEFAULTS = [nil, 'fulcrum-deployer-1', 'nyc2', '2gb',  COREOS_BETA_ID, [],
    true, CloudConfigGenerator, true, nil, nil, nil, nil, nil, nil, nil, nil, nil, '0.0.1', '0.0.1']


  def self.realize(client, form)
    new(form, *DEFAULTS).realize(client)
  end

  def initialize(form, *defaults)
    count = -1
    super(*SETTINGS_ATTRS.map {|a|
      count += 1
      form.get(a, defaults[count])
    })
  end

  def realize(client)
    raise "required attr" unless self.hostnames
    self.vhosts = self.hostnames.split(',')
    self.postgres_db = Secrets.generate(:db)
    self.postgres_password = Secrets.generate(:password)
    self.postgres_user = Secrets.generate(:user)
    #self.aws_id = ENV['AWS_ACCESS_KEY_ID']
    #self.aws_secret = ENV['AWS_SECRET_ACCESS_KEY']
    #self.aws_region = ENV['AWS_REGION']
    #unless aws_id && aws_secret && aws_region
      #raise ArgumentError,"Please set AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_REGION."
    #end
    set_discovery_url unless self.discovery_url
    self.image = self.image.call(client) if self.image.respond_to?(:call) && client
    self
  end

  def cloud_config
    if user_data.respond_to?(:call)
      self.user_data = self.user_data.call(self)
    end
    self.user_data
  end

  def set_discovery_url
    lines = []
    open('https://discovery.etcd.io/new?size=1') {|f|
      f.each_line {|l| lines << l}
    }
    self.discovery_url = lines.last
  end

  def droplet_initialize
    {name: droplet_name, region: region, size: size, image: image, ssh_keys: [ssh_key],
     ipv6: ipv6, user_data: cloud_config, private_networking: private_networking }
  end
end

Settings::FULCRUM_TAG= 'fulcrum-deployer'
Settings::FULCRUM_GENERATED_IP_TAG = 'fulcrum-deployer-generated-floater'
