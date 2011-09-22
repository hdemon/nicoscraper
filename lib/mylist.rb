﻿# -*- encoding: utf-8 -*-
$:.unshift File.dirname(__FILE__) 

require 'rubygems'
require 'ruby-debug'
require 'kconv'

require 'parser.rb'
require 'movie.rb'
require 'connector.rb'

class Nicos::Mylist
  def initialize (mylist_id)
    @mylist_id  = mylist_id    
    @movies     = []
    @available  = false
  end
  
  # 自分に含まれている動画のタイトルをすべての組み合わせにおいて比較し、
  # 類似度の平均を返す。
  def getSimilarity
    l = @movies.length - 1
    dlc = DamerauLevenshtein
    dl = 0.0
    dlAry = []
    count_o = 0
    count_i = 0
    
    while count_o <= l do
      count_i = count_o + 1
      while count_i <= l do
        dl = dlc.distance(
          @movies[count_i].title, 
          @movies[count_o].title
        )
        
        dl = 1.0 - dl.fdiv( @movies[count_i].title.length)
        dlAry.push(dl)
        
        count_i += 1
      end
      count_o += 1
    end
    
    if l != 0 && dlAry.length > 0
      t = 0
      dlAry.each { |_dl| t += _dl }
      similarity = t / dlAry.length
    elsif dlAry.length == 0
      similarity = 0
    else
      similarity = 1
    end
        
    return similarity
  end

  def getInfo
    con = Nicos::Connector::Html.new('mech')
    reqUrl = 'http://www.nicovideo.jp' +
      '/mylist/' + @mylist_id.to_s
    con.setWait(nil)
    mechPage = con.mechGet(reqUrl)
    result = []

    # Mylist自身の情報を取得    
    jsonStr = mechPage.search(
      "/html/body/div[2]" +
      "/div/div[2]/script[7]"
    ).to_html
    
    reg = /MylistGroup\.preloadSingle.{1,}?Mylist\.preload\(/m
    mlJson = jsonStr.scan(reg)[0]
      
    id = mlJson.scan(/\sid:[^\n]{1,}/)[0]
        .scan(/[0-9]{1,}/)[0]
    user_id = mlJson.scan(/\suser_id:[^\n]{1,}/)[0]
        .scan(/[0-9]{1,}/)[0]
    name = mlJson.scan(/\sname:[^\n]{1,}/)[0]
      name = name.slice(
        " name: \"".length,
        name.length - " name: \"".length - "\",\n".length
      )
    desc = mlJson.scan(/\sdescription:.{1,}/)[0]
      desc = desc.slice(
        " description: \"".length,
        desc.length - " description: \"".length - "\",\npublic".length
      )
    public = mlJson.scan(/\spublic:[^,]{1,}/)[0]
        .scan(/[0-9]{1,}/)[0]
    default_sort = mlJson.scan(/\sdefault_sort:[^\n]{1,}/)[0]
        .scan(/[0-9]{1,}/)[0]
    create_time = mlJson.scan(/\screate_time:[^\n]{1,}/)[0]
        .scan(/[0-9]{1,}/)[0]
    update_time = mlJson.scan(/\supdate_time:[^\n]{1,}/)[0]
        .scan(/[0-9]{1,}/)[0]
    icon_id = mlJson.scan(/\sicon_id:[^\n]{1,}/)[0]
        .scan(/[0-9]{1,}/)[0]
 
   # mlJson = mlJson.scan(/[^\r\n  ]{1,}/).join('')
    #mlJson = mlJson.scan(/{.+/)[0].split(',')
    
    # 説明文が空欄だった時の措置。
    desc   = mlJson[3].scan(/\".+\"/)[0]
    if desc != nil then desc = desc.scan(/[^\"]{1,}/)[0] end

    paramObj = {
      "id"            => id,
      "user_id"       => user_id,
      "name"          => name,
      "description"   => description,
      "public"        => public,
      "default_sort"  => default_sort,
      "create_time"   => create_time,
      "update_time"   => update_time,
      "icon_id"       => icon_id
      # "sort_order"  => ,
    }
    set(paramObj)  
    
    # 自分に含まれる動画の情報を取得
    jsonStr = mechPage.search(
      "/html/body/div[2]" +
      "/div/div[2]/script[7]"
    ).to_html

    mvJson = jsonStr.scan(/Mylist.preload.+/)[0]
    mvJson = mvJson.scan(/\".{1,}/)[0]
    mvJson = mvJson.slice(0, mvJson.length - 5)
    #mvJson = mvJson.split('},{')
    mvJson = Nicos::Unicode.unescape(mvJson).split('},{')
    
    mvJson.each { |e|
      e = "{" + e + "}"
      param = JSON.parse(e) 
      movie = Nicos::Movie.new(param['item_data']['video_id'])
      movie.set(param)
      
      @movies.push(movie)
    }    
  end
  
  def getInfoLt
    con = Nicos::Connector::MylistAtom.new()
    host = 'www.nicovideo.jp'
    puts @mylist_id
    entity = '/mylist/' + @mylist_id.to_s + '?rss=atom&numbers=1'
    con.setWait(nil)
    result = con.get(host, entity)

    if
      result["order"] == "success"
    then
      parsed = Nicos::Parser::mylistAtom(result["body"])
      
      parsed["entry"].each { |e|
        movie = Nicos::Movie.new(e["video_id"])
        e["available"] = true
        movie.set(e)
        @movies.push(movie)
      }

      @available = true
      set(parsed["mylist"])
      p self
    else
      @available = false
    end  
  end  

  def set(paramObj)
    paramObj.each_key { |key|
      param = paramObj[key]
      case key
      when "mylist_id"    
        @mylist_id = param
      when "id"    
        @mylist_id = param
    	when "user_id"
        @user_id = param
    	when "title"
        @title = param
    	when "description"
        @description = param
    	when "public"
        @public = param
    	when "default_sort"
        @default_sort = param
    	when "create_time"
        @create_time = param
    	when "update_time"
        @update_time = param
    	when "icon_id"
        @icon_id = param
    	when "sort_order"
        @sort_order = param
    	when "movies"
        @movies = param

    	when "updated"
        @update_time = param
    	when "author"
        @author = param
      end
    }   
  end

  attr_accessor :available
    
  attr_accessor :mylist_id    
	attr_accessor :user_id    
	attr_accessor :title       
	attr_accessor :description  
	attr_accessor :public     
	attr_accessor :default_sort   
	attr_accessor :create_time  
	attr_accessor :update_time  
	attr_accessor :icon_id    
  attr_accessor :sort_order   
  attr_accessor :author   
  
  attr_accessor :movies     
end