# -*- encoding: utf-8 -*-
$:.unshift File.dirname(__FILE__) 

require 'rubygems'
require 'ruby-debug'
require 'damerau-levenshtein'
require 'kconv'

require 'namespace.rb'
require 'parser.rb'
require 'mylist.rb'
require 'connector.rb'

class Nicos::Movie  
  # @param [video_id] video_id 動画ID
  # インスタンス作成直後は、情報を取得しメソッドを実行する準備が整ったことを示す
  # @availableがfalseである。getInfo等で情報を取得するか、あるいはsetメソッドで
  # availableにtrueを代入する必要がある。
  def initialize(video_id)
    @video_id   = video_id
    @available  = false
  end
  
  public
  
  # 指定されたマイリストに自分が入っていれば、真を返す。 
  #
  # 内部的にMylist::getInfoを利用しているため、もし指定したマイリストの他の情報を使いたければ、
  # ブロック中に処理を記述することで、getInfoの取得結果を共用することができる。
  # @param [Fixnum] mylistId マイリストID
  # @return [Boolean] 
  def isBelongsTo (mylistId, &block)
    isBelongs = false
    thisMl = Nicos::Mylist.new(mylistId)
    thisMl.getInfo
    
    thisMl.movies.each { |movie|
      isBelongs = true if movie.video_id == @video_id
    }   
  
    if isBelongs
      puts "\sThis movie is found in mylist/" + 
        mylistId.to_s
    else
      puts "\sThis movie is not found in mylist/" + 
        mylistId.to_s
    end

    block.call(thisMl) if block != nil    
    isBelongs
  end
  
  # 自分が含まれる、投稿者の作ったシリーズとしてまとめているマイリストのIDを返す。
  #
  # isBelongsは指定されたマイリストとの関係を調べるが、isSeriesOfは動画説明文中のマイリストIDのみを用いる。
  # @return [Fixnum] マイリストID
  def isSeriesOf
    if !@available then
      puts "This movie object is not available."
      return "failed"
    end
    
    puts
    puts "Start to discern the seriality of..."
    puts "\svideo_id:\s\s" + @video_id
    puts "\stitle:\s\s\s\s\s" + @title    
    # extrMylist呼び出し
    mylistIdAry = extrMylist
    sMylistIdAry = []
    mlObjAry = []
    mylistId = nil
    mylist = nil
    similarity = 0.0
    
    mylistIdAry.each { |_mylistId|
      belongsTo = isBelongsTo(_mylistId) { |mylistObj|        
        similarity = mylistObj.getSimilarity 
        puts "\sSimilarity:\t" + similarity.to_s
      }
      puts belongsTo
      if belongsTo && similarity > 0.7
        puts "\s" + _mylistId.to_s + "\tis perecieved as series mylist."
        sMylistIdAry.push(_mylistId)
      end  
    }
    
    sMylistIdAry.each { |mylistId|
      mlObjAry.push( Nicos::Mylist.new(mylistId) )
    }
    
    puts "\sDiscern logic terminated."
    mlObjAry   
  end

  # 動画説明文中からマイリストIDを示す文字列を抽出し、配列として返す。
  #
  # @return [Array] マイリストIDを含む配列
  def extrMylist
    return if !@available
    puts "Extracting mylistId from the description..."
    
    mylistIdAry = []
    extracted = @description.scan(/mylist\/[0-9]{1,8}/)
    if extracted[0] != nil
      extracted.each { |e|
        id = e.scan(/[0-9]{1,8}/)[0]
        mylistIdAry.push(id)
        puts "\sID:\t" + id + " is extracted."
      }
    else
      puts "\sMylistId is not found."
    end  
    
    mylistIdAry
  end
  
  # 動画の詳細な情報を取得し、インスタンス変数に納める。
  # 
  # 内部的にgetThumbInfo APIを利用。
  # @return [Boolean] 成功すればtrueを返す。
  def getInfo
    con = Nicos::Connector::GetThumbInfo.new()
    host = 'ext.nicovideo.jp'
    entity = '/api/getthumbinfo/' + @video_id
    con.setWait(nil)
    result = con.get(host, entity)

    if
      result["order"] == "success"
    then
      parsed = Nicos::Parser::getThumbInfo(result["body"])
      set(parsed)
      @available = true
    else
      @available = false
    end
  end
  
  # インスタンスに対し、任意の情報を入れる。
  #
  # @param [HashObj] paramObj getThumbInfo等から手に入れたハッシュ
  # getInfo等を利用せずインスタンス変数に直接情報を入れる場合、もしgetThumbInfoやMylist APIからXMLやJSONで取得し、
  # 特にキー名を変更していないハッシュオブジェクトがあるのであれば、setメソッドで一括代入することができる。
  #
  # なお、getThumbInfoや、マイリストAtomフィードなどの情報は、取得元になるXML等のタグ名が少しずつ異なるため、
  # setメソッドに渡すべきハッシュオブジェクトのキー名は、必ずしもインスタンス変数の名前とは一致しない。
  # 例えば、getThumbInfoは現在のコメント数をcomment_numというタグで示すが、
  # マイリストのAtomフィードはnico-numbers-resというクラス名のタグで囲んでいる。
  def set(paramObj)
    paramObj.each_key { |key|
      param = paramObj[key]
      case key
      when "available"
        @available = param
       
      # common  
      when "video_id"
        @video_id = param.to_s
      when "item_id"
        @item_id = param.to_i
      when "title"
        @title = param.to_s
      when "mylist_id"    
        @mylist_id = param.to_i
    	when "description"
        @description = param.to_s   
      when "length"
        @length = param.to_i   
      when "first_retrieve"
        @first_retrieve = param       
      
      # MylistAPI      
      when "item_data"
        paramObj['item_data'].each_key { |key|
        param = paramObj['item_data'][key]
          case key
          when "video_id"
            @video_id = param.to_s  
        	when "title"
            @title = param.to_s
        	when "thumbnail_url"
            @thumbnail_url = param.to_s
        	when "first_retrieve"
            @first_retrieve = param.to_i
        	when "update_time"
            @update_time = param.to_i
        	when "view_counter"
            @view_counter = param.to_i
        	when "mylist_counter"
            @mylist_counter = param.to_i
        	when "num_res"
            @comment_num = param.to_i
        	when "length_seconds"
            @length = param.to_i
        	when "deleted"
            @deleted = param.to_i       
        	when "last_res_body"
            @last_res_body = param.to_s
          end
        } 
    	when "watch"
        @watch = param.to_i
    	when "create_time"
        @create_time = param.to_i
    	when "update_time"
        @update_time = param.to_i
      
      # MylistAPI-Atom
    	when "memo"
        @memo = param.to_s       
    	when "published"
        @create_time = param.to_i     
    	when "updated"
        @update_time = param.to_i 
      when "view"
        @view_counter = param.to_i
      when "mylist"
        @mylist_counter = param.to_i
      when "res"
        @comment_num = param.to_i       
      
      # getThumbInfo  
    	when "thumbnail_url"
        @thumbnail_url = param.to_s
    	when "movie_type"
        @movie_type = param.to_s
      when "size_high"
        @size_high = param.to_i
    	when "size_low"
        @size_low = param.to_i
    	when "view_counter"
        @view_counter = param.to_i
    	when "mylist_counter"
        @mylist_counter = param.to_i
    	when "comment_num"
        @comment_num = param.to_i
    	when "last_res_body"
        @last_res_body = param.to_s
    	when "watch_url"
        @watch_url = param.to_s
    	when "thumb_type"
        @thumb_type = param.to_s
    	when "embeddable"
        @embeddable = param.to_i
    	when "no_live_play"
        @no_live_play = param.to_i
    	when "tags_jp"
        @tags_jp = param
      when "tags_tw"
        @tags_tw = param
    	when "tags_de"
        @tags_de = param
      when "tags_es"
        @tags_sp = param
    	when "user_id"
        @user_id = param.to_i
      end
    }   
  end  
  
  # このインスタンスがgetInfo等によって正常に情報を取得できている場合、trueとなる。
  # 各種メソッドの実行には、これがtrueであることが要求される。
  # 
  # @return [Boolean]
  attr_accessor :available
  
  # MylistAPI
  
  # 動画に付与される、sm|nmで始まる一意のID 
  #
  # @return [String]
  # <b>取得可能なメソッド</b>  
  # {Nicos::Movie#getInfo Movie::getInfo}  
  # {Nicos::Movie#getInfo Movie::getHtmlInfo}  
  # {Nicos::Movie#getInfo Mylist::getInfo}  
  # {Nicos::Movie#getInfo Mylist::getHtmlInfo}  
  attr_accessor	:video_id

  # この動画が属するマイリストのID  
  #
  # @return [Fixnum]
  # <b>取得可能なメソッド</b>  
  # {Nicos::Movie#getInfo Movie::getInfo}  
  # {Nicos::Movie#getInfo Movie::getHtmlInfo}  
  # {Nicos::Movie#getInfo Mylist::getInfo}  
  # {Nicos::Movie#getInfo Mylist::getHtmlInfo}  
  attr_accessor	:mylist_id

  # 動画に与えられるもう一つの一意なIDであり、投稿日時と同じか非常に近いUNIX時間になっている。
  #
  # 例えば、"【初音ミク】みくみくにしてあげる♪【してやんよ】"の動画IDはsm1097445であり、アイテムIDは1190218917である。このアイテムIDを日時に直すと、日本時間における2007年9月20日 1:21:57となるが、動画に投稿日時として表示されるのは、2007年9月20日 1:22:02である。
  #
  # @return [Fixnum]
  # <b>取得可能なメソッド</b>  
  # {Nicos::Movie#getInfo Movie::getInfo}  
  # {Nicos::Movie#getInfo Movie::getHtmlInfo}  
  # {Nicos::Movie#getInfo Mylist::getInfo}  
  # {Nicos::Movie#getInfo Mylist::getHtmlInfo}  
  attr_accessor	:item_id
  
  # 投稿者が記述した動画の説明文
  #
  # @return [String]
  # <b>取得可能なメソッド</b>  
  # {Nicos::Movie#getInfo Movie::getInfo}  
  # {Nicos::Movie#getInfo Movie::getHtmlInfo}  
  # {Nicos::Movie#getInfo Mylist::getInfo}  
  # {Nicos::Movie#getInfo Mylist::getHtmlInfo}  
  attr_accessor	:description

  # 動画のタイトル
  #
  # @return [String]
  # <b>取得可能なメソッド</b>  
  # {Nicos::Movie#getInfo Movie::getInfo}  
  # {Nicos::Movie#getInfo Movie::getHtmlInfo}  
  # {Nicos::Movie#getInfo Mylist::getInfo}  
  # {Nicos::Movie#getInfo Mylist::getHtmlInfo}
  attr_accessor	:title

  # サムネイルのURL
  #
  # @return [String]
  # <b>取得可能なメソッド</b>  
  # {Nicos::Movie#getInfo Movie::getInfo}  
  # {Nicos::Movie#getInfo Movie::getHtmlInfo}  
  # {Nicos::Movie#getInfo Mylist::getInfo}  
  # {Nicos::Movie#getInfo Mylist::getHtmlInfo}
  attr_accessor	:thumbnail_url

  # 動画の投稿日
  #
  # @return [Fixnum]
  # <b>取得可能なメソッド</b>  
  # {Nicos::Movie#getInfo Movie::getInfo}  
  # {Nicos::Movie#getInfo Movie::getHtmlInfo}  
  # {Nicos::Movie#getInfo Mylist::getInfo}  
  # {Nicos::Movie#getInfo Mylist::getHtmlInfo}
  attr_accessor	:first_retrieve

  # 取得時の再生数
  #
  # @return [Fixnum]
  # <b>取得可能なメソッド</b>  
  # {Nicos::Movie#getInfo Movie::getInfo}  
  # {Nicos::Movie#getInfo Movie::getHtmlInfo}  
  # {Nicos::Movie#getInfo Mylist::getInfo}  
  # {Nicos::Movie#getInfo Mylist::getHtmlInfo}
  attr_accessor	:view_counter

  # 取得時のマイリスト数
  #
  # @return [Fixnum]
  # <b>取得可能なメソッド</b>  
  # {Nicos::Movie#getInfo Movie::getInfo}  
  # {Nicos::Movie#getInfo Movie::getHtmlInfo}  
  # {Nicos::Movie#getInfo Mylist::getInfo}  
  # {Nicos::Movie#getInfo Mylist::getHtmlInfo}
  attr_accessor	:mylist_counter

  #　取得時のコメント数
  #
  # @return [Fixnum]
  # <b>取得可能なメソッド</b>  
  # {Nicos::Movie#getInfo Movie::getInfo}  
  # {Nicos::Movie#getInfo Movie::getHtmlInfo}  
  # {Nicos::Movie#getInfo Mylist::getInfo}  
  # {Nicos::Movie#getInfo Mylist::getHtmlInfo}
  attr_accessor	:comment_num

  # 動画の長さ（秒）
  #
  # @return [Fixnum]
  # <b>取得可能なメソッド</b>  
  # {Nicos::Movie#getInfo Movie::getInfo}  
  # {Nicos::Movie#getInfo Movie::getHtmlInfo}  
  # {Nicos::Movie#getInfo Mylist::getInfo}  
  # {Nicos::Movie#getInfo Mylist::getHtmlInfo}
  attr_accessor	:length

  # 削除されたかどうか。削除済みの場合は1、そうでなければ0。
  #
  # @return [Fixnum]
  # <b>取得可能なメソッド</b>  
  # {Nicos::Movie#getInfo Movie::getInfo}  
  # {Nicos::Movie#getInfo Movie::getHtmlInfo}  
  # {Nicos::Movie#getInfo Mylist::getInfo}  
  # {Nicos::Movie#getInfo Mylist::getHtmlInfo}
  attr_accessor	:deleted

  # 最新のコメント
  #
  # @return [String]
  # <b>取得可能なメソッド</b>  
  # {Nicos::Movie#getInfo Movie::getInfo}  
  # {Nicos::Movie#getInfo Movie::getHtmlInfo}  
  # {Nicos::Movie#getInfo Mylist::getInfo}  
  # {Nicos::Movie#getInfo Mylist::getHtmlInfo}
  attr_accessor	:last_res_body

  # ?
  #
  # @return [String]
  # <b>取得可能なメソッド</b>  
  # {Nicos::Movie#getInfo Movie::getInfo}  
  # {Nicos::Movie#getInfo Movie::getHtmlInfo}  
  # {Nicos::Movie#getInfo Mylist::getInfo}  
  # {Nicos::Movie#getInfo Mylist::getHtmlInfo}
  attr_accessor	:watch

  # 動画の投稿日に近いが、若干こちらの方が遅い。詳細不明。
  #
  # マイリストHTML中JSオブジェクトの"create_time"、マイリストAtomフィードにおける<published>に対応。
  #
  # @return [Fixnum]
  # <b>取得可能なメソッド</b>  
  # {Nicos::Movie#getInfo Mylist::getInfo}  
  # {Nicos::Movie#getInfo Mylist::getHtmlInfo}
  attr_accessor	:create_time

  # 動画の更新日？
  #
  # マイリストHTML中JSオブジェクトの"update_time"、マイリストAtomフィードにおける<updated>に対応。
  #
  # @return [Fixnum]
  # <b>取得可能なメソッド</b>  
  # {Nicos::Movie#getInfo Mylist::getInfo}  
  # {Nicos::Movie#getInfo Mylist::getHtmlInfo}
  attr_accessor :update_time
  # MylistAPI-Atom

  # マイリストの動画紹介欄に記載される説明文
  # 
  # @return [String]
  # <b>取得可能なメソッド</b>  
  # {Nicos::Movie#getInfo Movie::getInfo}  
  # {Nicos::Movie#getInfo Movie::getHtmlInfo}  
  # {Nicos::Movie#getInfo Mylist::getInfo}  
  # {Nicos::Movie#getInfo Mylist::getHtmlInfo}
  attr_accessor :memo

  
  # getThumbInfo

  # 動画ファイルの種類。
  #
  # @return [String]
  # <b>取得可能なメソッド</b>  
  # {Nicos::Movie#getInfo Movie::getInfo}  
  attr_accessor	:movie_type

  # 高画質時の動画サイズ？
  #
  # @return [Fixnum]
  # <b>取得可能なメソッド</b>  
  # {Nicos::Movie#getInfo Movie::getInfo}  
  attr_accessor	:size_high

  # 低画質時の動画サイズ？
  #
  # @return [Fixnum]
  # <b>取得可能なメソッド</b>  
  # {Nicos::Movie#getInfo Movie::getInfo}  
  attr_accessor	:size_low

  # 動画の閲覧URL
  #
  # @return [String]
  # <b>取得可能なメソッド</b>  
  # {Nicos::Movie#getInfo Movie::getInfo}  
  attr_accessor	:watch_url

  # ？
  #
  # @return [String]
  # <b>取得可能なメソッド</b>  
  # {Nicos::Movie#getInfo Movie::getInfo}  
  attr_accessor	:thumb_type

  # ブログ等に埋め込み、ログインなしでも閲覧できるかどうか。可能なら1。
  #
  # @return [Fixnum]
  # <b>取得可能なメソッド</b>  
  # {Nicos::Movie#getInfo Movie::getInfo}  
  attr_accessor :embeddable

  # ニコニコ生放送の拒否？
  #
  # @return [Fixnum]
  # <b>取得可能なメソッド</b>  
  # {Nicos::Movie#getInfo Movie::getInfo}  
  # {Nicos::Movie#getInfo Movie::getHtmlInfo}  
  attr_accessor :no_live_play

  # 日本語タグ
  #
  # @return [Array<String>]
  # <b>取得可能なメソッド</b>  
  # {Nicos::Movie#getInfo Movie::getInfo}  
  # {Nicos::Movie#getInfo Movie::getHtmlInfo}  
  attr_accessor	:tags_jp

  # 台湾タグ
  #
  # @return [Array<String>]
  # <b>取得可能なメソッド</b>  
  # {Nicos::Movie#getInfo Movie::getInfo}  
  attr_accessor	:tags_tw

  # ユーザID
  #
  # @return [Fixnum]
  # <b>取得可能なメソッド</b>  
  # {Nicos::Movie#getInfo Movie::getInfo}  
  # {Nicos::Movie#getInfo Movie::getHtmlInfo}  
  attr_accessor	:user_id

end
