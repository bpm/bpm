module BPM
  class Credentials
    attr_reader :email, :api_key

    def initialize
      parse
    end

    def save(email, api_key)
      @email   = email
      @api_key = api_key
      write
    end

    private

    def write
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, "w") do |file|
        file.write YAML.dump(:bpm_api_key => api_key, :bpm_email => email)
      end
    end

    def path
      LibGems.configuration.credentials_path
    end

    def parse
      if File.exist?(path)
        hash     = YAML.load_file(path)
        @email   = hash[:bpm_email]
        @api_key = hash[:bpm_api_key]
      end
    end
  end
end
