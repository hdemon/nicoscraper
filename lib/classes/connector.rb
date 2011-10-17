# -*- encoding: utf-8 -*-
$:.unshift File.dirname(__FILE__) 

require 'rubygems'
require 'net/http'

module Nicos
  module Connector

    class Connector < Config
      include Nicos::Connector::SetWait

      def initialize
        # デフォルトのウェイト設定
        @seqTime = 0
        @result = {
          :allDisabled => [],
          :notPublic => [],
          :limInCommunity => [],
          :notFound => [],
          :deleted => [],
          :noMovie => [],

          :deniedSeqReq => 0,
          :serverIsBusy => 0,
          :serviceUnavailable => 0,
          :timedOut => 0,

          :succeededNum => 0
        }
        @waitConfig = @@waitConfig
      end
      attr_accessor :waitConfig
      attr_accessor :result

      private

      # 再試行しない例外の共通処理
      def accessDisabled(exception)
        @result[exception].push(@nowAccess)
        { :order => :skip, :status => exception }  
      end
       
      def allDisabled
        # MylistAtomについて、全ての動画が非公開あるいはその他の理由でRSSフィードに掲載されない時。
        puts "All movies are disabled."
        accessDisabled(:allDisabled) 
      end
      
      def notPublic
        # マイリスト非公開のときに403になる。
        # http://www.nicovideo.jp/mylist/25479830
        puts "This movie/mylist is not public."
        accessDisabled(:notPublic) 
      end

      def limInCommunity
        puts "This movie/mylist is limited in comunity members."
        # ex. item_id -> 1294702905
        accessDisabled(:limInCommunity) 
      end

      def notFound
        puts "This movie/mylist is not found."
        accessDisabled(:notFound) 
      end

      def noMovie
        puts "This movie/mylist contains no movie."
        accessDisabled(:noMovie) 
      end

      def deleted # マイリストは削除と404の区別がない？
        puts "This movie/mylist is deleted."
        accessDisabled(:deleted) 
      end

      # 以下、再試行の可能性のある例外

      # 共通処理
      def exception(exception)
        if @retryCount <= @waitConfig[exception][:retryLimit]
          { :order => :skip }   
        else
          sleep @waitConfig[exception][:wait]
          @result[exception] += 1
          { :order => :retry }   
        end        
      end

      def deniedSeqReq
        puts "Denied sequential requests."
        exception(:deniedSeqReq)
      end

      def serverIsBusy
        puts "The server is busy."
        exception(:serverIsBusy)
      end

      def serviceUnavailable
        puts "Service unavailable."
        exception(:serviceUnavailable)
      end

      def timedOut
        puts "Request timed out."
        exception(:timedOut)
      end

      def reachedLast 
        # TagAtom専用。MylistAtomは、allDisabledと結果が被ってしまう。
        puts "Reached the last page."
        { :order => :terminate } 
      end

      def succeeded(resBody)
        @result[:succeededNum] += 1
        sleep @waitConfig[:each]
        @seqTime += 1
        
        if @seqTime >= @waitConfig[:seqAccLimit]
          sleep @waitConfig[:afterSeq]
          @seqTime = 0
        end
        
        { 
          :status => :success,
          :order => :afterTheSuccess, 
          :body => resBody
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
          :status => nil,
          :retry  => {}
        }

        @result.each_key do |key|
          if @result[key].instance_of?(Array) && @result[key].length >= 1
            status[:status] = key
          elsif key === :succeededNum && @result[key] >= 1
            status[:status] = :success
          elsif @result[key].instance_of?(Fixnum)
            status[:retry][key] = @result[key]
          end
        end

        status
      end        
    end

    class Xml < Connector
      def get (host, entity, param)  
        response = nil
        @retryCount = 0
        res = {}
              
        begin
          @nowAccess = host + entity + param
          puts "Request to " + @nowAccess
          Net::HTTP.start(host, 80) { |http|
            response = http.get(entity + param, HEADER)
          }
          @retryCount += 1

        rescue => e
          puts e
        rescue Timeout::Error => e
          timedOut
          res[:order] = :retry
        else
          res = case response
          when Net::HTTPSuccess then
            reviewRes( response.body.force_encoding("UTF-8") )
          # when Net::HTTPRedirection
          #  fetch(response['location'], limit - 1)
          when Net::HTTPForbidden           then forbidden         
          when Net::HTTPNotFound            then notFound
          when Net::HTTPServiceUnavailable  then serviceUnavailable
          else unknownError
          end    
        end until res[:order] != :retry

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

    class MylistHtml < Xml 
      def forbidden
        # マイリストが非公開の場合、html/Atomのどちらへのリクエストであっても、403が返ってくる。
        notPublic
      end
            
      def reviewRes(resBody)
        r = resBody.force_encoding("UTF-8")
        if # アクセス集中時
          /大変ご迷惑をおかけいたしますが、しばらく時間をあけてから再度検索いただくようご協力をお願いいたします。/ =~ r then
          serverIsBusy
        else
          succeeded(resBody)       
        end      
      end
    end

  end # end of connector
end
