# -*- encoding: utf-8 -*-
$:.unshift File.dirname(__FILE__) 

require 'rubygems'
require 'xml'
require 'time'

require 'converter.rb'

module Nicos
  module Parser
    # getThumbInfoが返すXMLを解析し、ハッシュオブジェクトにして返します。
    #
    # @return [HashObj]
    def getThumbInfo(xml)
      doc = XML::Reader.string(
        xml,
        :options => XML::Parser::Options::NOBLANKS |
        XML::Parser::Options::NOENT
      )
              
      n = -1
      parsed = {}
      category = ""

      while doc.read
        unless doc.node_type == XML::Reader::TYPE_END_ELEMENT
          case doc.name
          when "video_id", "title", "description", "thumbnail_url",
                "movie_type", "last_res_body" , "watch_url", "thumb_type"
            label = doc.name
            doc.read
            parsed[label] = doc.value
          when "size_high", "size_low", "view_counter", "comment_num",
                "mylist_counter", "embeddable", "no_live_play", 
                "user_id"   
            label = doc.name
            doc.read
            parsed[label] = doc.value.to_i
          when "first_retrieve"
            label = doc.name
            doc.read
            parsed[label] =  Nicos::Converter.iso8601ToUnix(doc.value)        
          when "length"
            doc.read
            lengthStr = doc.value.split(/\:/)
            length   = lengthStr[0].to_i * 60 + lengthStr[1].to_i
            parsed["length"] =  length
          when "tags"
            doc.move_to_attribute("domain")
            category = doc.value
            if defined? parsed["tags" + category]
              parsed["tags_" + category] = []
            end  
          when "tag"      
            doc.read
            parsed["tags_" + category].push(doc.value)
          end  
        end
      end

      doc.close 
      parsed
    end

    # タグ検索のAtomフィードが返すXMLを解析し、ハッシュオブジェクトにして返します。
    #
    # @return [HashObj]  
    def tagAtom(xml)
      doc = XML::Reader.string(
        xml,
        :options => XML::Parser::Options::NOBLANKS |
        XML::Parser::Options::NOENT
      )
              
      n = -1
      parsed = [{}]

      while doc.read
        unless doc.node_type == XML::Reader::TYPE_END_ELEMENT
          case doc.name
          when "entry"
            n += 1
            parsed[n] = {}
          when "title"
            doc.read
            parsed[n]["title"] =  doc.value
          when "link"
            doc.move_to_attribute("href")
            parsed[n]["video_id"] =  doc.value.split('/')[4]
          when "published", "updated"
            label = doc.name
            doc.read
            parsed[n][label] =  Nicos::Converter.iso8601ToUnix(doc.value)
          when "p"
            doc.move_to_attribute("class")
            case doc.value
            when "nico-thumbnail"
              doc.read
              doc.move_to_attribute("src")
              parsed[n]["thumbnail_url"] =  doc.value
            when "nico-description"
              doc.read
              parsed[n]["description"] =  doc.value
            end
          when "strong"
            doc.move_to_attribute("class")
            case doc.value
            when "nico-info-length"
              doc.read
              lengthStr = doc.value.split(/\:/)
              length   = lengthStr[0].to_i * 60 + lengthStr[1].to_i
              parsed[n]["length"] =  length
            when "nico-numbers-view", "nico-numbers-res",
                  "nico-numbers-mylist"
              label = doc.value
              doc.read
              parsed[n][label.slice(13,99)] =  doc.value.to_i
            end
          end   
        end
      end

      doc.close    
      parsed
    end
     
    # マイリストのAtomフィードが返すXMLを解析し、ハッシュオブジェクトにして返します。
    #
    # @return [HashObj]  
    def mylistAtom(xml)    
      doc = XML::Reader.string(
        xml,
        :options => XML::Parser::Options::NOBLANKS |
        XML::Parser::Options::NOENT
      )
              
      n = -1
      parsed = { "mylist" => {}, "entry" => [{}] }
      while doc.read
        unless doc.node_type == XML::Reader::TYPE_END_ELEMENT
          case doc.name
          
          # <title> and <id> are marked up both in mylist and
          # each entry's node. So we need to assign the value to the
          # appropriate variable in accordance with node's location.
          when "title" 
            if n == -1
              doc.read
              d = doc.value
              tmp = doc.value.slice(6, 99)
              tmp = tmp.slice(0, tmp.length - 7)
              parsed["mylist"]["title"] = tmp
            else
              doc.read
              parsed["entry"][n]["title"] = doc.value
            end
          when "link"
            if n != -1
              doc.move_to_attribute("href")
              parsed["entry"][n]["video_id"] =
                Nicos::Extractor.videoId(doc.value)
            end
          when "subtitle"  
            doc.read
            parsed["mylist"]["description"] = doc.value
          when "id"
            if n == -1
              doc.read
              parsed["mylist"]["mylist_id"] = 
                Nicos::Extractor.mylistId(doc.value)
            else
              doc.read
              parsed["entry"][n]["item_id"] =
                Nicos::Extractor.itemId(doc.value)
            end    
          when "updated"
            doc.read
            parsed["mylist"]["updated"] = 
              Nicos::Converter.iso8601ToUnix(doc.value)
          when "name"
            doc.read
            parsed["mylist"]["author"] = doc.value              
          when "entry"
            n += 1
            parsed["entry"][n] = {}              
          when "content"
            doc.read
            html = doc.value   

            /(<p\sclass=\"nico-memo\"\>)([^\<]{1,})/ =~ html
            memo = $2
                     
            /(<p\sclass=\"nico-thumbnail\">.+src=\")(http:\/\/[^\"]{1,})/ =~ html
            thumbnail_url = $2
            
            /(<p\sclass\=\"nico-description\"\>)([^\<]{1,})/ =~ html
            description = $2

            /(<p\sclass\=\"nico-info-length\"\>)([^\<]{1,})/ =~ html
            length = $2

            /(<p\sclass\=\"nico-info-date\"\>)([^\<]{1,})/ =~ html
            first_retrieve = $2

            /(<p\sclass\=\"nico-numbers-view\"\>)([^\<]{1,})/ =~ html
            view = $2

            /(<p\sclass\=\"nico-numbers-res\"\>)([^\<]{1,})/ =~ html
            res = $2

            /(<p\sclass\=\"nico-numbers-mylist\"\>)([^\<]{1,})/ =~ html
            mylist = $2
            
            parsed["entry"][n]["memo"] = memo 
            parsed["entry"][n]["thumbnail_url"] = thumbnail_url 
            parsed["entry"][n]["description"] = description 
            parsed["entry"][n]["length"] = length 
            parsed["entry"][n]["first_retrieve"] = first_retrieve 
            parsed["entry"][n]["view"] = view
            parsed["entry"][n]["res"] = res 
            parsed["entry"][n]["mylist"] = mylist 
          end  
        end
      end

      doc.close 
      parsed
    end
      
    module_function :tagAtom
    module_function :mylistAtom
    module_function :getThumbInfo
  end
end