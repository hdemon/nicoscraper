# -*- encoding: utf-8 -*-
# $:.unshift File.dirname(__FILE__) + "/../lib"

require '../lib/nicoscraper.rb'

describe "When execute 'Nicos::Searcher::ByTag.execute' method " +
          "and return a string except \"continue\" in this block" do  
  before(:all) do
    searcher = Nicos::Searcher::ByTag.new()
    @count = 0

    searcher.execute("ゆっくり実況プレイpart1リンク", "post_old") { |result|
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

    searcher.execute("ゆっくり実況プレイpart1リンク", "post_old") { |result|
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

    searcher.execute("ゆっくり実況プレイpart1リンク", "post_old") { |result|
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

describe "When execute 'Nicos::Connector::setWait" do
  before(:all) do
    wait = {
      'seqAccLimit' => 100,
     
      'deniedSeqReq'=> {   
        'retryLimit'  => 30,  
        'wait'        => 1200  
      },
      
      'serverIsBusy'=> {   
        'retryLimit'  => 10
      }
    }

    Nicos::Connector::Config::setWait(wait)
  end

  it "should have following values." do
    c = Nicos::Searcher::ByTag.new()  
    c.waitConfig    .should_not be_nil
    c.waitConfig["seqAccLimit"]
                    .should == 100
    c.waitConfig["afterSeq"]
                    .should == 10
    c.waitConfig["each"]
                    .should == 1
    c.waitConfig["increment"]
                    .should == 1
    c.waitConfig["deniedSeqReq"]["retryLimit"]
                    .should == 30
    c.waitConfig["deniedSeqReq"]["wait"]
                    .should == 1200
    c.waitConfig["serverIsBusy"]["retryLimit"]
                    .should == 10
    c.waitConfig["serverIsBusy"]["wait"]
                    .should == 120
    c.waitConfig["serviceUnavailable"]["retryLimit"]
                    .should == 3
    c.waitConfig["serviceUnavailable"]["wait"]
                    .should == 120
    c.waitConfig["timedOut"]["retryLimit"]
                    .should == 3
    c.waitConfig["timedOut"]["wait"]
                    .should == 10
  end

  after(:all) do
    Nicos::Connector::Config::setWait("default")
  end  
end

describe "When execute 'Nicos::Connector::setWait" do
  before(:all) do
    wait = {
      'seqAccLimit' => 100,
     
      'deniedSeqReq'=> {   
        'retryLimit'  => 30,  
        'wait'        => 1200  
      },
      
      'serverIsBusy'=> {   
        'retryLimit'  => 10
      }
    }

    @c1 = Nicos::Searcher::ByTag.new()  
    @c1.setWait(wait)

    @c2 = Nicos::Searcher::ByTag.new()  
  end

  it "should have following values." do
    @c1.waitConfig    .should_not be_nil
    @c1.waitConfig["seqAccLimit"]
                    .should == 100
    @c1.waitConfig["afterSeq"]
                    .should == 10
    @c1.waitConfig["each"]
                    .should == 1
    @c1.waitConfig["increment"]
                    .should == 1
    @c1.waitConfig["deniedSeqReq"]["retryLimit"]
                    .should == 30
    @c1.waitConfig["deniedSeqReq"]["wait"]
                    .should == 1200
    @c1.waitConfig["serverIsBusy"]["retryLimit"]
                    .should == 10
    @c1.waitConfig["serverIsBusy"]["wait"]
                    .should == 120
    @c1.waitConfig["serviceUnavailable"]["retryLimit"]
                    .should == 3
    @c1.waitConfig["serviceUnavailable"]["wait"]
                    .should == 120
    @c1.waitConfig["timedOut"]["retryLimit"]
                    .should == 3
    @c1.waitConfig["timedOut"]["wait"]
                    .should == 10

    @c2.waitConfig    .should_not be_nil
    @c2.waitConfig["seqAccLimit"]
                    .should == 10
    @c2.waitConfig["afterSeq"]
                    .should == 10
    @c2.waitConfig["each"]
                    .should == 1
    @c2.waitConfig["increment"]
                    .should == 1
    @c2.waitConfig["deniedSeqReq"]["retryLimit"]
                    .should == 3
    @c2.waitConfig["deniedSeqReq"]["wait"]
                    .should == 120
    @c2.waitConfig["serverIsBusy"]["retryLimit"]
                    .should == 3
    @c2.waitConfig["serverIsBusy"]["wait"]
                    .should == 120
    @c2.waitConfig["serviceUnavailable"]["retryLimit"]
                    .should == 3
    @c2.waitConfig["serviceUnavailable"]["wait"]
                    .should == 120
    @c2.waitConfig["timedOut"]["retryLimit"]
                    .should == 3
    @c2.waitConfig["timedOut"]["wait"]
                    .should == 10
  end
end