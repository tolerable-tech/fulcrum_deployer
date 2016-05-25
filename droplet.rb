require 'droplet_kit'
require 'forwardable'

class Droplet
  def self.application_token
    ENV['DO_APP_TOKEN']
  end

  Deletion = Struct.new(:droplet, :floating_ip, :tag) do
    def rm(type, response)
      self[type] ||= []
      self[type] << response
    end

    def will_rm(type, item)
      self[type] ||= []
      self[type] << response
    end
  end

  attr_reader :form

  attr_accessor :client, :settings, :floating, :floating_ip_assignment, :created,
    :assigned_floating_ip_addr

  def self.create(form, token)
    new(form).create(token)
  end

  def self.generate(form)
    new(form).generate
  end

  def self.delete_all(token)
    new(nil).delete_all(token)
  end

  def initialize(form)
    @form = form
  end

  def generate
    self.settings = Settings.realize(client, form)
    self
  end

  def create(token)
    assign_client(token)
    generate

    droplet = DropletKit::Droplet.new(settings.droplet_initialize)
    created = client.droplets.create(droplet)
    net = created.networks.v4.find{|r| r.type == "public"}
    puts "created droplet[#{created.id}] ip: [#{net ? net.ip_address : 'unknown'}]"

    created = wait_for_boot(created)
    net = created.networks.v4.find{|r| r.type == "public"}

    puts "droplet with public ip [#{net ? net.ip_address : 'unkown'}] ready, assigning floating ip"

    assign_floating_ip(created, settings)
    tag_created_droplet(created)
    self
  end

  def created_successfully?
    true
  end

  def deleteables(token)
    assign_client(token)
    floating_ips = client.floating_ips.all
    resp = Deletion.new([], [], [])

    client.droplets.all(tag_name: Settings::FULCRUM_TAG).each do |droplet|
      if droplet.tags.include?(Settings::FULCRUM_GENERATED_IP_TAG)
        fip = floating_ips.find {|f| f.droplet.id == droplet.id}
        resp.will_rm(:floating_ip, fip)
      end

      resp.will_rm(:droplet, droplet)
    end

    [Settings::FULCRUM_TAG, Settings::FULCRUM_GENERATED_IP_TAG].each do |tag|
      resp.will_rm(:tag, tag)
    end
  end

  def delete_all(token)
    assign_client(token)
    floating_ips = client.floating_ips.all
    resp = Deletion.new([], [], [])

    client.droplets.all(tag_name: Settings::FULCRUM_TAG).each do |droplet|
      if droplet.tags.include?(Settings::FULCRUM_GENERATED_IP_TAG)
        fip = floating_ips.find {|f| f.droplet.id == droplet.id}
        resp.rm(:floating_ip, [client.floating_ips.delete(ip: fip.ip), fip])
      end

      resp.rm(:droplet, [client.droplets.delete(id: droplet.id), droplet])
    end

    [Settings::FULCRUM_TAG, Settings::FULCRUM_GENERATED_IP_TAG].each do |tag|
      r = begin
            client.tags.delete(name: tag)
          rescue Exception => boom
            boom
          end
      resp.rm(:tag, [r, tag])
    end

    resp
  end

  private

  def assign_floating_ip(droplet, settings)
    if settings.floating_ip == "generated"
      floating_ip = DropletKit::FloatingIp.new(droplet_id: droplet.id)
      resp = client.floating_ips.create(floating_ip)
      self.assigned_floating_ip_addr = resp.ip
    else
      fip = client.floating_ips.find(ip: settings.floating_ip)
      self.floating_ip_assignment = client.floating_ip_actions.assign(ip: fip.ip, droplet_id: droplet.id)
      self.assigned_floating_ip_addr = settings.floating_ip
    end
  end

  def tag_created_droplet(droplet)
    tags = [Settings::FULCRUM_TAG]
    tags << Settings::FULCRUM_GENERATED_IP_TAG if settings.floating_ip == "generated"

    tags.each do |tag_name|
      itag = DropletKit::Tag.new(name: tag_name)
      client.tags.create(itag) rescue DropletKit::FailedCreate # Most likely, tag already exists
    end

    tags.each do |tag_name|
      client.tags.tag_resources(name: tag_name, resources:
                 [{resource_id: droplet.id, resource_type: 'droplet'}])
    end
  end

  def wait_for_boot(droplet)
    print "waiting for droplet -- status = #{droplet.status}"
    count = 30
    dr = client.droplets.find(id: droplet.id)
    while dr.status != "active" && count > 0 do
      print '.'
      sleep 1
      count -= 1
      dr = client.droplets.find(id: droplet.id)
      #puts "   --- new status == #{dr.status}"
    end
    puts
    dr
  end

  def destroy
    droplet = client.droplets.all.find {|r| r.name == 'fulcrumizer'}
    client.droplets.delete(id: droplet.id)
  end

  def assign_client(token)
    @client = DropletKit::Client.new(access_token: token)
  end

end

