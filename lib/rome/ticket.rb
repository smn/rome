module Rome
  class Ticket
    
    extend Rome::AuthenticationHelper
    
    delegate :account, :to => :@project
    delegate :id, :to => :@lh_ticket
    
    ESTIMATE_TIMESTAMP_MATCHER = "%d-%m-%Y"
    
    def initialize(project, lh_ticket)
      @project = project
      
      # we need the versions attribute for this ticket, if we get the ticket info
      # from the projects /tickets.xml list we don't have the versions info 
      # and so we need do a manual reload since the versions info is only included
      # in the /tickets/<ID>.xml resources
      unless lh_ticket.attributes.include? "versions"
        @lh_ticket = account.authenticate! do 
          Lighthouse::Ticket.find lh_ticket.id, :params => {
            :project_id => @project.id
          }
        end
      else
        @lh_ticket = lh_ticket
      end
    end
    
    def versions
      @lh_ticket.versions
    end
    
    def estimates
      estimates = versions.collect { |version| Rome::Estimate.from_version(version) }
      estimates.compact.sort_by { |estimate| estimate.created_at }
    end
    
    def open?
      @project.open_states_list.include?(state)
    end
    
    def activity
      estimates.map(&:created_at)
    end
    
    def estimate_for_day(date)
      
      # if the last estimating activity is before the given date and the ticket has been closed
      # return zero as the estimate
      if (activity.last < date and not open?)
        # puts "returning zero for ##{id}:'#{title}' on #{date.strftime(ESTIMATE_TIMESTAMP_MATCHER)}"
        Estimate.new(Time.parse("00:00"), date)
      else
        days_estimates = estimates.select do |estimate| 
          estimate.created_at < (date.midnight + 1.day) # == coming night
        end
        # puts "found #{days_estimates.size} estimates for ##{id}:'#{title}' on #{date.strftime(ESTIMATE_TIMESTAMP_MATCHER)}"
        # puts "returning: #{days_estimates.last.inspect}"
        days_estimates.last
      end
    end
    
    def assigned_to
      @assigned_to ||= Lighthouse::User.find(assigned_user_id)
    end
    authenticate :assigned_to
    
    def method_missing(method, *args)
      @lh_ticket.send(method, *args)
    end
  end
end