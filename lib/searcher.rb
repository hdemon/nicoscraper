# -*- encoding: utf-8 -*-
require 'rubygems'
require 'ruby-debug'

require 'time'
require 'mechanize'
require 'kconv'

require 'parser'


$wait_byTag = {
  'consec_count'  => 10,  # 連続してリクエストする回数
  'consec_wait'   => 10,  # 連続リクエスト後のウェイト
  'each'          => 10,  # 連続リクエスト時の、1リクエスト毎のウェイト
   
  'rejected'      => 120, # アクセス拒絶時（「短時間での連続アクセスは・・・」）
                          # の場合の再試行までの時間
  '403'           => 600, # "403"時の再試行までのウェイト
  'increment'     => 1,   # アクセス拒絶時の、次回以降の1リクエスト毎のウェイトの増加量

  'timeout'       => 5,   # タイムアウト時の、再試行までのウェイト
  '500'           => 600, # "500"時の再試行までのウェイト
  '503'           => 600, # "503"時の再試行までのウェイト

  'allowance_time'=> 5    # 再試行回数の限度
}

$wait_byMylistLt = {
  'consec_count'  => 10, 
  'consec_wait'   => 10, 
  'each'          => 10, 

  'rejected'      => 120,   
  '403'           => 600,   
  'increment'     => 1,   
  'timeout'       => 5,    
  '500'           => 600, 
  '503'           => 600, 
  'allowance_time'=> 5  
}

module GetMovie   
  public

  def byTag (tag, sort, waitObj, &block)
    gMByTag = GetMovieByTag.new()
    gMByTag.execute(tag, sort, waitObj) { |result, page|
      block.call(result, page)
    }
  end

  def byTagLt (tag, sort, waitObj, &block)
    gMByTagLt = GetMovieByTagLt.new()
    gMByTagLt.execute(tag, sort, waitObj) { |result, page|
      block.call(result, page)
    }
  end
    
  module_function :byTag
  module_function :byTagLt
end

class GetMovieByTagSuper
  private

  def get (tag, sort, page, method, waitObj)
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
    
    if page != 1 then paramAry.push("page=#{page}"); end
    paramAry.push(sortStr)
    if method == "atom" then paramAry.push("rss=atom&numbers=1") end
    param = tag + "?" + paramAry.join('&')
    
    host = 'www.nicovideo.jp'
    entity = '/tag/' + param

    @con.setWait(waitObj)
    @con.get(host, entity)
  end

  public

  def loop (tag, sort, method, waitObj, &block)
    termFlag = false
    page   = 1
   
    begin
       result  = []
       response = get(
        tag,
        sort,
        page,
        method,
        waitObj
      )

      if response
        result = parse(response)
        termFlag = block.call(result, page)
      else
        termFlag = true
      end
 
      page += 1
    end until termFlag
  end
end


class GetMovieByTag < GetMovieByTagSuper
  def initialize
    @NumOfSearched = 32
    @incrAmt = 0.2

    @con = Connector.new('mech')
    
    # HTML中の各パラメータの所在を示すXPath
    @videoIdXP  = "//div[@class='uad_thumbfrm']/table/tr/td/p/a"
    @lengthXP   = "//div[@class='uad_thumbfrm']/table/tr/td/p[2]/span"
    @viewXP     = "//div[@class='uad_thumbfrm']/table/tr/td[2]/div/nobr[1]/strong"
    @resXP      = "//div[@class='uad_thumbfrm']/table/tr/td[2]/div/nobr[2]/strong"
    @mylistXP   = "//div[@class='uad_thumbfrm']/table/tr/td[2]/div/nobr[3]/a/strong"
    @adXP       = "//div[@class='uad_thumbfrm']/table/tr/td[2]/div/nobr[4]/a/strong"
  end
    
  def parse(movieNum)
    result = []
    
    video_id  = /(sm|nm)[0-9]{1,}/.match(@con.mech.page.search(@videoIdXP)[movieNum]['href'])[0]
      lengthStr = @con.mech.page.search(@lengthXP)[movieNum].text.split(/\:/)
    length    = lengthStr[0].to_i * 60 + lengthStr[1].to_i
    view      = @con.mech.page.search(@viewXP)[movieNum]
                .text.gsub(/\,/, '').to_i
    res       = @con.mech.page.search(@resXP)[movieNum]
                .text.gsub(/\,/, '').to_i
    mylist    = @con.mech.page.search(@mylistXP)[movieNum]
                .text.gsub(/\,/, '').to_i
    ad        = @con.mech.page.search(@adXP)[movieNum]
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
  
  def execute(tag, sort, waitObj, &block) 
    loop(tag, sort, "mech", waitObj) { |result, page|
      block.call(result, page)
    }
  end
end

class GetMovieByTagLt < GetMovieByTagSuper
  def initialize
    @NumOfSearched = 32
    @incrAmt = 0.2
    @con = Connector.new('atom')
  end

  def parse(xml)
    NicoParser.tagRss(xml)
  end
   
  def execute(tag, sort, waitObj, &block) 
    loop(tag, sort, "atom", waitObj) { |result, page|
      block.call(result, page)
    }
  end
end



