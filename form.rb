require 'ostruct'

FORM_ATTRS = %i|owner_email hostnames droplet_name region size floating_ip ssh_key aws_id aws_secret aws_region etcd_discovery|

Form = Struct.new(*FORM_ATTRS) do

  def self.from_params(parms)
    new(*FORM_ATTRS.map {|a| parms[a.to_s]})
  end

  def self.from_accepted_params(parms)
    attrs = FORM_ATTRS.map {|a| parms[a.to_s]}
    if FORM_ATTRS.length == attrs.length
      new(*attrs)
    else
      new(*attrs)
    end
  end

  def get(name, default = nil)
    return default unless members.include?(name)
    val = self[name]

    return default if val.nil? || val.blank?

    val
  end

  def has_authenticated_properties?
    false
  end

end
