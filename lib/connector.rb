# -*- encoding: utf-8 -*-
require 'rubygems'
require 'ruby-debug'
require 'net/http'

class Connector
  def initialize(mode)
    @mode = mode
    # デフォルトのウェイト設定
    @waitConfig = {
      'consec_count'  => 10,    # 連続してリクエストする回数
      'consec_wait'   => 10,    # 連続リクエスト後のウェイト
      'each'          => 10,    # 連続リクエスト時の、1リクエスト毎のウェイト
 
      '200-abnormal'  => 1,   # アクセス拒絶時（「短時間での連続アクセスは・・・」）の場合の再試行までの時間
      'unavailable'   => 10,
      '403'           => 1,   # "403"時の再試行までのウェイト
      '404'           => 1,   # "403"時の再試行までのウェイト
      'increment'     => 1,     # アクセス拒絶時の、次回以降の1リクエスト毎のウェイトの増加量

      'timeout'       => 5,     # タイムアウト時の、再試行までのウェイト
      '500'           => 1,   # "500"時の再試行までのウェイト
      '503'           => 1,   # "503"時の再試行までのウェイト
 
      'retryLimit'    => 5    # 再試行回数の限度
    }
    
    # 1つの検索結果画面に表示される動画の数。現時点では10個。
    @NumOfSearched = 32
    
    if @mode == "mech"
      @mech = Mechanize.new
      # メモリ節約のため、Mechanizeの履歴機能をオフにする。
      @mech.max_history = 1
    end

    @consec_count = 0
  end

  private
  
  def mixin(targetObj, overWriteObj)
    output = Marshal.load(Marshal.dump(targetObj))
    if targetObj.instance_of?(Hash)
      overWriteObj.each_key { |key|    
        overWriteObj[key] = mixin(targetObj[key], overWriteObj[key])
        output[key] = overWriteObj[key]
      }
    else
      output = overWriteObj
    end
    return output
  end
  
  public 
  
  def setWait(waitConfig)
    if waitConfig != nil
      @waitConfig = mixin(@waitConfig, waitConfig)
    end
  end

  def eachWait
     # ウェイト...1回目の場合は無視 -------------------------
    if @consec_count != 0
      # 動画毎
      sleep @wait['each']
 
      # 一定のリクエスト回数毎
      if @consec_count >= @wait['consec_count'] then
        sleep @wait['consec_wait']
        @consec_count = 0
      end
    end
    # ------------------------------------------------
  end

  def timeOut
    sleep @wait['timeout']
    @connection = false
    @failed += 1
    warn "Timeout"
  end

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

  def xmlGet (host, entity)
    response = nil
    xmlDoc = nil
    retryCount = 0
    terminate = false
        
    begin
      puts "Requesting to " + host + entity 
      Net::HTTP.start(host, 80) { |http|
        response = http.get(entity)
      }
    rescue => e
      puts e
    rescue Timeout::Error => e  
      puts e
      puts "Timeout."
      # マイリスト非公開のときに、403になる。後で専用の処理を入れるべき。
      wait("timeout")
      retryCount += 1
      
      if retryCount >= @waitConfig["retryLimit"]
        terminate = true
        return "failed"
      end
    else
      case response
      when Net::HTTPSuccess
        unless abnormalRes(response.body)
          terminate = true
          return response.body.force_encoding("UTF-8") 
        end
        wait("200-abnormal")
        retryCount += 1
      when Net::HTTPRedirection 
        fetch(response['location'], limit - 1)
      when Net::HTTPForbidden
        puts "Access forbidden."
        # マイリスト非公開のときに、403になる。後で専用の処理を入れるべき。
        wait("403")
        retryCount += 1
      when Net::HTTPNotFound
        puts "Http not found."
        wait("404")
        retryCount += 1
      when Net::HTTPServiceUnavailable  
        puts "Access rejected or service unavailable."
        wait("unavailable")
        retryCount += 1
      else
        puts response.force_encoding("UTF-8") 
        puts "Unknown error."
        wait("other")
        retryCount += 1
      end
      
      if retryCount >= @waitConfig["retryLimit"]
        terminate = true
        return "failed"
      end
    end until terminate
  end

  def abnormalRes(resBody)
    if
      # mylistRss アクセス集中時
       /大変ご迷惑をおかけいたしますが、しばらく時間をあけてから再度検索いただくようご協力をお願いいたします。/ =~ resBody.force_encoding("UTF-8") ||
      # getThumbInfo失敗時
       /<nicovideo_thumb_response\sstatus=\"fail\">/ =~ resBody
    then
      puts "!!!!"
      true
    end  
  end
  
  def wait(status)
    sleep @waitConfig[status.to_s]
  end
  
  def get (host, entity)
    case @mode
    when "html"
      mechGet(host + entity)
    when "atom"
      xmlGet(host, entity)
    end
  end

  attr_reader :mech
end
