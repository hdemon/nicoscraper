# -*- encoding: utf-8 -*-
$:.unshift File.dirname(__FILE__) + "/../lib"

require 'nicoscraper'

describe Nicos::Movie, "After executiton of 'getInfo' method" do  
  before(:all) do
    @movie = Nicos::Movie.new("sm1097445")
    @movie.getInfo
  end

  it "should have following values" do
    @movie.available    .should be_true
  
    @movie.video_id     .should == "sm1097445"
    @movie.title        .should == "【初音ミク】みくみくにしてあげる♪【してやんよ】"
    @movie.description  .should_not be_nil
    @movie.thumbnail_url.should_not be_nil
    @movie.first_retrieve.should == 1190218922
    @movie.length       .should == 99
    @movie.movie_type   .should == "flv"
    @movie.size_high    .should == 3906547
    @movie.size_low     .should == 1688098

    @movie.view_counter .should_not be_nil
    @movie.comment_num  .should_not be_nil
    @movie.mylist_counter .should_not be_nil 
    @movie.last_res_body.should_not be_nil 

    @movie.watch_url    .should == "http://www.nicovideo.jp/watch/sm1097445"
    @movie.thumb_type   .should == "video"
    @movie.embeddable   .should == 1
    @movie.no_live_play .should == 0
    @movie.tags_jp      .should_not be_nil
    @movie.tags_tw      .should_not be_nil
    @movie.user_id      .should == 70391
  end    

  it "should return true when execute 'isBelongsTo' method." +
      "passing arguments (1450136)" do
    result = @movie.isBelongsTo(1450136)
    result .should_not be_nil
    result .should be_true
  end
end

describe Nicos::Movie, "when access with non-existent video_id" do
  before(:all) do
    @movie = Nicos::Movie.new("sm*nonexistent")
    @movie.getInfo
  end

  it "should be unavailable" do
    @movie.available    .should be_false
  end    
end

describe Nicos::Mylist, "After executiton of 'getInfo' method" do  
  before(:all) do
    @mylist = Nicos::Mylist.new(15196568)
    @mylist.getInfo
    puts @mylist
  end

  it "should have following values" do
    @mylist.available    .should be_true
  
    @mylist.mylist_id    .should == 15196568
    @mylist.user_id      .should be_nil
    @mylist.title        .should == "【Oblivion】おっさんの大冒険"
    @mylist.description  .should_not be_nil
    @mylist.public       .should be_nil
    @mylist.default_sort .should be_nil
    @mylist.create_time  .should be_nil
    @mylist.update_time  .should_not be_nil

    @mylist.icon_id      .should be_nil
    @mylist.movies       .should_not be_nil
    @mylist.movies       .should be_kind_of(Array)
    @mylist.author       .should == "おぽこ"
  end 

  it "should return over 0.9 when execute 'getSimilarity' method." +
      "passing arguments (1450136)" do
    result = @mylist.getSimilarity
    result .should_not be_nil
    result .should >= 0.9
  end
end

describe "When execute 'Nicos::Searcher::ByTag.execute' method " +
          "and return a string except \"continue\" in this block" do  
  before(:all) do
    searcher = Nicos::Searcher::ByTag.new()
    @count = 0

    searcher.execute("ゆっくり実況プレイpart1リンク", "post_old", nil) { |result|
      @count += 1
      "not continue"
    }
  end

  it "should end only one access." do
    @count.should == 1  
  end
end

describe "When execute 'Nicos::Searcher::ByTag.execute' method " +
          "and return a string except \"continue\" in this block" do  
  before(:all) do
    searcher = Nicos::Searcher::ByTag.new()
    @count = 0

    searcher.execute("ゆっくり実況プレイpart1リンク", "post_old", nil) { |result|
      @count += 1
      nil
    }
  end

  it "should end only one access." do
    @count.should == 1  
  end
end

describe "When execute 'Nicos::Searcher::ByTag.execute' method " +
          "passing following argument" do  
  before(:all) do
    searcher = Nicos::Searcher::ByTag.new()
    count = 0

    searcher.execute("ゆっくり実況プレイpart1リンク", "post_old", nil) { |result|
      @result = result

      count += 1
      puts count
      "continue" unless count >= 3
    }
    puts "end"
  end

  it "should have Array of movie objects." do
    @result   .should be_kind_of(Array)
    @result[0].should be_instance_of(Nicos::Movie)
  end

  it "should contains movie objects that have following structure." do
    @result[0].available    .should be_true
  
    @result[0].video_id     .should_not be_nil
    @result[0].title        .should_not be_nil
    @result[0].create_time  .should_not be_nil
    @result[0].update_time  .should_not be_nil
    #@result[0].memo         .should_not be_nil
    @result[0].description  .should_not be_nil
    @result[0].thumbnail_url.should_not be_nil
    @result[0].create_time  .should_not be_nil
    @result[0].update_time  .should_not be_nil
    @result[0].length       .should_not be_nil

    @result[0].view_counter .should_not be_nil
    @result[0].comment_num  .should_not be_nil
    @result[0].mylist_counter.should_not be_nil 
  end    
end