# -*- encoding: utf-8 -*-
$:.unshift File.dirname(__FILE__) 

require 'rubygems'
require 'xml'
require 'time'
require 'json'

require 'converter.rb'

module Nicos
  module Parser
    module Xml
      def parseRow(symbol, type, doc)
        hash = {}

        value = case type
        # common
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
        when :itemId then
          doc.read
          Nicos::Extractor.itemId(doc.value)
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
          locked = false
          prev = nil
          now = nil

          while doc.read
            unless doc.node_type == XML::Reader::TYPE_END_ENTITY
              # 終了を判別。もっと環境に依存しない上手いやり方があるはず。
              break if doc.name == "tags"

              if prev == :end
                category = false
                locked = false
              end

              doc.move_to_attribute("category")
              category = true if doc.name == "category"

              doc.move_to_attribute("lock")
              locked = true if doc.name == "lock"

              # ノードの開始、値、終了を判別する。
              # 例えば<tag>と<tag lock="1"/>が、どちらも'2'と解釈され、開始と終了が区別しづらい。
              #http://dotgnu.org/pnetlib-doc/System/Xml/XmlNodeType.html
              nt = doc.node_type 
              now = if (nt == 2 || nt == 1) && prev != :val then :start
              elsif (nt == 2 || nt == 15) && prev == :val then :end
              elsif nt == 3 then :val
              end

              val = doc.read_outer_xml

              #puts
              #puts now              
              #puts val
              #puts "cat:#{category} locked:#{locked}"

              if now == :val
                obj = { "value" => val }
                obj.merge!({ :locked => true }) if locked == true
                obj.merge!({ :category => true }) if category == true

                tags.push(obj)
              end

              prev = now
            end
          end

          tags
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
              /(マイリスト )(.+)(‐ニコニコ動画)/ =~ parseRow(:title, :String,  doc)[:title]
              { :title => $2 }
            when "id"       then parseRow(:mylist_id,   :mylistId,doc)
            when "subtitle" then parseRow(:description, :String,  doc)
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
              
              /(<p\sclass=\"nico-description\"\>)([^\<]{1,})/ =~ html
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
                :description      => description,
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

    module Html
      def mylist(html)
        rawScript = html.scan(
          /\<script\stype\=\"text\/javascript\">.[^<]{1,}/
        )[6]
        
        /(Jarty\.globals\()(\{([^}]|\}[^)])+)/ =~ rawScript
        s = $2
        
        /(user_id:\s)([0-9]{1,})/ =~ s
        user_id   = $2
        
        /(nickname:\s\")([^"]{1,})/ =~ s
        author    = $2

        /(MylistGroup\.preload)(([^;]|[^)]\;)+)/ =~ rawScript
        s = $2

        /(name:\s\")([^"]{1,})/ =~ s
        title = $2

        /(description:\s\")([^"]{1,})/ =~ s
        description = $2

        /(id:\s)([0-9]{1,})/ =~ s
        mylist_id   = $2     
           
        /(public:\s)([0-9]{1,})/ =~ s
        public   = $2      
          
        /(default_sort:\s)([0-9]{1,})/ =~ s
        default_sort   = $2  
                
        /(create_time:\s)([0-9]{1,})/ =~ s
        create_time   = $2  
                
        /(update_time:\s)([0-9]{1,})/ =~ s
        update_time   = $2  
                
        /(icon_id:\s)([0-9]{1,})/ =~ s
        icon_id   = $2

       
        /(Mylist\.preload\([0-9]{1,}\,)(.+(?=\]\)\;))/ =~ rawScript
        if $2 != nil
          s = $2 + "]"
          entry = JSON.parse(s)
        else
          entry = nil
        end

        parse = {
          :mylist => {
            :user_id      => user_id,
            :author       => author,
            :title        => title,
            :description  => description,
            :mylist_id    => mylist_id,
            :public       => public,
            :default_sort => default_sort,
            :create_time  => create_time,
            :update_time  => update_time,
            :icon_id      => icon_id
          },
          :entry => entry
        }

        parse
      end

      module_function :mylist
    end
  end
end
