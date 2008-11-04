module Rome
  class Milestone
    
    extend Rome::AuthenticationHelper
    
    attr_accessor :project
    
    delegate :account, :to => :@project
    delegate :id, :to => :@lh_milestone
    
    MILESTONE_QUERY = "milestone:'%s'"
    START_ON_PATTERN = /#start\s*(\d{2}-\d{2}-\d{4})/i
    
    def initialize(project, lh_milestone)
      @project = project
      @lh_milestone = lh_milestone
    end
    
    def ==(other)
      id == other.id
    end
    
    def start_on
      if goals =~ START_ON_PATTERN
        DateTime.parse($1).utc.to_time.midnight
      else
        created_at.midnight
      end
    end
    
    def get_tickets_from_lighthouse
      params = { 
        :project_id => @project.id, 
        :q => MILESTONE_QUERY % @lh_milestone.title
      }
      lh_tickets = Lighthouse::Ticket.find_all_across_pages(:params => params).collect do |lht| 
        Rome::Ticket.new(@project, lht)
      end
      
      lh_tickets.compact
    end
    
    def tickets(options={})
      @tickets ||= get_tickets_from_lighthouse
      
      unless options.blank?
        @tickets.select do |ticket|
          options.all? { |key,value| ticket.send(key) == value }
        end
      else
        @tickets
      end
    end
    authenticate :tickets
    
    def tickets_with_estimates(options = {})
      tickets(options).reject { |ticket| ticket.estimates.empty? }
    end
    
    def tickets_without_estimates(options={})
      tickets(options).select { |ticket| ticket.estimates.empty? }
    end
    
    def members
      tickets.map(&:assigned_to).uniq
    end
    
    # the duration is not really accurate since we don't have a technical start 
    # date of a milestone
    def duration
      due_on - start_on
    end
    
    # redefine due_on to be midnight the next day
    def due_on
      @lh_milestone.due_on + 1.day
    end
    
    # probably should move to the ticket model
    def time_total(options={})
      time_remaining_on_day(start_on, options)
    end
    
    def time_remaining(options={})
      tickets_with_estimates(options).inject(0) { |total, ticket| total += ticket.estimates.last.to_i }
    end
    
    def time_remaining_on_day(day, options = {})
      tickets_with_estimates(options).inject(0) { |total, ticket| total += ticket.estimate_for_day(day).to_i }
    end
    
    def method_missing(method, *args)
      @lh_milestone.send(method, *args)
    end
  end
end

  