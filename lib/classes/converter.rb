# -*- encoding: utf-8 -*-
$:.unshift File.dirname(__FILE__) 

require 'rubygems'
require 'xml'
require 'time'

module Nicos
  module Converter
    def iso8601ToUnix(str)
      Time.strptime(str, "%Y-%m-%dT%H:%M:%S").to_i
    end
    module_function :iso8601ToUnix

    def japToUnix(str)
      str.gsub!(/年|月/, '-')
        .gsub!(/日/, 'T')
        .gsub!(/：/, ':')
        .gsub!(/\s/, '')
      iso8601ToUnix(str)
    end
    module_function :japToUnix
      
    def toSeconds(lengthStr)
      # lengthStr = "mm:ss"
      lengthStr = lengthStr.split(/\:/)
      lengthStr[0].to_i * 60 + lengthStr[1].to_i
    end
    module_function :toSeconds
    
    def commaRemover(str)
      str.gsub(/\,/, '').to_i
    end  
    module_function :commaRemover
  end

  module Extractor
    def mylistId(str)
      /(mylist\/)([0-9]{1,})/ =~ str
      $2.to_i
    end
    module_function :mylistId

    def itemId(str)
      /(watch\/)([0-9]{1,})/ =~ str
      $2.to_i
    end
    module_function :itemId
    
    def videoId(str)
      /(http:\/\/www.nicovideo.jp\/watch\/)((sm|nm)[0-9]{1,})/ =~ str
      $2    
    end
    module_function :videoId
  end

  module Nicos::Unicode
    def escape(str)
      ary = str.unpack("U*").map!{|i| "\\u#{i.to_s(16)}"}
      ary.join
    end
    
    UNESCAPE_WORKER_ARRAY = []
    def unescape(str)
      str.gsub(/\\u([0-9a-f]{4})/) {
        UNESCAPE_WORKER_ARRAY[0] = $1.hex
        UNESCAPE_WORKER_ARRAY.pack("U")
      }
    end
    
    module_function :escape, :unescape
  end
end
