# -*- encoding: utf-8 -*-
$:.unshift File.dirname(__FILE__) 

require 'rubygems'
require 'ruby-debug'
require 'damerau-levenshtein'
require 'kconv'

require 'parser.rb'
require 'mylist.rb'
require 'connector.rb'
  
class Movie  
  def initialize(video_id)
    @video_id   = video_id
    @available  = false
  end
  
  private
   
  public
  
  # 指定されたマイリストに自分が入っていれば、真を返す。  
  def isBelongsTo (mylistId, &block)
    isBelongs = false
    thisMl = Mylist.new(mylistId)
    thisMl.getInfoLt
    
    thisMl.movies.each { |movie|
      isBelongs = true if movie.video_id == @video_id
    }   
  
    if isBelongs
      puts "\sThis movie is found in mylist/" + mylistId.to_s
    else
      puts "\sThis movie is not found in mylist/" + mylistId.to_s
    end
    
    # 無駄なアクセスを省くため、マイリスト中の動画に関する追加処理があれば、
    # ブロックとして実行できる。
    block.call(thisMl) if block != nil
    
    return isBelongs
  end
  
  # 自分が含まれる、投稿者の作ったシリーズとしてまとめているマイリストのIDを返す。
  # 情報取得元が異なるため、必ずしもisBelongsの結果とは包含関係にならない。
  def isSeriesOf
    if !@available then
      puts "This movie object is not available."
      return "failed"
    end
    
    puts
    puts "Start to discern the seriality of..."
    puts "\svideo_id:\s\s" + @video_id
    puts "\stitle:\s\s\s\s\s" + @title    
    # extrMylist呼び出し
    mylistIdAry = extrMylist
    sMylistIdAry = []
    mlObjAry = []
    mylistId = nil
    mylist = nil
    similarity = 0.0
    
    mylistIdAry.each { |_mylistId|
      belongsTo = isBelongsTo(_mylistId) { |mylistObj|        
        similarity = mylistObj.getSimilarity 
        puts "\sSimilarity:\t" + similarity.to_s
      }
      puts belongsTo
      if belongsTo && similarity > 0.7
        puts "\s" + _mylistId.to_s + "\tis perecieved as series mylist."
        sMylistIdAry.push(_mylistId)
      end  
    }
    
    sMylistIdAry.each { |mylistId|
      puts mylistId
      mlObjAry.push( Mylist.new(mylistId) )
    }
    
    puts "\sDiscern logic terminated."
    return mlObjAry   
  end

  # 動画説明文中から、マイリストIDを示す文字列を抜き出す。
  def extrMylist
    return if !@available
    puts "Extracting mylistId from the description..."
    
    mylistIdAry = []
    extracted = @description.scan(/mylist\/[0-9]{1,8}/)
    if extracted[0] != nil
      extracted.each { |e|
        id = e.scan(/[0-9]{1,8}/)[0]
        mylistIdAry.push(id)
        puts "\sID:\t" + id + " is extracted."
      }
    else
      puts "\sMylistId is not found."
    end  
    
    return mylistIdAry
  end
  
  def getInfo
    con = GetThumbInfoConnector.new()
    host = 'ext.nicovideo.jp'
    entity = '/api/getthumbinfo/' + @video_id
    con.setWait(nil)
    result = con.get(host, entity)

    if
      result["order"] == "success"
    then
      parsed = NicoParser.getThumbInfo(result["body"])
      set(parsed)
      @available = true
    else
      @available = false
    end
  end
    
  def set(paramObj)
    paramObj.each_key { |key|
      param = paramObj[key]
      case key
      when "available"
        @available = param
        
      when "video_id"
        @video_id = param
      when "mylist_id"    
        @mylist_id = param
    	when "item_id"
        @item_id = param
    	when "description"
        @description = param
      
      # MylistAPI
      when "video_id"
        @video_id = param
    	when "item_id"
        @item_id = param.to_i
    	when "description"
        @description = param        
      when "item_data"
        paramObj['item_data'].each_key { |key|
        param = paramObj['item_data'][key]
          case key
          when "video_id"
            @video_id = param   
        	when "title"
            @title = param
        	when "thumbnail_url"
            @thumbnail_url = param
        	when "first_retrieve"
            @first_retrieve = param
        	when "update_time"
            @update_time = param
        	when "view_counter"
            @view_counter = param.to_i
        	when "mylist_counter"
            @mylist_counter = param.to_i
        	when "num_res"
            @comment_num = param.to_i
        	when "length_seconds"
            @length = param
        	when "deleted"
            @deleted = param.to_i       
        	when "last_res_body"
            @last_res_body = param
          end
        } 
    	when "watch"
        @watch = param
    	when "create_time"
        @create_time = param
    	when "update_time"
        @update_time = param
      
      # MylistAPI-Atom
      when "video_id"
        @video_id = param
    	when "item_id"
        @item_id = param
    	when "memo"
        @memo = param        
    	when "published"
        @published = param       
    	when "updated"
        @updated = param    
    	when "thumbnail_url"
        @thumbnail_url = param     
    	when "length"
        @length = param
    	when "view"
        @view_counter = param.to_i
    	when "mylist"
        @mylist_counter = param.to_i
    	when "res"
        @comment_num = param.to_i     
    	when "first_retrieve"
        @first_retrieve = param       
    	when "length"
        @length = param        
      
      # getThumbInfo  
      when "video_id"
        @video_id = param   
    	when "title"
        @title = param
    	when "description"
        @description = param  
    	when "thumbnail_url"
        @thumbnail_url = param
    	when "first_retrieve"
        @first_retrieve = param
    	when "length"
        @length = param
    	when "movie_type"
        @movie_type = param
      when "size_high"
        @size_high = param
    	when "size_low"
        @size_low = param
    	when "view_counter"
        @view_counter = param
    	when "mylist_counter"
        @mylist_counter = param
    	when "comment_num"
        @comment_num = param
    	when "last_res_body"
        @last_res_body = param
    	when "watch_url"
        @watch_url = param
    	when "thumb_type"
        @thumb_type = param
    	when "embeddable"
        @embeddable = param
    	when "no_live_play"
        @no_live_play = param
    	when "tags_jp"
        @tags_jp = param
      when "tags_tw"
        @tags_tw = param
    	when "tags_de"
        @tags_de = param
      when "tags_sp"
        @tags_sp = param
    	when "user_id"
        @user_id = param
      end
    }   
  end  
  
  attr_accessor :available
  
  # MylistAPI   
  attr_accessor	:video_id
  attr_accessor	:mylist_id
  attr_accessor	:item_id
  attr_accessor	:description

  attr_accessor	:title
  attr_accessor	:thumbnail_url
  attr_accessor	:first_retrieve
  attr_accessor	:update_time
  attr_accessor	:view_counter
  attr_accessor	:mylist_counter
  attr_accessor	:comment_num
  attr_accessor	:length
  attr_accessor	:deleted
  attr_accessor	:last_res_body

  attr_accessor	:watch
  attr_accessor	:create_time
  attr_accessor	:update_time

  # MylistAPI-Atom
  attr_accessor :memo
  attr_accessor	:published
  attr_accessor	:updated
  
  # getThumbInfo
  attr_accessor	:movie_type
  attr_accessor	:size_high
  attr_accessor	:size_low
  attr_accessor	:watch_url
  attr_accessor	:thumb_type
  attr_accessor	:embeddable
  attr_accessor	:no_live_play
  attr_accessor	:tags_jp
  attr_accessor	:tags_tw
  attr_accessor	:user_id
end
