require 'active_record'

# Models a worker so they can be exposed to clients through the JSON API.
#
# Workers have a simple heartbeat mechanism that pings every 10 seconds (unless
# configured otherwise) while travis-hub will purge records that are older than
# 15 seconds at an interval of 5 seconds (unless configured otherwise).
class Worker < ActiveRecord::Base
  autoload :States, 'travis/model/worker/states'
  autoload :Status, 'travis/model/worker/status'

  include States

  class << self
    def prune
      workers = where(['last_seen_at < ?', Time.now.utc - Travis.config.workers.prune.after]).destroy_all
      workers.each { |worker| worker.notify(:remove) }
    end
  end

  serialize :payload

  before_create do
    self.last_seen_at = Time.now.utc
  end

  def full_name
    [host, name].join(':')
  end

  def queue
    read_attribute(:queue) || guess_queue
  end

  def guess_queue
    case full_name
    when /ruby/, /staging/
      'builds.common'
    when /jvm/
      'builds.jvmotp'
    when /ppp/, /php/
      'builds.php'
    when /rails/
      'builds.rails'
    when /spree/
      'builds.spree'
    else
      raise "No idea what queue #{full_name} might use."
    end
  end
end
