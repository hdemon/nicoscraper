# -*- encoding: utf-8 -*-
$:.unshift File.dirname(__FILE__) 

require 'rubygems'
require 'ruby-debug'
require 'net/http'

module Nicos
  module Connector
    class Connector
      include Config

      def initialize
        # デフォルトのウェイト設定
        @seqTime = 0
        @result = {}
        @waitConfig = @@waitConfig
      end

      private
      
      def notPublic
        # マイリスト非公開のときに403になる。後で専用の処理を入れるべき。
        puts "This movie/mylist is not public."
        @result = "notPublic"
        return { "order" => "terminate" }  
      end

      def limInCommunity
        puts "This movie/mylist is limited in comunity members."
        # ex. item_id -> 1294702905
        @result = "limInCommunity"
        return { "order" => "terminate" }   
      end

      def notFound
        puts "This movie/mylist is not found."
        @result = "notFound"
        return { "order" => "terminate" }  
      end

      def deleted
        puts "This movie/mylist is deleted."
        @result = "deleted"
        return { "order" => "terminate" }  
      end

      def deniedSeqReq
        puts "Denied sequential requests."
        sleep @@waitConfig["deniedSeqReq"]
        @result = "deniedSeqReq"
        return { "order" => "retry" }  
      end

      def serverIsBusy
        puts "The server is busy."
        sleep @@waitConfig["serverIsBusy"]
        @result = "serverIsBusy"
        return { "order" => "retry" } 
      end

      def serviceUnavailable
        puts "Service unavailable."
        sleep @@waitConfig["serviceUnavailable"]
        @result = "serviceUnavailable"
        return { "order" => "retry" } 
      end

      def timedOut
        puts "Request timed out."
        sleep @@waitConfig["timedOut"]
        @result = "timedOut"
        return { "order" => "retry" } 
      end

      def success(resBody)
        sleep @@waitConfig["each"]
        @seqTime += 1
        
        if @seqTime >= @@waitConfig["seqAccLimit"]
          sleep @@waitConfig["afterSeq"]
          @seqTime = 0
        end
        return { "order" => "success", "body" => resBody } 
      end

      def wait(status)
        puts "Wait for " + waitTime + " second."
        sleep @@waitConfig[status.to_s]
      end
        
      public
    end

    class Xml < Connector
      def get (host, entity)  
        response = nil
              
        begin
          puts "Request to " + host + entity 
          Net::HTTP.start(host, 80) { |http|
            response = http.get(entity)
          }

        rescue => e
          puts e
        rescue Timeout::Error => e  
          timeOut      

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
            serviceUnavailable
          else
            unknownError
          end    
        end until res["order"] == "success" ||
                  res["order"] == "terminate"

        res
      end
    end

    class MylistAtom < Xml
      private

      def forbidden
        # マイリストが非公開の場合、html/Atomのどちらへのリクエストであっても、403が返ってくる。
        notPublic
      end

      def reviewRes(resBody)
        if # アクセス集中時
          /大変ご迷惑をおかけいたしますが、しばらく時間をあけてから再度検索いただくようご協力をお願いいたします。/ =~
            resBody.force_encoding("UTF-8")
        then
          serverIsBusy
        else
          success(resBody)
        end      
      end
    end

    class TagAtom < Xml
      private

      def forbidden
        # マイリストが非公開の場合、html/Atomのどちらへのリクエストであっても、403が返ってくる。
        notPublic
      end

      def reviewRes(resBody)
        if # アクセス集中時
          /大変ご迷惑をおかけいたしますが、しばらく時間をあけてから再度検索いただくようご協力をお願いいたします。/ =~
            resBody.force_encoding("UTF-8")
        then
          serverIsBusy
        else
          success(resBody)
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
          success(resBody)
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
