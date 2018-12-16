require 'json'
require 'date'
require 'time'

module RubyTermux
  class Base
    def api_command(command, *args)
      res = %x(termux-#{command} #{args.join(' ')})
      raise $? if $?.exitstatus != 0
      res
    end

    def json_api_command(command, *args)
      res = api_command(command, args)
      return res if res.nil? || res == ''
      JSON.parse(res, symbolize_names: true)
    end

    # Systems

    def clipboard
      @clipboard ||= Clipboard.new(self)
    end

    def tts
      @tts ||= Tts.new(self)
    end

    def call_log
      @call_log ||= CallLog.new(self)
    end

    def location
      @location ||= Location.new(self)
    end

    def sms
      @sms ||= Sms.new(self)
    end
  end

  class System
    attr_accessor :base_object
    
    def initialize(base_object)
      @base_object = base_object
    end
  end

  class Clipboard < System
    def set(value)
      base_object.api_command('clipboard-set', value)
    end

    def get
      base_object.api_command('clipboard-get')
    end
  end

  class Tts < System
    def speak(value)
      base_object.api_command('tts-speak', value)
    end
  end

  class CallLog < System
    def log(limit:nil, offset:nil)
      args = []
      args += ['-l', limit.to_s] unless limit.nil?
      args += ['-o', offset.to_s] unless offset.nil?
      res = base_object.json_api_command('call-log', *args)
      Xformer.xform(res, date: :time, duration: :duration, type: :symbol)
    end
  end

  class Location < System
    def get(provider: nil, request: nil)
      args = []
      args += ['-p', provider] unless provider.nil?
      args += ['-r', request] unless request.nil?
      res = base_object.json_api_command('location', *args)
      Xformer.xform(res, provider: :symbol)
    end

    def gps(request: nil)
      get(provider: :gps, request: request)
    end

    def network(request: nil)
      get(provider: :network, request: request)
    end
  end

  class Sms < System
    def list(limit: nil, offset: nil, type: nil)
      args = []
      args += ['-l', limit.to_s] unless limit.nil?
      args += ['-o', offset.to_s] unless offset.nil?
      args += ['-t', type.to_s] unless type.nil?
      res = base_object.json_api_command('sms-list', *args)
      Xformer.xform(res, received: :time, type: :symbol)
    end

    def inbox(limit: nil, offset: nil)
      list(limit: limit, offset: offset, type: :inbox)
    end

    def outbox(limit: nil, offset: nil)
      list(limit: limit, offset: offset, type: :outbox)
    end

    def sent(limit: nil, offset: nil)
      list(limit: limit, offset: offset, type: :sent)
    end

    def draft(limit: nil, offset: nil)
      list(limit: limit, offset: offset, type: :draft)
    end
  end

  class Xformer
    def self.xform(object, args)
      collection = object.is_a?(Array) ? object : [object]
      collection.each { |i| xform_item(i, args) }
      object
    end

    private

    def self.xform_item(item, args)
      return unless item.is_a?(Hash)
      args.each do |arg, type|
        next unless item.key?(arg)
        item[arg] = xform_prop(item[arg], type)
      end
    end

    def self.xform_prop(value, type)
      case type
      when :date
        Date.parse(value)
      when :time
        Time.parse(fix_time(value))
      when :duration
        to_duration(value)
      when :integer
        value.to_i
      when :float
        value.to_f
      when :symbol
        value.to_sym
      else
        value
      end
    end

    def self.to_duration(value)
      parts = value.split(':').reverse
      res = parts.pop.to_i
      res += (parts.pop.to_i * 60) if parts.any?
      res += (parts.pop.to_i * 60 * 60) if parts.any?
      res
    end

    def self.fix_time(time_str)
      # Termux likes to give hours in 24:xx:xx format instead of 00:xx:xx
      time_str.gsub(/(.*)(24)(:\d\d:\d\d)(.*)/, '\1'+'00'+'\3'+'\4')
    end
  end
end
