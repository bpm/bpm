module Spade::Packager
  class Repository
    attr_accessor :creds

    def initialize
      self.creds = Credentials.new
    end

    def logged_in?
      !self.creds.api_key.nil?
    end

    def dependency_for(packages)
      LibGems::Dependency.new(/(#{packages.join('|')})/, LibGems::Requirement.default)
    end
  end
end

