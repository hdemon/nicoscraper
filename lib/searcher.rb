# -*- encoding: utf-8 -*-# -*- encoding: utf-8 -*-
$:.unshift File.dirname(__FILE__)

require 'rubygems'
require 'ruby-debug'

require 'time'
require 'mechanize'
require 'kconv'

require 'namespace.rb'
require 'parser.rb'

module Nicos::Searcher
  # :nodocs:
  class ByTagSuper
    private

    def get(tag, sort, page, method, waitObj)
      paramAry = []

      case sort
        when 'comment_new'
          sortStr = ''
        when 'comment_old'
          sortStr = 'order=a'
        when 'view_many'
          sortStr = 'sort=v'
        when 'view_few'
          sortStr = 'sort=v&order=a'
        when 'comment_many'
          sortStr = 'sort=r'
        when 'comment_few'
          sortStr = 'sort=r&order=a'
        when 'mylist_many'
          sortStr = 'sort=m'
        when 'mylist_few'
          sortStr = 'sort=m&order=a'
        when 'post_new'
          sortStr = 'sort=f'
        when 'post_old'
          sortStr = 'sort=f&order=a'
        when 'length_long'
          sortStr = 'sort=l'
        when 'length_short'
          sortStr = 'sort=l&order=a'
      end

      paramAry.push("page=#{page}") if page != 1
      paramAry.push(sortStr)
      if method == "atom" then paramAry.push("rss=atom&numbers=1") end
      param = tag + "?" + paramAry.join('&')

      host = 'www.nicovideo.jp'
      entity = '/tag/' + param

      @connector.setWait(waitObj)
      @connector.get(host, entity)
    end

    def loop(tag, sort, method, waitObj, &block)
      termFlag    = false
      page        = 1
      movieObjAry = []

      begin
         response = get(
          tag,
          sort,
          page,
          method,
          waitObj
        )

        if response["order"] == "success"
          result = parse(response["body"])
          result.each { |each|
            movie = Nicos::Movie.new(each["video_id"])
            each["available"] = true
            movie.set(each)
            movieObjAry.push(movie)
          }

          termFlag = block.call(movieObjAry, page)
        else
          termFlag = true
        end

        page += 1
      end until termFlag
    end
  end

  class ByTagHtml < ByTagSuper
    def initialize
      @numOfSearched = 32
      @incrAmt = 0.2

      @connector = Nicos::Connector.new('mech')

      # HTML中の各パラメータの所在を示すXPath
      @videoIdXP  = "//div[@class='uad_thumbfrm']/table/tr/td/p/a"
      @lengthXP   = "//div[@class='uad_thumbfrm']/table/tr/td/p[2]/span"
      @viewXP     = "//div[@class='uad_thumbfrm']/table/tr/td[2]/div/nobr[1]/strong"
      @resXP      = "//div[@class='uad_thumbfrm']/table/tr/td[2]/div/nobr[2]/strong"
      @mylistXP   = "//div[@class='uad_thumbfrm']/table/tr/td[2]/div/nobr[3]/a/strong"
      @adXP       = "//div[@class='uad_thumbfrm']/table/tr/td[2]/div/nobr[4]/a/strong"
    end

    private

    def parse(movieNum)
      result = []

      video_id  = /(sm|nm)[0-9]{1,}/.match(@connector.mech.page.search(@videoIdXP)[movieNum]['href'])[0]
        lengthStr = @connector.mech.page.search(@lengthXP)[movieNum].text.split(/\:/)
      length    = lengthStr[0].to_i * 60 + lengthStr[1].to_i
      view      = @connector.mech.page.search(@viewXP)[movieNum]
                  .text.gsub(/\,/, '').to_i
      res       = @connector.mech.page.search(@resXP)[movieNum]
                  .text.gsub(/\,/, '').to_i
      mylist    = @connector.mech.page.search(@mylistXP)[movieNum]
                  .text.gsub(/\,/, '').to_i
      ad        = @connector.mech.page.search(@adXP)[movieNum]
                  .text.gsub(/\,/, '').to_i

      result.push({
        "video_id"  => video_id,
        "length"    => length,
        "view"      => view,
        "res"       => res,
        "mylist"    => mylist,
        "ad"        => ad
      })
    end

    public
    
    # @param [String] tag
    # @param [String] sortMethod
    # @param [HashObj] waitConfig
    def execute(tag, sortMethod, waitConfig, &block)
      loop(tag, sort, "mech", waitObj) { |result, page|
        block.call(result, page)
      }
    end
  end

  class ByTag < ByTagSuper
    def initialize
      @numOfSearched = 32
      @incrAmt = 0.2
      @connector = Nicos::Connector::TagAtom.new()
    end

    private 

    def parse(xml)
      Nicos::Parser.tagAtom(xml)
    end

    public

    # 実行
    #
    # @param [String] tag 検索したいタグ文字列
    # @param [String] sortMethod ソート方法
    #==sortMethod: ソート方法
    # *comment_new*  
    # コメントが新しい順
    # 
    # *comment_old*  
    # コメントが新しい順
    # 
    # *view_many*  
    # 再生数が多い順
    # 
    # *view_few*  
    # 再生数が少ない順
    # 
    # *comment_many*  
    # コメントが多い順
    # 
    # *comment_few*  
    # コメントが少ない順
    # 
    # *mylist_many*  
    # マイリスト登録が多い順
    # 
    # *mylist_few*  
    # マイリスト登録が少ない順
    # 
    # *post_new*  
    # 登録が新しい順
    # 
    # *post_old*  
    # 登録が少ない順
    # 
    # *length_long*  
    # 再生時間が長い順
    # 
    # *length_short*  
    # 再生時間が短い順
    # 
    # @param [HashObj] waitConfig ウェイト設定
    #==waitConfig: ウェイト設定
    # <b>ウェイトの変更に際しては、READMEの注意点と免責事項を事前にお読み下さい。</b>
    #
    # 以下のフォーマットのハッシュオブジェクトを与えて下さい。これはデフォルト設定です。
    # また、ハッシュは以下のキーを全て用意する必要はありません。
    # 変更したい部分のキーと値のみを持つハッシュオブジェクトを作って下さい。
    #
    #  @waitConfig = {
    #    'seqAccLimit' => 10,  # 連続してリクエストする回数
    #    'afterSeq'    => 10,  # 連続リクエスト後のウェイト（以下、単位は全て秒）
    #    'each'        => 1,   # 連続リクエスト時の、1リクエスト毎のウェイト
    #    'increment'   => 1,   # アクセス拒絶時の、次回以降の1リクエスト毎のウェイトの増加量
    # 
    #    'deniedSeqReq'=> {     # 連続アクセスを拒否された際の設定（以下同じ）
    #      'retryLimit'  => 3,  # 再試行の上限回数
    #      'wait'        => 120 # 次のアクセスまでのウェイト
    #    },
    #    
    #    'serverIsBusy'=> {     # サーバ混雑時
    #      'retryLimit'  => 3,
    #      'wait'        => 120
    #    },
    #    
    #    'serviceUnavailable' => { # 503が返ってきた時
    #      'retryLimit'  => 3,
    #      'wait'        => 120
    #    },
    #    
    #    'timedOut' => {        # タイムアウト時
    #      'retryLimit'  => 3,
    #      'wait'        => 10
    #    }
    #  }
    def execute(tag, sortMethod, waitConfig, &block)
      loop(tag, sort, "atom", waitObj) { |result, page|
        block.call(result, page)
      }
    end
  end
end