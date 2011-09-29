# -*- encoding: utf-8 -*-
#$:.unshift File.dirname(__FILE__) + "/../lib"

require '../lib/nicoscraper.rb'

describe Nicos::Movie, "After executiton of 'getInfo' method" do  
  before(:all) do
    @mylist = Nicos::Mylist.new(15196568)
    @mylist.getInfo
    p @mylist
  end

  it "should have following values" do
    @mylist.available.should be_true
  
    @mylist.mylist_id.should === 15196568
    @mylist.movies   .should be_instance_of(Array)

    movieObj = @mylist.movies[0]
    movieObj.available    .should be_true
  
    movieObj.video_id     .should_not be_nil
    movieObj.title        .should_not be_nil
    movieObj.first_retrieve  .should_not be_nil
    #movieObj.memo         .should_not be_nil
    movieObj.description  .should_not be_nil
    movieObj.thumbnail_url.should_not be_nil
    movieObj.length       .should_not be_nil

    movieObj.view_counter .should_not be_nil
    movieObj.comment_num  .should_not be_nil
    movieObj.mylist_counter.should_not be_nil 
  end    

end
