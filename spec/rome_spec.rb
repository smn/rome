require File.dirname(__FILE__) + '/../spec_helper'
require "active_resource"
require "active_resource/http_mock"
require "rome"

def projects
  [{:id => 1, :title => "lighthouse project", :open_states_list => "new,open,review"}]
end

def milestones
  milestones = returning(Array.new) do |array|
    projects.each do |project|
      array << {:project_id => project[:id], :id => 1, :created_at => (15.days.ago - 1.week), :due_on => (15.days.ago.utc), :title => "2 weeks ago", :open_tickets_count => 0, :tickets_count => 3}
      array << {:project_id => project[:id], :id => 2, :created_at => (1.day.ago - 1.week).utc.midnight, :due_on => 1.day.ago.utc.midnight, :title => "late milestone", :open_tickets_count => 10, :tickets_count => 5}
      array << {:project_id => project[:id], :id => 3, :created_at => (1.day.from_now - 1.week), :due_on => 1.day.from_now.utc, :title => "current milestone", :open_tickets_count => 10, :tickets_count => 3}
      array << {:project_id => project[:id], :id => 4, :created_at => Time.now, :due_on => 1.week.from_now.utc, :title => "future milestone", :open_tickets_count => 20, :tickets_count => 3}
    end
  end
  
  # add the starts: magic token to the goals
  milestones.collect do |milestone|
    milestone[:goals] = "#start #{milestone[:created_at].strftime("%d-%m-%Y")}"
    milestone
  end
  
end

def current_milestone
  sorted_ms = milestones.sort_by { |ms| ms[:created_at] }
  sorted_ms.detect { |ms| ms[:open_tickets_count] > 0 }
end

def tickets(params={})
  returning(Array.new) do |tickets|
    milestones.each do |milestone|
      1.upto(3) do |ticket_id|
        tickets << {
          :id => (milestone[:id] * 10) + ticket_id,
          :milestone_id => milestone[:id],
          :title => "ticket #{ticket_id} for #{milestone[:title]}",
          :versions => [
            { :body => "Some comment\n#e00:15", :created_at => 2.days.ago.utc },
            { :body => "Some comment\n#e00:30", :created_at => 1.day.ago.utc },
            { :body => "Some comment\n#e01:30", :created_at => 1.hour.ago.utc }
          ]
        }
      end
    end
  end
end

def sample_sprint_tickets_for(milestone)
  returning(Array.new) do |tickets|
    
    hours = [
      ["#e01:00","#e01:00","#e01:00","#e00:00","#e00:00","#e00:00"],
      ["#e01:00","#e01:00","#e00:00","#e00:00","#e00:00","#e00:00"],
      ["#e02:00","#e02:00","#e01:00","#e01:00","#e00:00","#e00:00"],
      ["#e03:00","#e02:00","#e00:00","#e00:00","#e00:00","#e00:00"],
      ["#e03:00","#e03:00","#e04:00","#e03:00","#e02:00","#e00:00"]
    ]
    
    hours.each_with_index do |hours, ticket_id|
      versions = []
      
      hours.each_with_index do |hour, index|
        created_at = current_milestone[:created_at] + index.days
        versions << { :body => "\n#{hour}\n", :created_at => created_at }
      end
      
      tickets << {
        :id => (milestone[:id] * 10) + ticket_id,
        :milestone_id => milestone[:id],
        :title => "ticket #{ticket_id} for #{milestone[:title]}",
        :versions => versions,
        :state => "resolved",
      }
      
    end
  end
end

def tickets_for_milestone(id)
  tickets.select { |t| t[:milestone_id] == id }
end

def request_header
  { "X-LighthouseToken" => token }
end

def bad_request_header
  { "X-LighthouseToken" => "bad token" }
end

def token
  "65567e443747ea74830ddde9c514ad5e32228eea"
end

def query_tickets(params)
  '/projects/1/tickets.xml?' + {:q => "milestone:'%s'" % current_milestone[:title] }.merge(params).to_query
end

def mock_requests!
  ActiveResource::HttpMock.respond_to do |mock|
    mock.get '/projects.xml', request_header, projects.to_xml(:root => "project")
    mock.get '/projects.xml', bad_request_header, nil, 401
    mock.get '/projects/1/milestones.xml', request_header, milestones.to_xml(:root => "milestone")
    mock.get '/projects/1/milestones/current.xml', request_header, current_milestone.to_xml(:root => "milestone")
    mock.get '/projects/1/tickets.xml', request_header, tickets.to_xml(:root => "ticket")
    
    mock.get query_tickets(:page => 1), request_header, sample_sprint_tickets_for(current_milestone).to_xml(:root => "ticket")
    # mock an empty result, pagine quits when it no longer gets results
    mock.get query_tickets(:page => 2), request_header, [].to_xml(:root => "ticket")
    
    # get all the tickets for the project
    mock.get query_tickets(:page => 1, :q=>'all'), request_header, tickets.to_xml(:root => "ticket")
    mock.get query_tickets(:page => 2, :q=>'all'), request_header, [].to_xml(:root => "ticket")
  end
end

describe Rome::Account do
  
  before(:each) do
    mock_requests!
    @account = Rome::Account.new("soocial", token)
  end
  
  it "should be able to authenticate with a token" do
    @account = Rome::Account.new("soocial", token)
    @account.should be_authorized

    @account = Rome::Account.new("soocial", "bad token")
    @account.should_not be_authorized
  end
  
  it "should return a list of projects defined" do
    @account.should have(1).projects # the test project
    @account.projects.first.id.should == 1
    @account.projects.first.title.should == "lighthouse project"
  end
end

describe Rome::Project do
  
  before(:each) do
    mock_requests!
    @account = Rome::Account.new("soocial", token)
    @project = @account.projects.first
  end
  
  it "should return a list of milestones" do
    @project.should have_at_least(1).milestones
  end
  
  it "should return a list of open milestones" do
    @project.should have_at_least(1).open_milestones
  end
  
  it "should return the current milestone" do
    @project.current_milestone.id.should == current_milestone[:id]
    @project.open_milestones.should include(@project.current_milestone)
  end
  
  it "should return the previous milestone" do
    @project.previous_milestone.id.should == 1
    @project.open_milestones.should_not include(@project.previous_milestone)
  end
  
  it "should return the late milestones" do
    @project.should have(1).late_milestone
  end
  
  it "should return the future milestones" do
    @project.should have(2).future_milestone
  end
  
  it "should return a list of all tickets for the project" do
    @project.should have(milestones.size * 3).tickets
  end
  
end

describe Rome::Milestone do
  
  before(:each) do
    mock_requests!
    @account = Rome::Account.new("soocial", token)
    @project = @account.projects.first
    @milestone = @project.current_milestone
  end
  
  it "should return the tickets for the given milestone" do
    @milestone.should have(@milestone.tickets_count).tickets
  end
  
  it "should return the duration of the milestone in seconds" do
    # ugh daylight savings time got me here, keep an approximation
    # of an hour otherwise tests fail if you've gone into summer / winter
    # time in the last 14 days
    
    @milestone.duration.should == 1.week + 1.day # starting 00 in the morning, ending 00 on the last day
  end
  
  it "should return the total number of work for the given tickets" do
    @milestone.time_total.should == 10.hours
  end
  
  it "should return the time remaining for a given day" do
    @milestone.time_remaining_on_day(@milestone.start_on + 0.days).should == 10.hours
    @milestone.time_remaining_on_day(@milestone.start_on + 1.days).should == 9.hours
    @milestone.time_remaining_on_day(@milestone.start_on + 2.days).should == 6.hours
    @milestone.time_remaining_on_day(@milestone.start_on + 3.days).should == 4.hours
    @milestone.time_remaining_on_day(@milestone.start_on + 4.days).should == 2.hours
    @milestone.time_remaining_on_day(@milestone.start_on + 5.days).should == 0.hours
  end
  
  it "should have the real and projected data equal at the first day" do
    @milestone.time_total.should == @milestone.time_remaining_on_day(@milestone.start_on)
  end
end

describe Rome::Ticket do
  
  before(:each) do
    mock_requests!
    @account = Rome::Account.new("soocial", token)
    @project = @account.projects.first
    @milestone = @project.current_milestone
    @ticket = @milestone.tickets.reject { |t| t.estimates.empty? }.first
    @ticket.should_not be_nil
  end
  
  it "should return the time estimate for a ticket" do
    @ticket.should have(6).estimates
    
    0.upto(2) do |i|
      # should be 01:00
      estimate = @ticket.estimates[i]
      estimate.time.should be_an_instance_of(Time)
      estimate.should respond_to(:to_i)
      estimate.time.hour.should == 1
      estimate.time.min.should == 0
    end
    
    3.upto(5) do |i|
      # should be 00:00
      estimate = @ticket.estimates[i]
      estimate.time.should be_an_instance_of(Time)
      estimate.should respond_to(:to_i)
      estimate.time.hour.should == 0
      estimate.time.min.should == 0
    end

  end
  
  it "should return the time estimate for a ticket on a given day" do
    
    @ticket.should have(6).estimates
    
    0.upto(2) do |i|
      # should be 01:00
      estimate = @ticket.estimate_for_day(@milestone.start_on + i.days)
      estimate.time.should be_an_instance_of(Time)
      estimate.should respond_to(:to_i)
      estimate.time.hour.should == 1
      estimate.time.min.should == 0
      estimate.created_at.should be_close(@milestone.start_on + i.days,1.hour + 1.second)
    end
    
    3.upto(5) do |i|
      # should be 00:00
      estimate = @ticket.estimates[i]
      estimate.time.should be_an_instance_of(Time)
      estimate.should respond_to(:to_i)
      estimate.time.hour.should == 0
      estimate.time.min.should == 0
      estimate.created_at.should be_close(@milestone.start_on + i.days,1.hour + 1.second)
    end
    
  end
  
  it "should return the accurate estimates for each day" do
    
    ticket = @milestone.tickets.last
    
    ticket.estimates[0].to_i.should == 3.hours
    ticket.estimates[1].to_i.should == 3.hours
    ticket.estimates[2].to_i.should == 4.hours
    ticket.estimates[3].to_i.should == 3.hours
    ticket.estimates[4].to_i.should == 2.hours
    ticket.estimates[5].to_i.should == 0.hours
    
    ticket.estimate_for_day(@milestone.start_on + 0.days).to_i.should == 3.hours
    ticket.estimate_for_day(@milestone.start_on + 1.days).to_i.should == 3.hours
    ticket.estimate_for_day(@milestone.start_on + 2.days).to_i.should == 4.hours
    ticket.estimate_for_day(@milestone.start_on + 3.days).to_i.should == 3.hours
    ticket.estimate_for_day(@milestone.start_on + 4.days).to_i.should == 2.hours
    ticket.estimate_for_day(@milestone.start_on + 5.days).to_i.should == 0.hours
    
  end
  
  it "should grab the estimation from the ticket description" do
    
  end
end

describe Rome::Graph do
  
  before(:each) do
    mock_requests!
    @account = Rome::Account.new("soocial", token)
    @project = @account.projects.first
    @milestone = @project.current_milestone
  end
  
  it "should generate a Google Charts graph" do
    @graph_url = Rome::Graph.for_milestone(@milestone)
    puts "<img src=\"#{@graph_url}\">"
    # @graph.should be_an_instance_of(GoogleChart::LineChart)
    # lambda { URI.parse @graph.to_url }.should_not raise_error
    # puts "<img src=\"#{@graph.to_url(:chs => "500x400", :chtt => @milestone.title)}\">" 
  end
  
end