module Rome
  module AuthenticationHelper
    
    # NOTE: this is a workaround for ActiveResource's weird ass authentication
    #       mechanism that stores the credentials in class variables
    #       It proxies all calls to methods that need authentication to go 
    #       through account.authenticate! everytime it is called to make sure 
    #       the class variable is set properly
    def authenticate(name)
      original = "#{name}_without_authentication"
      klass = ([Class, Module].include?(self.class) ? self : self.class)
      klass.class_eval do
        alias_method original, name
        private      original
        define_method(name) do |*args|
          account.authenticate! { send(original, *args) }
        end
      end
    end
  end
end