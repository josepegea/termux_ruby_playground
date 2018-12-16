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
      JSON.parse(api_command(command, args), symbolize_names: true)
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
        Time.parse(value)
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
  end
end
