# -*- encoding: utf-8 -*-
$:.unshift File.dirname(__FILE__) 

require 'rubygems'
require 'xml'
require 'time'

require 'converter.rb'

module Nicos
  module Parser
    def parseRow(symbol, type, doc)
      hash = {}      

      value = case type
      when :Fixnum  then
        doc.read
        doc.value.to_i
      when :String  then 
        doc.read
        doc.value
      when :ISO8601 then 
        doc.read
        Nicos::Converter.iso8601ToUnix(doc.value) 
      when :JapDate then 
        doc.read
        Nicos::Converter.japToUnix(doc.value)
      when :Time    then 
        doc.read
        Nicos::Converter.toSeconds(doc.value)

      # for Mylist Atom
      when :mylistId then
        doc.read
        Nicos::Extractor.mylistId(doc.value) 
      when :videoId then
        doc.move_to_attribute("href")
        Nicos::Extractor.videoId(doc.value) 

      # for getThumbInfo
      when :Tags    then
        doc.move_to_attribute("domain")
        symbol = case doc.value
        when "jp" then :tags_jp
        when "tw" then :tags_tw
        when "de" then :tags_de
        when "es" then :tags_es
        end

        tags = []
        lockedTags = []
            category = nil
            lock = nil

        while doc.read
          unless doc.node_type == XML::Reader::TYPE_END_ENTITY
            break if doc.name === "tags"

            if category == nil
              doc.move_to_attribute("category")
              if doc.name === "category"
                doc.read
                category = doc.value 
                doc.read
              end
            end

            doc.move_to_attribute("lock")
            if doc.name === "lock"
              lock = true
              doc.read
              doc.read
            else lock = false
            end

            doc.read_inner_xml
            if doc.value != nil  
              if lock then lockedTags.push(doc.value) 
              else tags.push(doc.value) end
            end   
          end
        end

        {
          :category => category,
          :tags     => tags,
          :lockedTags => lockedTags
        }
      end 
      
      hash[symbol] = value
      hash
    end
    module_function :parseRow

    def parseTag
    end

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

      while doc.read
        unless doc.node_type == XML::Reader::TYPE_END_ELEMENT
          row = case doc.name
          when "video_id"       then parseRow(:video_id,      :String,  doc)
          when "title"          then parseRow(:title,         :String,  doc)
          when "description"    then parseRow(:description,   :String,  doc)
          when "thumbnail_url"  then parseRow(:thumbnail_url, :String,  doc)
          when "movie_type"     then parseRow(:movie_type,    :String,  doc)
          when "last_res_body"  then parseRow(:last_res_body, :String,  doc)
          when "watch_url"      then parseRow(:watch_url,     :String,  doc)
          when "thumb_type"     then parseRow(:thumb_type,    :String,  doc)

          when "size_high"      then parseRow(:size_high,     :Fixnum,  doc) 
          when "size_low"       then parseRow(:size_low,      :Fixnum,  doc) 
          when "view_counter"   then parseRow(:view_counter,  :Fixnum,  doc) 
          when "comment_num"    then parseRow(:comment_num,   :Fixnum,  doc) 
          when "mylist_counter" then parseRow(:mylist_counter,:Fixnum,  doc) 
          when "embeddable"     then parseRow(:embeddable,    :Fixnum,  doc) 
          when "no_live_play"   then parseRow(:no_live_play,  :Fixnum,  doc) 
          when "user_id"        then parseRow(:user_id,       :Fixnum,  doc) 
          when "first_retrieve" then parseRow(:first_retrieve,:ISO8601, doc)       
          when "length"         then parseRow(:length,        :Time,    doc) 
          when "tags"           then parseRow(:tags,          :Tags,    doc) 
          when "tag"            then parseRow(:tag,           :Tag,     doc) 
          end

          parsed.update(row) if row != nil
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
            parsed[n][:title] = doc.value
          when "link"
            doc.move_to_attribute("href")
            parsed[n][:video_id] = doc.value.split('/')[4]
          when "published", "updated"
            label = doc.name
            doc.read
            parsed[n][label] = Nicos::Converter.iso8601ToUnix(doc.value)
          when "p"
            doc.move_to_attribute("class")
            case doc.value
            when "nico-thumbnail"
              doc.read
              doc.move_to_attribute("src")
              parsed[n][:thumbnail_url] = doc.value
            when "nico-description"
              doc.read
              parsed[n][:description] = doc.value
            end
          when "strong"
            doc.move_to_attribute("class")
            case doc.value
            when "nico-info-length"
              doc.read
              parsed[n][:length] = Nicos::Converter.toSeconds(doc.value)
            when "nico-info-date"
              label = doc.name
              doc.read
              parsed[n][:first_retrieve] = Nicos::Converter.japToUnix(doc.value)
            when "nico-numbers-view", "nico-numbers-res",
                  "nico-numbers-mylist"
              label = doc.value
              doc.read
              parsed[n][label.slice(13,99)] = Nicos::Converter::commaRemover(doc.value)
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
              
      n = 0
      parsed = { :mylist => {}, :entry => [{}] }

      while doc.read
        break if doc.name === "entry"

        unless doc.node_type == XML::Reader::TYPE_END_ELEMENT
          row = case doc.name
          when "title" then
            /(マイリスト)(.+)(‐ニコニコ動画)/ =~ parseRow(:title, :String,  doc)["title"]
            $2
          when "id"       then parseRow(:mylist_id,   :String,  doc)
          when "subtitle" then parseRow(:descrpition, :String,  doc)
          when "updated"  then parseRow(:updated,     :ISO8601, doc)
          when "name"     then parseRow(:author,      :String,  doc)
          end

          parsed[:mylist].update(row) if row != nil           
        end
      end

      while doc.read
        unless doc.node_type == XML::Reader::TYPE_END_ELEMENT
          # bump up the page number
          if doc.name === "entry"
            n += 1
            parsed[:entry][n] = {}              
          end

          row = case doc.name
          # <title> and <id> are marked up both in mylist and
          # each entry's node. So we need to assign the value to the
          # appropriate variable in accordance with node's location.
          when "title" then parseRow(:title,    :String,  doc)
          when "link"  then parseRow(:video_id, :videoId, doc)
          when "id"    then parseRow(:item_id,  :itemId,  doc)
          when "content"
            doc.read
            html = doc.value   

            /(<p\sclass=\"nico-memo\"\>)([^\<]{1,})/ =~ html
            memo = $2
                     
            /(<p\sclass=\"nico-thumbnail\">.+src=\")(http:\/\/[^\"]{1,})/ =~ html
            thumbnail_url = $2
            
            /(<p\sclass\=\"nico-description\"\>)([^\<]{1,})/ =~ html
            description = $2

            /(<strong\sclass\=\"nico-info-length\"\>)([^\<]{1,})/ =~ html
            length = Nicos::Converter.toSeconds($2)

            /(<strong\sclass\=\"nico-info-date\"\>)([^\<]{1,})/ =~ html
            first_retrieve = Nicos::Converter.japToUnix($2)

            /(<strong\sclass\=\"nico-numbers-view\"\>)([^\<]{1,})/ =~ html
            view = Nicos::Converter.commaRemover($2)

            /(<strong\sclass\=\"nico-numbers-res\"\>)([^\<]{1,})/ =~ html
            res = Nicos::Converter.commaRemover($2)

            /(<strong\sclass\=\"nico-numbers-mylist\"\>)([^\<]{1,})/ =~ html
            mylist = Nicos::Converter.commaRemover($2)
            
            {
              :memo             => memo,
              :thumbnail_url    => thumbnail_url,
              :descrpition      => description,
              :length           => length,
              :first_retrieve   => first_retrieve,
              :view             => view,
              :res              => res,
              :mylist           => mylist
            } 
          end 

          parsed[:entry][n].update(row) if row != nil  
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