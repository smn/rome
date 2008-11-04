module Rome
  class Account
    
    attr_reader :name, :token
    
    def initialize(name, token)
      @name = name
      @token = token
    end
    
    def authenticate!
      Lighthouse.account = @name
      Lighthouse.token = @token
      yield
    end
    
    def authorized?
      authenticate! do
        Lighthouse::Project.find :all
        true
      end
    rescue ActiveResource::UnauthorizedAccess => e
      false
    end
    
    def projects
      authenticate! do
        Lighthouse::Project.find(:all).collect { |lhp| Rome::Project.new(self, lhp) }
      end
    end
  end
end