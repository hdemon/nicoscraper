#どんなライブラリか
　ニコニコ動画から動画およびマイリスト情報を取得し、その情報に対して各種操作を行えます。タグやマイリスト検索結果からの抽出、および抽出結果に対する反復処理を行うメソッドも備え、ランキングサイト等の制作を支援します。

#簡単な概要
　Movieクラス、Mylistクラス、Searcherモジュールから主要な機能が構成されています。基本的には、動画やマイリストのIDを指定してインスタンスを作り、そこから詳細な情報を取得するためのメソッドを実行したのち、さらに分析や加工を行う別のメソッドを実行する、という手順を踏みます。

##動画情報の取得

　例えば"sm1097445"という動画IDから、タイトルや動画の長さ、現在の閲覧数等の詳細な情報を知りたいときは、

~~~~
require 'nicoscraper'

movie = Nicos::Movie::new("sm1097445")
movie.getInfo

p movie

<Nicos::Movie:0x00000002537aa8
	@video_id="sm1097445", 
	@available=false, @title="【初音ミク】みくみくにしてあげる♪【してやんよ】", 
	@description="おまえら、みっくみくにしてやんよ。歌詞はhttp://ikamo.hp.infoseek.co.jp/mikumiku.txt（9/20 1:55修正）。上げている他のもの→mylist/1450136", 
	@thumbnail_url="http://tn-skr2.smilevideo.jp/smile?i=1097445", 
	@first_retrieve=1190218922, 
	@length=99, 
	@movie_type="flv", 
	@size_high=3906547, 
	@size_low=1688098, 
	@view_counter=9073614, 
	@comment_num=2553366, 
	@mylist_counter=183470, 
	@last_res_body="★███████████☆ ☆████████████●●●●███ ★█████... ", 
	@watch_url="http://www.nicovideo.jp/watch/sm1097445", @thumb_type="video", 
	@embeddable=1, 
	@no_live_play=0, 
	@tags_jp=["音楽", "初音ミク", "みくみくにしてあげる♪", "ミクオリジナル曲", "ika", "VOCALOID殿堂入り", "元気が出るミクうた", "VOCALOID", "初音ミク名曲リンク", "深夜みっく"], 
	@tags_tw=["彈幕強大", "把你MikuMiku掉♪", "週刊vocaloid排行榜第1名獲得曲", "翻譯歌曲", "台灣VOCALOID評論人氣曲", "最強彈幕傳說", "初音未來"], 
	@user_id=70391 >

~~~~

　このように、Movieクラスのインスタンス（以下「動画インスタンス」）のgetInfoメソッドを利用します。その結果、動画インスタンスにインスタンス変数として各種情報が付加されます。

##マイリスト情報の取得
　Mylistクラスもほぼ同様ですが、Mylistクラスのインスタンス（以下「マイリストインスタンス」）は、マイリスト情報の他に、そのマイリストが含む動画のインスタンスを自動的に生成します。つまり、

~~~~
require 'nicoscraper'

mylist = Nicos::Mylist::new("")
mylist.getInfoLt

p mylist

# 結果
#<Nicos::Mylist:0x00000002884670
　@mylist_id=15196568,
	@movies=[
		#<Nicos::Movie:0x0000000255a968
			@video_id="sm8481759", 
			@available=true, @title="【Oblivion】おっさんの大冒険１（ゆっくり実況）",
			...
		#<Nicos::Movie:0x0000000251a6b0 
			@video_id="sm8506034",
		 	@available=true,
		 	@title="【Oblivion】おっさんの大冒険２（ゆっくり実況）",
		 	...
	],
	@available=true,
	@title="【Oblivion】おっさんの大冒険", 
	... >
~~~~

　というように、動画インスタンスを勝手につくりだして配列として保持します。

##検索結果の取得

　タグやマイリスト検索結果からの情報取得には、Searcherモジュールを使います。情報のソート方法の指定、取得する範囲の制限が可能です。

~~~~
require 'nicoscraper'

t = Time.now
ytd = Date::new(t.year, t.month, t.day) - 1
yesterday = Time.local(ytd.year, ytd.month, ytd.day, 0, 0, 0).to_i

Searcher.byTag('ゆっくり実況プレイpart1リンク', 'post_new', nil) {
  |result, page|

	result.each { |e|
    movie = Nicos::Movie.new(e['video_id'])
    movie.getInfo

	  puts movie.title.toutf8 +
      " is posted at " +
       Time.at(movie.first_retrieve).to_s.toutf8

    true if movie.first_retrieve <= yesterday 
  }  
}
~~~~

　これは'ゆっくり実況プレイpart1リンク'というタグの付く動画を、post_new=投稿日時が新しい順からさかのぼって取得していき、取得した動画の日付が前日の0時0分を超えるまでそれを続けます。 

　ブロック内の第1引数には取得結果が与えられるのですが、これは動画1つ毎のコールバックではなく、32個分の配列です。なぜ32個のセットなのかと言うと、ご存知のようにニコニコ動画の検索画面はページで区切られており、Searcherモジュールの各メソッドはページ毎に情報を取得するためです。Htmlから取得するにしろAtomフィードから取得するにしろ、1ページに32個の動画情報が含まれています。そして、第2引数にはそのページ数が与えられます。

　なお、ブロック内でtrueを返すことによりスクレイプは終わります。逆に言えば、trueを返さない限り検索結果全ての情報を取得しようとするため、十分に注意して下さい。上の例では、取得した動画の日付を調べ、3日前の0時0分より前の動画があればそこでループを終える設計です。


#より詳しい情報

は、こちらを御覧下さい。