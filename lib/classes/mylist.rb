# -*- encoding: utf-8 -*-
$:.unshift File.dirname(__FILE__) 

require 'rubygems'
require 'kconv'

require 'parser.rb'
require 'movie.rb'
require 'connector.rb'


module Nicos
  class Mylist
    def initialize (mylist_id)
      @mylist_id  = mylist_id    
      @movies     = []
      @available  = false
    end

    # 自分に含まれている動画のタイトルをすべての組み合わせにおいて比較し、
    # 類似度の平均を返す。
    #
    # @return [Fixnum] 編集距離に基づく類似度。上限は1、下限はなし。
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

=begin
    # 自分に含まれている動画のタイトルをすべての組み合わせにおいて比較し、
    def getInfoHtml
      con = Nicos::Connector::Html.new('mech')
      reqUrl = 'http://www.nicovideo.jp' +
        '/mylist/' + @mylist_id.to_s
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
        :id            => id,
        :user_id       => user_id,
        :name          => name,
        :description   => description,
        :public        => public,
        :default_sort  => default_sort,
        :create_time   => create_time,
        :update_time   => update_time,
        :icon_id       => icon_id
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
=end
    # マイリストのAtomフィードから、マイリストとそれに含まれる動画の情報を取得する。
    #
    # @return [Fixnum] 編集距離に基づく類似度。上限は1、下限はなし。
    def getInfo
      con = Nicos::Connector::MylistAtom.new()
      host = 'www.nicovideo.jp'
      puts @mylist_id
      entity = '/mylist/' + @mylist_id.to_s + '?rss=atom&numbers=1'
      result = con.get(host, entity)

      if result[:order] == :afterTheSuccess
        parsed = Nicos::Parser::mylistAtom(result[:body])
        
        parsed[:entry].each { |e|
          movie = Nicos::Movie.new(e[:video_id])
          e[:available] = true
          movie.set(e)
          @movies.push(movie)
        }

        @available = true
        set(parsed[:mylist])
        { :result => parsed, :status => :success}
      else
        status = Nicos::Connector::convertSt(result[:status])
        @available = false
        { :result => nil, :status => status }
      end  
    end  

    # {Movie#set}　を参照。
    def set(paramObj)
      paramObj.each_key { |key|
        param = paramObj[key]
        case key
        when "mylist_id",  :mylist_id
          @mylist_id = param
        when "id",         :id
          @mylist_id = param
      	when "user_id",    :user_id
          @user_id = param
      	when "title",      :title
          @title = param
      	when "description",:description
          @description = param
      	when "public",     :public
          @public = param
      	when "default_sort",:default_sort
          @default_sort = param
      	when "create_time",:create_time
          @create_time = param
      	when "update_time",:updated_time
          @update_time = param
      	when "icon_id",    :icon_id
          @icon_id = param
      	when "sort_order", :sort_order
          @sort_order = param
      	when "movies",     :movies
          @movies = param

      	when "updated",    :updated
          @update_time = param
      	when "author",     :author
          @author = param
        end
      }   
    end

    include Nicos::Connector::SetWait 


    # このインスタンスがgetInfo等によって正常に情報を取得できている場合、trueとなる。
    # 各種メソッドの実行には、これがtrueであることが要求される。
    # 
    # @return [Boolean]
    attr_accessor :available

    # マイリストID
    #
    # @return [Fixnum]
    # <b>取得可能なメソッド</b> 
    # {Nicos::Movie#getInfo Mylist::getInfo}  
    # {Nicos::Movie#getInfo Mylist::getHtmlInfo}
    attr_accessor :mylist_id 

    # ユーザID
    #
    # @return [Fixnum]
    # <b>取得可能なメソッド</b> 
    # {Nicos::Movie#getInfo Mylist::getHtmlInfo}   
  	attr_accessor :user_id 

    # マイリストのタイトル
    #
    # @return [Fixnum]
    # <b>取得可能なメソッド</b> 
    # {Nicos::Movie#getInfo Mylist::getInfo}  
    # {Nicos::Movie#getInfo Mylist::getHtmlInfo}   
  	attr_accessor :title   

    # マイリストの説明文
    #
    # @return [Fixnum]
    # <b>取得可能なメソッド</b> 
    # {Nicos::Movie#getInfo Mylist::getInfo}  
    # {Nicos::Movie#getInfo Mylist::getHtmlInfo}    
  	attr_accessor :description

    # 公開設定
    #
    # 調査中
    # @return [Fixnum]
    # <b>取得可能なメソッド</b> 
    # {Nicos::Movie#getInfo Mylist::getInfo}  
    # {Nicos::Movie#getInfo Mylist::getHtmlInfo}  
  	attr_accessor :public 

    # ソート順の設定
    #
    # ソート順の設定
    # @return [Fixnum]
    # <b>取得可能なメソッド</b> 
    # {Nicos::Movie#getInfo Mylist::getInfo}  
    # {Nicos::Movie#getInfo Mylist::getHtmlInfo}    
  	attr_accessor :default_sort 

    # マイリスト作成日時
    #
    # @return [Fixnum]
    # <b>取得可能なメソッド</b> 
    # {Nicos::Movie#getInfo Mylist::getInfo}  
    # {Nicos::Movie#getInfo Mylist::getHtmlInfo}  
  	attr_accessor :create_time

    # マイリストの更新日時
    #
    # @return [Fixnum]
    # <b>取得可能なメソッド</b> 
    # {Nicos::Movie#getInfo Mylist::getInfo}  
    # {Nicos::Movie#getInfo Mylist::getHtmlInfo}  
  	attr_accessor :update_time  

    # アイコンの色？
    #
    # @return [Fixnum]
    # <b>取得可能なメソッド</b> 
    # {Nicos::Movie#getInfo Mylist::getInfo}  
    # {Nicos::Movie#getInfo Mylist::getHtmlInfo}
  	attr_accessor :icon_id

    # 現在のソート順
    #
    # @return [Fixnum]
    # <b>取得可能なメソッド</b> 
    # {Nicos::Movie#getInfo Mylist::getInfo}  
    # {Nicos::Movie#getInfo Mylist::getHtmlInfo}    
    attr_accessor :sort_order  

    # 作成者の名前
    #
    # @return [Fixnum]
    # <b>取得可能なメソッド</b> 
    # {Nicos::Movie#getInfo Mylist::getInfo}  
    attr_accessor :author

    # マイリストが含む動画インスタンスの配列
    #
    # getInfo等のメソッドを利用した際に、そのマイリストが含む動画の
    # インスタンスが配列として自動的に作られ、moviesに収められる。
    # @return [Array<Movie>] 
    attr_accessor :movies   
  end
end