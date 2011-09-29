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
  end    

end
