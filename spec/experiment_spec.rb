require File.dirname(__FILE__) + '/../spec_helper'
require "rubygems"
require "active_resource"
require "active_resource/http_mock"
require "rome"

module XmlHelper
  
  def self.included(base)
    base.extend self
  end
  
  def xml_elements(*args)
    self.class_eval do
      define_method(:to_xml) do |*xml_args|
        
        options = xml_args.first || {}
        
        hash = returning(Hash.new) do |hash|
          args.each { |arg| hash[arg] = self.send(arg) }
        end
        hash.to_xml({:root => self.class.name.downcase}.merge(options))
      end
    end
  end
end

def project(name,&block)
  p = Project.new(name)
  yield(p)
  p
end

class User < Struct.new(:id, :name)
  
  include XmlHelper
  
  xml_elements :id, :name
  
  def tickets
    @tickets ||= []
  end
  
  def assign(ticket)
    tickets << ticket
    ticket
  end
  
end

class Milestone < Struct.new(:id, :name)
  
  include XmlHelper
  
  xml_elements :id, :name, :tickets
  
  def tickets
    @tickets ||= []
  end
  
  def ticket(ticket_name)
    ticket = Ticket.new(ticket_name)
    ticket.milestone = self
    yield(ticket)
    tickets << ticket
    ticket
  end
end

class Ticket < Struct.new(:name)
  
  include XmlHelper
  
  xml_elements :name, :versions
  
  attr_accessor :milestone
  
  def versions
    @versions ||= []
  end
  alias :comments :versions
  
  def comment(body)
    returning(Version.new(body)) do |comment|
      versions << comment
    end
  end
  
end

class Version < Struct.new(:body)
  
  include XmlHelper
  
  xml_elements :body, :created_at
  
  def created_at
    @created_at ||= Time.now
  end
  
  def on(date)
    @created_at = date
  end
end

class Project
  
  attr_accessor :name, :users, :milestones
  
  def initialize(name)
    @name = name
    @users = []
    @milestones = []
  end
  
  def milestone(name)
    if ms = @milestones.detect { |ms| ms.name == name }
      yield(ms) if block_given?
      ms
    end
  end
  
  def user(id)
    users.detect { |user| user.id == id }
  end
end

describe "Something Pretty" do
  before(:each) do
    @project = project("Soocial") do |project|
      
      project.users << User.new(1, "Simon de Haan")
      project.users << User.new(2, "Tijn Schuurmans")
      project.users << User.new(3, "Tiago Macedo")
      
      project.milestones << Milestone.new(1, "Lame Luke")
      
      project.milestone("Lame Luke") do |milestone|
        
        webapp_ticket = milestone.ticket("webapp bug") do |ticket|
          ticket.comment(2.hours).on(2.days.ago)
          ticket.comment(2.hours).on(1.day.ago)
          ticket.comment(30.minutes).on(1.hour.ago)
        end
        
        havana_ticket = milestone.ticket("havana bug") do |ticket|
          ticket.milestone = milestone
          ticket.comment(2.hours).on(2.days.ago)
          ticket.comment(2.hours).on(1.day.ago)
          ticket.comment(30.minutes).on(1.hour.ago)
        end
        
        project.user(1).assign webapp_ticket
        project.user(1).assign havana_ticket
        
      end
    end
  end
  
  it "should store the name" do
    @project.name.should == "Soocial"
  end
  
  it "should store the users" do
    @project.users.should have(3).items
    @project.user(1).should == User.new(1, "Simon de Haan")
    @project.user(2).should == User.new(2, "Tijn Schuurmans")
    @project.user(3).should == User.new(3, "Tiago Macedo")
    @project.user(4).should be_nil
  end
  
  it "should store the milestones" do
    @project.milestones.should have(1).item
    @project.milestone("Lame Luke").should == Milestone.new(1, "Lame Luke")
    @project.milestone("BLame Fluke").should be_nil
  end
  
  it "should store the tickets" do
    @project.user(1).tickets.should have(2).items
    @project.user(1).tickets[0].milestone.should == Milestone.new(1, "Lame Luke")
    @project.user(1).tickets[1].milestone.should == Milestone.new(1, "Lame Luke")
    
    @project.milestone("Lame Luke").tickets.should have(2).items
    @project.milestone("Lame Luke").tickets.should == @project.user(1).tickets
  end
  
  it "should store the comments in the tickets" do
    ticket = @project.user(1).tickets.first
    ticket.comments.should have(3).items
    ticket.comments[0].body.should == 2.hours
    ticket.comments[1].body.should == 2.hours
    ticket.comments[2].body.should == 30.minutes
  end
end
