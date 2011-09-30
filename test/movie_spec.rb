# -*- encoding: utf-8 -*-
#$:.unshift File.dirname(__FILE__) + "/../lib"

require '../lib/nicoscraper.rb'

describe Nicos::Movie, "After executiton of 'getInfo' method." +
    "And for example, with passing argument (sm1097445)" do

  before(:all) do
    @movie = Nicos::Movie.new("sm1097445")
    @result = @movie.getInfo
  end

  it "should have the following structure and values." do
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
      "with passing arguments (1450136)" do
    result = @movie.isBelongsTo(1450136)
    result .should_not be_nil
    result .should be_true
  end

  it "should return the following values." do
    @result[:parsed]   .should be_instance_of(Hash)
    @result[:status]   .should equal(:success)
    @result[:retry]    .should have_key(:deniedSeqReq)
    @result[:retry]    .should have_key(:serverIsBusy)
    @result[:retry]    .should have_key(:serviceUnavailable)
    @result[:retry]    .should have_key(:timedOut)

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
