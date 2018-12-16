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

    def typed_json_api_command(command, type_conversions = {}, *args)
      res = json_api_command(command, args)
      apply_types(res, type_conversions)
    end

    def clipboard
      @clipboard ||= Clipboard.new(self)
    end

    def tts
      @tts ||= Tts.new(self)
    end

    def call_log
      @call_log ||= CallLog.new(self)
    end

    private

    def apply_types(results, type_conversions)
      collection = results.is_a?(Array) ? results : [results]
      collection.each { |c| apply_types_to_item(c, type_conversions) }
      results
    end

    def apply_types_to_item(item, type_conversions)
      return unless item.is_a?(Hash)
      type_conversions.each do |k, v|
        next unless item.key?(k)
        item[k] = apply_type_to_item_prop(item[k], v)
      end
    end

    def apply_type_to_item_prop(value, type)
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

    def to_duration(value)
      parts = value.split(':').reverse
      res = parts.pop.to_i
      res += (parts.pop.to_i * 60) if parts.any?
      res += (parts.pop.to_i * 60 * 60) if parts.any?
      res
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
      base_object.typed_json_api_command('call-log', { date: :time, duration: :duration, type: :symbol }, *args)
    end
  end
end
