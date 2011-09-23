NicoScraper
====================

**My site:**  [http://hdemon.net](http://hdemon.net)  
**GitHub:**  [http://github.com/hdemon/nicoscraper](http://github.com/hdemon/nicoscraper)   
**Author:**  Masami Yonehara  
**Copyright:**  2011  
**License:**  MIT License  
**Latest Version:**  0.2.2  
**Release Date:**  Sep 23rd 2011  
 

何をするライブラリ？
------

　ニコニコ動画の動画ページ、検索ページ、あるいはそのAtomフィードから情報を取得し、その情報に対して各種操作を行えます。タグやマイリスト検索結果からの抽出、および抽出結果に対する反復処理を行うメソッドも備え、ランキングサイト等の制作を支援します。

インストール
------
　Ruby 1.9.2以外には、特に必要とするものはありません。

    $ gem install nicoscraper

　とした後、

    require 'nicoscraper' 

　で使い始めて下さい。

基本的な使い方
------

　Movieクラス、Mylistクラス、Searcherモジュールから主要な機能が構成されています。基本的には、動画やマイリストのIDを指定してインスタンスを作り、そこから詳細な情報を取得するためのメソッドを実行したのち、さらに分析や加工を行う別のメソッドを実行する、という手順を踏みます。

###動画情報の取得

　例えば"sm1097445"という動画IDから、タイトルや動画の長さ、現在の閲覧数等の詳細な情報を知りたいときは、

    require 'nicoscraper'

    movie = Nicos::Movie::new("sm1097445")
    movie.getInfo

    p movie

　Movieクラスのインスタンス（以下「動画インスタンス」）を動画IDを与えて生成した後、getInfoメソッドを利用します。その結果、

    <Nicos::Movie:0x00000002537aa8
      @video_id="sm1097445", 
      @available=false, 
      @title="【初音ミク】みくみくにしてあげる♪【してやんよ】", 
      @description="おまえら、みっくみくにしてやんよ。歌詞は...", 
      @thumbnail_url="http://tn-skr2.smile...", 
      @first_retrieve=1190218922, 
      @length=99, 
      @movie_type="flv", 
      @size_high=3906547, 
      @size_low=1688098, 
      @view_counter=9073614, 
      @comment_num=2553366, 
      @mylist_counter=183470, 
      @last_res_body="★███████████☆...", 
      @watch_url="http://www.nicovideo.jp/...", 
      @thumb_type="video", 
      @embeddable=1, 
      @no_live_play=0, 
      @tags_jp=["音楽", "初音ミク", ...], 
      @tags_tw=["彈幕強大", "把你MikuMiku掉♪", ...], 
      @user_id=70391 >
　このように、動画インスタンスにインスタンス変数として各種情報が付加されます。

###マイリスト情報の取得

　Mylistクラスもほぼ同様ですが、Mylistクラスのインスタンス（以下「マイリストインスタンス」）は、マイリスト情報の他に、そのマイリストが含む動画のインスタンスを自動的に生成します。つまり、

    require 'nicoscraper'

    mylist = Nicos::Mylist::new("")
    mylist.getInfoLt

    p mylist

このように実行すると、

    <Nicos::Mylist:0x00000002884670
      @mylist_id=15196568,
      @movies=[
        #<Nicos::Movie:0x0000000255a968
          @video_id="sm8481759", 
          @available=true, 
          @title="【Oblivion】おっさんの大冒険１（ゆっくり実況）",
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

　というように、動画インスタンスを勝手につくりだして配列として保持します。もちろん、これらの動画インスタンスには独立した操作を加えられます。

###検索結果の取得

　タグやマイリスト検索結果からの情報取得には、Searcherモジュールを使います。情報のソート方法の指定、取得する範囲の制限が可能です。

    require 'nicoscraper'

    t = Time.now
    ytd = Date::new(t.year, t.month, t.day) - 1
    yesterday = Time.local(ytd.year, ytd.month, ytd.day, 0, 0, 0).to_i

    searcher = Nicos::Searcher::ByTag.new()

    searcher.execute('ゆっくり実況プレイpart1リンク', 'post_new', nil) {
      |result, page|

      result.each { |movieObj|
        puts movieObj.title +
          " is posted at " +
           Time.at(movieObj.first_retrieve).to_s

        "continue" if movieObj.first_retrieve >= yesterday 
      }  
    }

　この例では、'ゆっくり実況プレイpart1リンク'というタグの付く動画を、post_new=投稿日時が新しい順からさかのぼって取得し、取得した動画の日付が前日の0時0分を超えるまでそれを続けます。 

　ブロック内の第1引数には取得結果に基づく動画インスタンスが与えられるのですが、これは32個分の配列です。なぜ32個のセットなのかと言うと、ご存知のようにニコニコ動画の検索画面はページで区切られており、Searcherモジュールの各メソッドはページ毎に情報を取得し、ページ単位でブロックをコールするからです。Htmlから取得するにしろAtomフィードから取得するにしろ、1ページに32個の動画情報が含まれています。そして、第2引数には現在のページ数が与えられます。

　そして、ブロック内で"continue"を返すことによりスクレイプが継続します。つまり、"continue"を返し続けるロジックを組み込まないと、1ページ目を読んだ時点で処理が終了します。これは意図せざる過剰アクセスを防ぐための措置です。

　上の例では、取得した動画の日付を調べ、3日前の0時0分より前の動画に到達すればそこでループを終える設計です。ループを終えるために取得情報を使うかどうかは任意なので、例えば10分間の制限で取得出来るだけ取得するということも可能でしょう。

###取得した情報に対する操作

　現在のところ、以下のような操作が可能です。詳しい使い方は、各メソッドの説明を参照して下さい。

**動画の説明文からタイトルを取得する。**
{Nicos::Movie#extrMylist Nicos::Movie::extrMylist}
　動画の説明文中に、'mylist/...'という表記で投稿者がマイリストを提示している事があります。extrMylistはこれを全て取得し、配列として返します。


**指定したマイリストに、自分自身が入っているかを調べる。**
{Nicos::Movie#isBelongsTo Nicos::Movie::isBelongsTo}


**そのマイリスト内に含まれる全ての動画の、タイトルの類似性を調べる。**
{Nicos::Mylist#getSimilarity Nicos::Mylist::getSimilarity}
　マイリストのシリーズ性を判定するために、マイリスト内の全ての動画の組み合わせで、タイトルの「編集距離」に基づく類似度を計算します。


**その動画が属する、シリーズとみなせるマイリストのIDを返します。**
{Nicos::Movie#isSeriesOf Nicos::Movie::isSeriesOf}
　isBelongsToとgetSimiralityの組み合わせにより、ある動画の説明文中にマイリストの記載がある場合、そのマイリストがタイトルの類似性によるシリーズとみなせるならば、そのIDを返します。


注意点、および免責事項
------

　それぞれのメソッドは大半がニコニコ動画へのアクセスを伴い、特にSearcherモジュールは継続的かつ無制限なアクセスを可能にするため、使用には十分注意して下さい。その点を考慮し、Searcherモジュールのデフォルトのウェイトはかなり大きめに設定してあります。

　使用する際には、ご自分の責任においてウェイトを変更して下さい。**本ライブラリの使用によって発生した損害および法的な責任については、ライブラリのバグに起因するものを含め、一切の責任を負いかねます。**

　なお、Htmlからスクレイプするメソッドよりも、Atomフィードを使うメソッドの方がニコニコ動画側の負荷が（たぶん）軽く、アクセス制限などは起こりにくくなっています。大半の情報はAtomフィードで取得できるため、そうでない情報を取得したい場合に限り、Htmlを利用するメソッドを使うべきでしょう。


用語・用法
------

**動画インスタンス**
Movieクラスのインスタンス

**マイリストインスタンス**
Mylistクラスのインスタンス

**動画ID | video_id**
ニコニコ動画の各動画に与えられる、sm|nmで始まる一意のID。

**アイテムID | item_id**
動画に与えられるもう一つの一意なIDであり、投稿日時と同じか非常に近いUNIX時間になっている。例えば、"【初音ミク】みくみくにしてあげる♪【してやんよ】"の動画IDはsm1097445であり、アイテムIDは1190218917である。このアイテムIDを日時に直すと、日本時間における2007年9月20日 1:21:57となるが、動画に投稿日時として表示されるのは、2007年9月20日 1:22:02である。


今後の予定
------

**v0.3**

+ HTMLから取得・解析するメソッドの追加。

+ キーワード検索の実装

**v0.4-**

+ シリーズ性判定の強化。説明文中にある「次 sm***」等の表記を解析し、マイリストに頼らずにシリーズ性を判定するようにする。

+ コミュニティ動画、限定公開動画・マイリストへの対応。


更新履歴
------

**v0.2.4**

+ ドキュメント作成

+ Searcherループのバグ修正。 

+ Searcherループの継続判定を、ブロック内で"continue"を返す事を要求する方式に変更。