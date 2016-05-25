require 'securerandom'

module Secrets
  module_function

  def generate(what)
    send(:"generate_#{what}")
  end

  def generate_db
    random_hex
  end

  def generate_password
    random_b64
  end

  def generate_user
    random_hex
  end

  def random_hex(length = 20)
    SecureRandom.hex(length)
  end

  def random_b64(length = 40)
    SecureRandom.base64(length)
  end
end
