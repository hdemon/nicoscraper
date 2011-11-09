# -*- encoding: utf-8 -*-# -*- encoding: utf-8 -*-
$:.unshift File.dirname(__FILE__)

require 'rubygems'
require 'time'
require 'kconv'

require 'parser.rb'

module Nicos
  module Searcher
    # @private
    class ByTagSuper < Nicos::Connector::Config
      private

      def get(tag, sort, method)
        paramAry = []

        case sort
          when :comment_new
            sortStr = ''
          when :comment_old
            sortStr = 'order=a'
          when :view_many
            sortStr = 'sort=v'
          when :view_few
            sortStr = 'sort=v&order=a'
          when :comment_many
            sortStr = 'sort=r'
          when :comment_few
            sortStr = 'sort=r&order=a'
          when :mylist_many
            sortStr = 'sort=m'
          when :mylist_few
            sortStr = 'sort=m&order=a'
          when :post_new
            sortStr = 'sort=f'
          when :post_old
            sortStr = 'sort=f&order=a'
          when :length_long
            sortStr = 'sort=l'
          when :length_short
            sortStr = 'sort=l&order=a'
        end

        paramAry.push("page=#{@page}") if @page != 1
        paramAry.push(sortStr)
        paramAry.push("rss=atom&numbers=1") if method == :atom
        param = "#{tag}?" + paramAry.join('&')

        host = 'www.nicovideo.jp'
        entity = '/tag/'

        @connector.get(host, entity, param)
      end

      def loop(tag, sort, method, &block)
        @page = 1
        order       = ""

        begin
          movieObjAry = []
          response = get(
            tag,
            sort,
            method
          )

          if response[:order] == :afterTheSuccess
            result = parse(response[:body])
            result.each { |each|
              movie = Nicos::Movie.new(each[:video_id])
              each[:available] = true
              movie.set(each)
              movieObjAry.push(movie)
            }
          elsif response[:order] == :terminate
            puts "Request loop terminated."
            break
          end

          status = { :page => @page, :results => @connector.result}
          order = block.call(movieObjAry, status)
          @page += 1
        end until order != "continue" || order != :continue
      end

      public

      include Nicos::Connector::SetWait 
    end

    class ByTagHtml < ByTagSuper
      def initialize
        @numOfSearched = 32
        @incrAmt = 0.2

        @connector = Nicos::Connector.new(:mech)

        # HTML中の各パラメータの所在を示すXPath
        @videoIdXP  = "//div[@class='uad_thumbfrm']/table/tr/td/p/a"
        @lengthXP   = "//div[@class='uad_thumbfrm']/table/tr/td/p[2]/span"
        @viewXP     = "//div[@class='uad_thumbfrm']/table/tr/td[2]/div/nobr[1]/strong"
        @resXP      = "//div[@class='uad_thumbfrm']/table/tr/td[2]/div/nobr[2]/strong"
        @mylistXP   = "//div[@class='uad_thumbfrm']/table/tr/td[2]/div/nobr[3]/a/strong"
        @adXP       = "//div[@class='uad_thumbfrm']/table/tr/td[2]/div/nobr[4]/a/strong"
        @waitConfig = @@waitConfig
      end
      attr_accessor :waitConfig

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
          :video_id => video_id,
          :length   => length,
          :view     => view,
          :res      => res,
          :mylist   => mylist,
          :ad       => ad
        })
      end

      public

      # @param [String] tag
      # @param [String] sortMethod
      # @param [HashObj] waitConfig
      def execute(tag, sortMethod, &block)
        loop(tag, sort, :mech) { |result, page|
          block.call(result, page)
        }
      end
    end

    class ByTag < ByTagSuper
      def initialize
        @numOfSearched = 32
        @incrAmt = 0.2
        @connector = Nicos::Connector::TagAtom.new()
        @waitConfig = @@waitConfig
      end
      attr_accessor :waitConfig

      private 

      def parse(xml)
        Nicos::Parser::Xml.tagAtom(xml)
      end

      public

      # タグ検索を実行し、ブロックに結果を渡します。
      #
      # @param [String] tag 検索したいタグ文字列
      # @param [Symbol] sortMethod ソート方法
      #==基本的な使い方
      #  require 'nicoscraper'
      #  
      #  count = 0
      #
      #  searcher = Nicos::Searcher::ByTag.new()
      #  searcher.execute('VOCALOID', :view_many) {
      #    |result, status|
      #    
      #    count += 1
      #
      #    result.each { |movieObj|
      #      puts movieObj.title 
      #    }  
      #
      #    :continue unless count >= 3
      #  }
      #
      #  result ----
      #
      #  【初音ミク】みくみくにしてあげる♪【してやんよ】
      #  初音ミク　が　オリジナル曲を歌ってくれたよ「メルト」
      #  初音ミク　が　オリジナル曲を歌ってくれたよ「ワールドイズマイン」
      #  初音ミクオリジナル曲　「初音ミクの消失（LONG VERSION）」
      #  【巡音ルカ】ダブルラリアット【オリジナル】
      #  「卑怯戦隊うろたんだー」をKAITO,MEIKO,初音ミクにry【オリジナル】修正版
      #  【オリジナル曲PV】マトリョシカ【初音ミク・GUMI】
      #  初音ミクがオリジナルを歌ってくれたよ「ブラック★ロックシューター」
      #  ...
      #
      #　　Nicos::Searcher::ByTagのインスタンスを作り、executeメソッドに引数を与えて実行します。
      # 結果がブロックの第1仮引数に渡されます。渡される結果はMovieクラスのインスタンスを含む配列ですが、
      # MovieクラスのgetInfo、getHtmlInfoメソッドと全く同じではありません。これは、検索ページ/RSSから
      # 動画情報を取得しており、先の2メソッドとは異なる取得元だからです。
      #
      #==スクレイプの継続について
      #
      #　　スクレイプは、ブロック内で明示的に ':continue' あるいは '"continue"' を返さない限り、1リクエストで
      # 終了します。これは、意図せざる過剰アクセスを防ぐための措置です。上の例では、3回アクセスすると終了します。
      # 帰ってきた動画インスタンスの情報を利用することで、一定の投稿日までさかのぼって取得するなどの処理も可能です
      # （トップの例を参照）。
      #
      # 　また、ニコニコ動画の検索結果は、指定した数を一度に取得できる訳ではありません。
      # なぜなら、現状では検索結果はHTML1ページ、もしくは1つのRSS/Atomフィードに32個を限度に渡される方式であり、
      # ByTagクラスがその結果を利用する以上、32個=1単位という制約のもとに置かれるからです。
      # 従って、例えば最新の投稿100個の情報が欲しいとしても、1回のリクエストでは手に入らず、
      # かならず数回に分けてリクエストすることになります。
      #
      #　加えて、リクエストを継続するかどうかの判定も1ページ/1フィード毎に行います。
      #==sortMethod: ソート方法
      # 　以下のシンボルを指定して下さい。
      #
      # *:comment_new*  
      # コメントが新しい順
      # 
      # *:comment_old*  
      # コメントが新しい順
      # 
      # *:view_many*  
      # 再生数が多い順
      # 
      # *:view_few*  
      # 再生数が少ない順
      # 
      # *:comment_many*  
      # コメントが多い順
      # 
      # *:comment_few*  
      # コメントが少ない順
      # 
      # *:mylist_many*  
      # マイリスト登録が多い順
      # 
      # *:mylist_few*  
      # マイリスト登録が少ない順
      # 
      # *:post_new*  
      # 登録が新しい順
      # 
      # *:post_old*  
      # 登録が少ない順
      # 
      # *:length_long*  
      # 再生時間が長い順
      # 
      # *:length_short*  
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
      #    :seqAccLimit => 10,  # 連続してリクエストする回数
      #    :afterSeq    => 10,  # 連続リクエスト後のウェイト（以下、単位は全て秒）
      #    :each        => 1,   # 連続リクエスト時の、1リクエスト毎のウェイト
      #    :increment   => 1,   # アクセス拒絶時の、次回以降の1リクエスト毎のウェイトの増加量
      # 
      #    :deniedSeqReq=> {     # 連続アクセスを拒否された際の設定（以下同じ）
      #      :retryLimit  => 3,  # 再試行の上限回数
      #      :wait        => 120 # 次のアクセスまでのウェイト
      #    },
      #    
      #    :serverIsBusy=> {     # サーバ混雑時
      #      :retryLimit  => 3,
      #      :wait        => 120
      #    },
      #    
      #    :serviceUnavailable => { # 503が返ってきた時
      #      :retryLimit  => 3,
      #      :wait        => 120
      #    },
      #    
      #    :timedOut => {        # タイムアウト時
      #      :retryLimit  => 3,
      #      :wait        => 10
      #    }
      #  }
      #
      #==ブロック内の第2引数について
      #
      # 第2引数には、それまでの検索の成否、例外の発生回数などを記録した
      # ハッシュが渡されます。これは以下のような構造になっています。
      #
      #  {
      #    # 各種例外等が発生した動画・マイリストのIDを配列で保管。
      #    :notPublic => [],
      #    :limInCommunity => [],
      #    :notFound => [],
      #    :deleted => [],
      #  
      #    # 再試行で対処できる例外等が発生した件数。
      #    :deniedSeqReq => 0,
      #    :serverIsBusy => 0,
      #    :serviceUnavailable => 0,
      #    :timedOut => 0,
      #  
      #    # 成功回数
      #    :succeededNum => 0
      #  }
      #
      # *allDisabled*  
      # 　マイリストの場合のみ機能。そのマイリスト内の動画が全て非公開、
      # あるいは削除済み等で存在しないが、マイリストは残っている場合。
      #
      # *notPublic*  
      # 　動画、マイリストが非公開である場合。
      #
      # *limInCommunity*  
      # 　動画、マイリストがコミュニティ限定公開である場合。
      #
      # *notFound*  
      # 　動画、マイリストが存在しない場合。マイリストは削除済みの場合もnotFoundとなる。
      #
      # *deleted*  
      # 　その動画が削除済みである場合。マイリストについては、上のnotFoundと
      # 区別されない。 
      #
      # *deniedSeqReq*  
      # 　連続アクセスとして明示的に拒否された場合。 
      #
      # *serverIsBusy*  
      # 　「大変ご迷惑をおかけいたしますが、しばらく時間をあけてから
      # 再度検索いただくようご協力をお願いいたします。」と表示される場合。
      #
      # *serviceUnavailable*  
      # 　503が返ってきた時。
      #
      # *timedOut*  
      # 　タイムアウト
      #
      # *succeededNum*  
      # 　成功回数
      #==
      def execute(tag, sortMethod, &block)
        loop(tag, sortMethod, :atom) { |result, page|
          block.call(result, page)
        }
      end
    end
  end
end