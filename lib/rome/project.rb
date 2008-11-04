module Rome
  class Project
    
    extend Rome::AuthenticationHelper
    
    delegate :id, :to => :@lh_project
    
    attr_accessor :account
    
    TICKET_QUERY = 'all'
    
    def initialize(account, lh_project)
      @account = account
      @lh_project = lh_project
    end
    
    def milestones
      @lh_project.milestones.collect { |lhm| Rome::Milestone.new(self, lhm) }
    end
    authenticate :milestones
    
    def tickets
      Lighthouse::Ticket.find_all_across_pages(:params => {
        :q => TICKET_QUERY, 
        :project_id => id
      }).collect { |lht| Rome::Ticket.new(self, lht) }
    end
    authenticate :tickets
    
    def tickets_with_estimates
      tickets.reject { |ticket| ticket.estimates.empty? }
    end
    
    def open_milestones
      milestones.select { |ms| ms.open_tickets_count > 0 }.sort_by { |ms| ms.due_on }
    end
    
    def current_milestone
      Rome::Milestone.new self, Lighthouse::Milestone.find(:one, :params => {:project_id => id }, :from => :current)
    end
    authenticate :current_milestone
    
    def previous_milestone
      milestone_before current_milestone
    end
    
    def milestone_before(milestone)
      milestones.select { |ms| ms.due_on < milestone.due_on }.last
    end
    
    def late_milestones
      open_milestones.select { |ms| ms.due_on < Time.now.utc }
    end
    
    def future_milestones
      open_milestones.select { |ms| ms.due_on > current_milestone.due_on }
    end
    
    # decorate
    def method_missing(method, *args)
      @lh_project.send(method, *args)
    end
  end
end