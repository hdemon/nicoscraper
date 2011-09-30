# -*- encoding: utf-8 -*-
#$:.unshift File.dirname(__FILE__) + "/../lib"

require '../lib/nicoscraper.rb'

describe Nicos::Mylist, "After executiton of 'getInfo' method" +
    "And for example, with passing argument (15196568)" do  
  before(:all) do
    @mylist = Nicos::Mylist.new(15196568)
    @mylist.getInfo
  end


  it "should have the following values" do
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


  it "should have Movie class instances. and these have the following structure." do
    @mylist.available.should be_true
  
    @mylist.mylist_id.should === 15196568
    @mylist.movies          .should be_instance_of(Array)

    movieObj = @mylist.movies[0]
    movieObj.available      .should be_true
  
    movieObj.video_id       .should_not be_nil
    movieObj.title          .should_not be_nil
    movieObj.first_retrieve .should_not be_nil
    #movieObj.memo         .should_not be_nil
    movieObj.description    .should_not be_nil
    movieObj.thumbnail_url  .should_not be_nil
    movieObj.length         .should_not be_nil

    movieObj.view_counter   .should_not == 0
    movieObj.comment_num    .should_not == 0
    movieObj.mylist_counter .should_not == 0
  end    

end


describe Nicos::Mylist, "After executiton of 'getInfo' method" +
    "for non-existent mylist." do  
  before(:all) do
    @mylist = Nicos::Mylist.new(999999999)
  end

  it "should " do
    r = @mylist.getInfo
    r[:status]  .should === :notFound
    r[:result]  .should be_nil

    @mylist.available   .should_not be_true
  end
end


describe Nicos::Mylist, "After executiton of 'getInfo' method" +
    "for nonpublic mylist." do  
  before(:all) do
    @mylist = Nicos::Mylist.new(22947348)
  end

  it "should " do
    r = @mylist.getInfo
    r[:status]  .should === :notPublic
    r[:result]  .should be_nil

    @mylist.available   .should_not be_true
  end
end

# マイリストは削除と404の区別がない？
describe Nicos::Mylist, "After executiton of 'getInfo' method" +
    "for deleted mylist." do  
  before(:all) do
    @mylist = Nicos::Mylist.new(23361251) # 自分のマイリストで、公開設定にしてから削除したもの。
  end

  it "should " do
    r = @mylist.getInfo
    # r["status]  .should === :deleted
    r[:status]  .should === :notFound
    r[:result]  .should be_nil

    @mylist.available   .should_not be_true
  end
end


describe Nicos::Mylist, "After executiton of 'getInfo' method" do  
  before(:all) do
    @mylist = Nicos::Mylist.new(15196568)
    @mylist.getInfo
  end

  it "should return over 0.9 when execute 'getSimilarity' method." +
      "passing arguments (1450136)" do
    result = @mylist.getSimilarity
    result .should_not be_nil
    result .should >= 0.9
  end
end
