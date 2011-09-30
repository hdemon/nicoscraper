# -*- encoding: utf-8 -*-
$:.unshift File.dirname(__FILE__) 

require 'rubygems'
require 'net/http'

module Nicos
  module Connector

    #
    #
    # 
    #==ブロック内の第2引数について
    #
    # 第2引数には、それまでの検索の成否、例外の発生回数などを記録した
    # ハッシュが渡されます。これは以下のような構造になっています。
    #
    # {
    #   # 各種例外等が発生した動画・マイリストのIDを配列で保管。
    #   "allDisabled" => [],
    #   "notPublic" => [],
    #   "limInCommunity" => [],
    #   "notFound" => [],
    #   "deleted" => [],
    # 
    #   # 再試行で対処できる例外等が発生した件数。
    #   "deniedSeqReq" => 0,
    #   "serverIsBusy" => 0,
    #   "serviceUnavailable" => 0,
    #   "timedOut" => 0,
    # 
    #   # 成功回数
    #   "succeededNum" => 0
    # }
    #
    #  これらのパラメータが複数の結果を保持する前提になっているのは、Searcherモジュール
    # に対応させる為です。将来的には、Movie/Mylistクラス
    # には専用のハッシュを設ける設計にするつもりです。
    #
    # **allDisabled**  
    # 　マイリストの場合のみ機能。そのマイリスト内の動画が全て非公開、
    # あるいは削除済み等で存在しないが、マイリストは残っている場合。
    #
    # **notPublic**  
    # 　動画、マイリストが非公開である場合。
    #
    # **limInCommunity**  
    # 　動画、マイリストがコミュニティ限定公開である場合。
    #
    # **notFound**  
    # 　動画、マイリストが存在しない場合。マイリストは削除済みの場合もnotFoundとなる。
    #
    # **deleted**  
    # 　その動画が削除済みである場合。マイリストについては、上のnotFoundと
    # 区別されない。 
    #
    # **deniedSeqReq**  
    # 　連続アクセスとして明示的に拒否された場合。 
    #
    # **serverIsBusy**  
    # 　「大変ご迷惑をおかけいたしますが、しばらく時間をあけてから
    # 再度検索いただくようご協力をお願いいたします。」と表示される場合。
    #
    # **serviceUnavailable**  
    # 　503が返ってきた時。
    #
    # **timedOut**  
    # 　タイムアウト
    #
    # **succeededNum**  
    class Connector < Config
      def initialize
        # デフォルトのウェイト設定
        @seqTime = 0
        @result = {
          "allDisabled" => [],
          "notPublic" => [],
          "limInCommunity" => [],
          "notFound" => [],
          "deleted" => [],

          "deniedSeqReq" => 0,
          "serverIsBusy" => 0,
          "serviceUnavailable" => 0,
          "timedOut" => 0,

          "succeededNum" => 0
        }
        @waitConfig = @@waitConfig
      end
      attr_accessor :waitConfig
      attr_accessor :result

      private

      # 再試行しない例外の共通処理
      def accessDisabled(exception)
        @result[exception].push(@nowAccess)
        { "order" => "skip", "status" => exception }  
      end
       
      def allDisabled
        # MylistAtomについて、全ての動画が非公開あるいはその他の理由でRSSフィードに掲載されない時。
        puts "All movies are disabled."
        accessDisabled("allDisabled") 
      end
      
      def notPublic
        # マイリスト非公開のときに403になる。
        # http://www.nicovideo.jp/mylist/25479830
        puts "This movie/mylist is not public."
        accessDisabled("notPublic") 
      end

      def limInCommunity
        puts "This movie/mylist is limited in comunity members."
        # ex. item_id -> 1294702905
        accessDisabled("limInCommunity") 
      end

      def notFound
        puts "This movie/mylist is not found."
        accessDisabled("notFound") 
      end

      def deleted # マイリストは削除と404の区別がない？
        puts "This movie/mylist is deleted."
        accessDisabled("deleted") 
      end

      # 以下、再試行の可能性のある例外

      # 共通処理
      def exception(exception, retryCount)
        if retryCount <= @waitConfig[exception]["retryLimit"]
          { "order" => "skip" }   
        else
          sleep @waitConfig[exception]["wait"]
          @result[exception] += 1
          { "order" => "retry" }   
        end        
      end

      def deniedSeqReq(retryCount)
        puts "Denied sequential requests."
        exception("deniedSeqReq", retryCount)
      end

      def serverIsBusy(retryCount)
        puts "The server is busy."
        exception("serverIsBusy", retryCount)
      end

      def serviceUnavailable(retryCount)
        puts "Service unavailable."
        exception("serviceUnavailable", retryCount)
      end

      def timedOut(retryCount)
        puts "Request timed out."
        exception("timedOut", retryCount)
      end


      def reachedLast 
        # TagAtom専用。MylistAtomは、allDisabledと結果が被ってしまう。
        puts "Reached the last page."
        return { "order" => "terminate" } 
      end

      def succeeded(resBody)
        @result["succeededNum"] += 1
        sleep @waitConfig["each"]
        @seqTime += 1
        
        if @seqTime >= @waitConfig["seqAccLimit"]
          sleep @waitConfig["afterSeq"]
          @seqTime = 0
        end
        return { 
          "order" => "afterTheSuccess", 
          "body" => resBody
        } 
      end

      def wait(status)
        puts "Wait for " + waitTime + " second."
        sleep @waitConfig[status.to_s]
      end

      public

      # リクエスト結果を格納する変数を、MylistやMovie等の
      # 単一リクエストメソッド用に構造を変換する。
      def getStatus
        status = {
          "status"  => nil,
          "retry"   => {}
        }

        @result.each_key do |key|
          if @result[key].instance_of?(Array) && @result[key].length >= 1
            status["status"] = key
          elsif key === "succeededNum" && @result[key] >= 1
            status["status"] = "success"
          elsif @result[key].instance_of?(Fixnum)
            status["retry"][key] = @result[key]
          end
        end

        status
      end        
    end

    class Xml < Connector
      def get (host, entity)  
        response = nil
        retryCount = 0
        res = {}
              
        begin
          @nowAccess = host + entity
          puts "Request to " + @nowAccess
          Net::HTTP.start(host, 80) { |http|
            response = http.get(entity, HEADER)
          }
          retryCount += 1

        rescue => e
          puts e
        rescue Timeout::Error => e  
          debugger
          timeOut 
          res["order"] = "retry"     

        else
          res = case response
          when Net::HTTPSuccess
            reviewRes( response.body.force_encoding("UTF-8") )
          #    return response.body.force_encoding("UTF-8") 
          # when Net::HTTPRedirection
          #  fetch(response['location'], limit - 1)
          when Net::HTTPForbidden
            forbidden         
          when Net::HTTPNotFound
            notFound
          when Net::HTTPServiceUnavailable 
          debugger
            serviceUnavailable
          else
            unknownError
          end    
        end until res["order"] != "retry"

        res
      end
    end

    class TagAtom < Xml
      private

      def forbidden
        # マイリストが非公開の場合、html/Atomのどちらへのリクエストであっても、403が返ってくる。
        notPublic
      end

      def reviewRes(resBody)
        resBody = resBody.force_encoding("UTF-8")
        if # アクセス集中時
          /大変ご迷惑をおかけいたしますが、しばらく時間をあけてから再度検索いただくようご協力をお願いいたします。/ =~         
          resBody then
          serverIsBusy
        elsif /\<entry\>/ =~ resBody && /\<\/entry\>/ =~ resBody
          succeeded(resBody)          
        else
          reachedLast
        end      
      end
    end

    class MylistAtom < TagAtom 
      def reviewRes(resBody)
        resBody = resBody.force_encoding("UTF-8")
        if # アクセス集中時
          /大変ご迷惑をおかけいたしますが、しばらく時間をあけてから再度検索いただくようご協力をお願いいたします。/ =~         
          resBody then
          serverIsBusy
        elsif /\<entry\>/ =~ resBody && /\<\/entry\>/ =~ resBody
          succeeded(resBody)          
        else
          allDisabled
        end      
      end
    end

    class GetThumbInfo < Xml
      private

      def reviewRes(resBody)
        r = resBody.force_encoding("UTF-8")

        if # getThumbInfoは、該当する動画がない・削除済み・コミュニティ限定でも200が返ってくる。
          /<nicovideo_thumb_response\sstatus=\"fail\">/ =~ r
          if /<code>NOT_FOUND<\/code>/ =~ r
            notFound
          elsif /<code>DELETED<\/code>/ =~ r
            deleted
          elsif /<code>COMMUNITY<\/code>/ =~ r
            limInCommunity
          else
            serverIsBusy
          end
        else
          succeeded(resBody)
        end      
      end
    end

=begin
    class HtmlConnector < Connector
      def initialize(mode)
        @mode = mode
        # デフォルトのウェイト設定
        @@waitConfig = {
          'consec_count'  => 10,  # 連続してリクエストする回数
          'consec_wait'   => 10,  # 連続リクエスト後のウェイト
          'each'          => 10,  # 連続リクエスト時の、1リクエスト毎のウェイト
     
          '200-abnormal'  => 300, # アクセス拒絶時（「短時間での連続アクセスは・・・」）の場合の再試行までの時間
          'unavailable'   => 10,
          '403'           => 300, # "403"時の再試行までのウェイト
          '404'           => 300, # "403"時の再試行までのウェイト
          'increment'     => 1,   # アクセス拒絶時の、次回以降の1リクエスト毎のウェイトの増加量

          'timeout'       => 10,  # タイムアウト時の、再試行までのウェイト
          '500'           => 10,  # "500"時の再試行までのウェイト
          '503'           => 10,  # "503"時の再試行までのウェイト
     
          'retryLimit'    => 3    # 再試行回数の限度
        }
        
        # 1つの検索結果画面に表示される動画の数。現時点では32個がデフォルトの模様。
        @NumOfSearched = 32

        @mech = Mechanize.new
        # メモリ節約のため、Mechanizeの履歴機能を切る。
        @mech.max_history = 1

        @consec_count = 0
      end
      
      public 

      def errorStatus(ex)
        # 再試行回数が
        @retryTime += 1
        if @retryTime >= @wait['allowance_time']
          return false
        end

        case ex.response_code
        when '403' then
          sleep @wait['403']
          warn "403"
        when '500' then
          sleep @wait['500']
          warn "500"
        when '503' then
          sleep @wait['503']
          warn "503"
        else
          warn "Server error: #{ex.code}"
          return false
        end
     
        @connection = false
        @failed += 1
      end

      def htmlReq (url, request, procedure)
        @failed = 0

        # 再試行ループ
        begin
          eachWait 
          @connection = nil
          request.call(url)
        
        # タイムアウト時処理
        rescue TimeoutError
          timeOut
          retry
           
        # Mechanizeでアクセスし、200以外のステータスが返ってきた時
        # 実際に該当するコードが返ってきたことがないので、正常に動くか不明   
        rescue Mechanize::ResponseCodeError => ex
          if errorStatus(ex) then retry
          else break end
           
        # HTTP Status:200時の処理
        else
          procedure.call
          
          # 失敗カウントが指定回数を超えたらループを終わる。
          if @failed >= @wait['allowance_time'] then
            puts 'Exceeded the limit of retry time.'
            @connection = false
            break
          end
        end until @connection

        # 連続アクセスカウント+1
        @consec_count += 1
        # 成功 = true / 失敗 = false
        return @connection
      end

      def htmlGet (host, entity)
        htmlReq(
          host + entity,
          lambda { |url|
            t = Thread.new do
              @mech.get(url)
              puts "Requesting for " + url
            end
            t.join
          },
          # HTTP Status:200時の処理 
          lambda {
            # 連続アクセス拒絶メッセージが返ってきた時       
            if /短時間での連続アクセスはご遠慮ください/ =~ @mech.page.search('/html').text then
              puts 'Access rejected.'
              @connection = false
              @failed += 1
         
              # ウェイトを置いた後、今後のページ毎のウェイトを増やす。
              puts 'Waiting for ' + @wait['rejected'] + 's.'
              sleep @wait['rejected']
              @wait['each'] += @wait['increment']
              puts 'Increased each @wait by ' + @wait['increment'] + 'sec.'
            else
              @connection = true
            end
          }
        )
        
        return @mech.page
      end
      
      attr_reader :mech
    end
=end
  end
end
