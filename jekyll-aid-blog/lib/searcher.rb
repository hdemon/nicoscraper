# -*- encoding: utf-8 -*-# -*- encoding: utf-8 -*-
$:.unshift File.dirname(__FILE__) 

require 'rubygems'
require 'ruby-debug'

require 'time'
require 'mechanize'
require 'kconv'

require 'parser.rb'


class SearchByTagSuper
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
          movie = Movie.new(each["video_id"]) 
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

class SearchByTag < SearchByTagSuper
  def initialize
    @numOfSearched = 32
    @incrAmt = 0.2

    @connector = Connector.new('mech')
    
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
  
  def execute(tag, sort, waitObj, &block) 
    loop(tag, sort, "mech", waitObj) { |result, page|
      block.call(result, page)
    }
  end
end

class SearchByTagLt < SearchByTagSuper
  def initialize
    @numOfSearched = 32
    @incrAmt = 0.2
    @connector = SearchByTagAtomConnector.new()
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



