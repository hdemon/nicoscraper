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

    private

    def ngram(data, n)
      ret = []
      data.split(//u).each_cons(n) do |a|
        ret << a.join
      end
      ret
    end

    def sim(a, b, n)
      agram = ngram(a, n)
      bgram = ngram(b, n)

      all  = (agram | bgram).size.to_f
      same = (agram & bgram).size.to_f

      (same / all).nan? ? 0 : (same / all)
    end

    def connect(connector, type)
      host = 'www.nicovideo.jp'
      entity = "/mylist/#{@mylist_id.to_s}"
      param = (type == :atom ? '?rss=atom&numbers=1' : '')

      result = connector.get(host, entity, param)
      status = connector.getStatus

      { :result => result, :status => status }
    end

    def parse(result, &block)
      if result[:order] == :afterTheSuccess
        parsed = block.call(result)
        
        parsed[:entry].each do |e|
          movie = Nicos::Movie.new(e[:video_id])
          e[:available] = true
          movie.set(e)
          @movies.push(movie)
        end if parsed[:entry] != nil

        set(parsed[:mylist])
        @available = true
        parsed
      end 
    end

    public

    # 自分に含まれている動画のタイトルをすべての組み合わせにおいて比較し、
    # 類似度の平均を返す。
    #
    # @return [Fixnum] 編集距離に基づく類似度。上限は1、下限はなし。
    def getSimilarity
      l = @movies.length - 1
      sim = 0.0
      simAry = []
      count_o = 0
      count_i = 0
      
      @movies.each do |movie|
        puts "\s" + movie.title
      end

      if @movies.length >= 2 
        while count_o <= l do
          count_i = count_o + 1
          while count_i <= l do
            simAry.push(
              sim(
                @movies[count_i].title, 
                @movies[count_o].title,
                3
              )
            )
            count_i += 1
          end
          count_o += 1
        end
      
        t = 0
        simAry.each { |_sim| t += _sim }
        similarity = t / simAry.length
      elsif @movies.length == 1
        similarity = 1
      else
        similarity = 0
      end
          p similarity
      ( similarity * 100 ).round / 100.0 
    end


    # マイリストのAtomフィードから、マイリストとそれに含まれる動画の情報を取得する。
    #
    # @return [Fixnum] Trigram法による、
    def getInfo
      parsed = nil
      @available = false

      res = connect( 
        Nicos::Connector::MylistAtom.new(), 
        :atom )
      parse = parse(res[:result]) do |result|
        Nicos::Parser::Xml::mylistAtom(result[:body])
      end

      { 
        :parsed  => parse, 
        :status  => res[:status][:status],
        :retry   => res[:status][:retry]
      }      
    end  

    def getMoreInfo
      parsed = nil
      @available = false

      res = connect( 
        Nicos::Connector::MylistHtml.new(),
        :html )
      parse = parse(res[:result]) do |result|
        Nicos::Parser::Html::mylist(result[:body])
      end

      { 
        :parsed  => parse, 
        :status  => res[:status][:status],
        :retry   => res[:status][:retry]
      }      
    end   

    # {Movie#set}　を参照。
    def set(paramObj)
      paramObj.each_key do |key|
        param = paramObj[key]
        case key
        when "mylist_id",  :mylist_id     then @mylist_id = param.to_i
        when "user_id",    :user_id       then @user_id = param.to_i
        when "title",      :title         then @title = param
        when "description",:description   then @description = param
        when "public",     :public        then @public = param.to_i
        when "default_sort",:default_sort then @default_sort = param.to_i
        when "create_time",:create_time   then @create_time = param.to_i
        when "update_time",:update_time   then @update_time = param.to_i
        when "icon_id",    :icon_id       then @icon_id = param.to_i
        when "sort_order", :sort_order    then @sort_order = param.to_i
        when "movies",     :movies        then @movies = param
        when "updated",    :updated       then @update_time = param
        when "author",     :author        then @author = param
        end
      end   
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
    # @return [String]
    # <b>取得可能なメソッド</b> 
    # {Nicos::Movie#getInfo Mylist::getInfo}  
    # {Nicos::Movie#getInfo Mylist::getHtmlInfo}   
    attr_accessor :title   

    # マイリストの説明文
    #
    # @return [String]
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
    # @return [String]
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