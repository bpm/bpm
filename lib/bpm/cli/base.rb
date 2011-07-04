require 'thor'

module BPM
  module CLI
    LOGIN_MESSAGE = "Please login first with `bpm login`."

    class Base < Thor

      class_option :verbose, :type => :boolean, :default => false,
        :aliases => ['-V'],
        :desc => 'Show additional debug information while running'

      desc "owner", "Manage users for a package"
      subcommand "owner", BPM::CLI::Owner

      desc "fetch [PACKAGE]", "Fetch one or many bpm packages to local cache"
      method_option :version,    :type => :string,  :default => ">= 0", :aliases => ['-v'],    :desc => 'Specify a version to install'
      method_option :prerelease, :type => :boolean, :default => false,  :aliases => ['--pre'], :desc => 'Install a prerelease version'
      def fetch(*packages)
        project = BPM::Project.nearest_project(Dir.pwd) if packages.empty?
        if project
          success = project.fetch_dependencies options[:verbose]
          if !success
            abort project.errors * "\n"
          else
            say "Fetched dependent packages for #{project.name}"
          end

        else
          report_arity_error("fetch") and return if packages.size.zero?

          begin
            packages.each do |package|
              installed = BPM::Remote.new.install(package, options[:version], options[:prerelease])
              installed.each do |spec|
                say "Successfully fetched #{spec.name} (#{spec.version})"
              end
            end
          rescue LibGems::InstallError => e
            abort "Fetch error: #{e}"
          rescue LibGems::GemNotFoundException => e
            abort "Can't find package #{e.name} #{e.version} available for fetch"
          rescue Errno::EACCES, LibGems::FilePermissionError => e
            abort e.message
          end
        end
      end


      desc "fetched [PACKAGE]", "Shows what bpm packages are fetched"
      def fetched(*packages)
        local = BPM::Local.new
        index = local.installed(packages)
        print_specs(packages, index)
      end

      desc "add [PACKAGE]", "Add package to project"
      method_option :version,    :type => :string,  :default => nil, :aliases => ['-v'],    :desc => 'Specify a version to install'
      method_option :project,    :type => :string,  :default => nil, :aliases => ['-p'],    :desc => 'Specify project location other than working directory'
      method_option :prerelease, :type => :boolean, :default => false,  :aliases => ['--pre'], :desc => 'Install a prerelease version'
      def add(*package_names)
        # map to dependencies
        if package_names.empty?
          abort "You must specify at least one package"
        else
          if package_names.size > 1 && options[:version]
            abort "You can only name one package with the version option"
          end

          deps = {}
          package_names.each do |name|
            vers = options[:version] || (options[:prerelease] ? '>= 0-pre' : '>= 0')
            if name =~ /^(.+?)(-(\d[\w\.]*))?\.bpkg$/
              name = $1
              vers = $3 if $3
            end
            deps[name] = vers
          end
        end

        # find project
        project = find_project

        begin
          project.add_dependencies deps, true
          project.build :debug, true
        rescue Exception => e
          abort e.message
        end
      end

      desc "remove [PACKAGE]", "Remove package from project"
      method_option :project,    :type => :string,  :default => nil, :aliases => ['-p'],    :desc => 'Specify project location other than working directory'
      def remove(*package_names)

        # map to dependencies
        if package_names.size.zero?
          abort "You must specify at least one package"
        end

        begin
          project = find_project
          project.unbuild options[:verbose]
          project.remove_dependencies package_names, true
          project.build :debug, true
          
        rescue Exception => e
          abort e.message
        end
      end

      desc "autocompile", "Preview server that will autocompile assets.  Useful for hacking"
      method_option :mode, :type => :string, :default => :debug, :aliases => ['-m'], :desc => 'Set build mode for compile (default debug)'
      method_option :project,    :type => :string,  :default => nil, :aliases => ['-p'],    :desc => 'Specify project location other than working directory'
      method_option :port,       :type => :string,  :default => '4020', :desc => "Port to host server on"
      def autocompile
        
        project = find_project
        puts project
        BPM::Server.start project, :Port => options[:port]
        
      end
      
      desc "compile", "Build the bpm_package.js for development"
      method_option :mode, :type => :string, :default => :debug, :aliases => ['-m'], :desc => 'Set build mode for compile (default debug)'
      method_option :project,    :type => :string,  :default => nil, :aliases => ['-p'],    :desc => 'Specify project location other than working directory'
      def compile
        
        begin
          project = find_project
          project.rebuild_dependencies nil, options[:verbose]
          project.build options[:mode], options[:verbose]
        rescue Exception => e
          abort e.message
        end
      end
      
      desc "login", "Log in with your BPM credentials"
      method_option :username,  :type => :string,  :default => nil, :aliases => ['-u'], :desc => 'Specify the username to login as'
      method_option :password,  :type => :string,  :default => nil, :aliases => ['-p'], :desc => 'Specify the login password'
      def login
        email = options[:username]
        password = options[:password]

        unless email && password
          require 'highline'
          highline = HighLine.new
          say "Enter your BPM credentials."

          begin
            email ||= highline.ask "\nEmail:" do |q|
              next unless STDIN.tty?
              q.readline = true
            end

            password ||= highline.ask "\nPassword:" do |q|
              next unless STDIN.tty?
              q.echo = "*"
            end
          rescue Interrupt => ex
            abort "Cancelled login."
          end
        end

        say "\nLogging in as #{email}..."

        if BPM::Remote.new.login(email, password)
          say "Logged in!"
        else
          say "Incorrect email or password."
          login unless options[:username] && options[:password]
        end
      end

      desc "push", "Distribute your bpm package"
      def push(package)
        remote = BPM::Remote.new
        if remote.logged_in?
          say remote.push(package)
        else
          say LOGIN_MESSAGE
        end
      end

      desc "yank", "Remove a specific package version release from SproutCutter"
      method_option :version, :type => :string,  :default => nil,   :aliases => ['-v'],    :desc => 'Specify a version to yank'
      method_option :undo,    :type => :boolean, :default => false,                        :desc => 'Unyank package'
      def yank(package)
        if options[:version]
          remote = BPM::Remote.new
          if remote.logged_in?
            if options[:undo]
              say remote.unyank(package, options[:version])
            else
              say remote.yank(package, options[:version])
            end
          else
            say LOGIN_MESSAGE
          end
        else
          say "Version required"
        end
      end

      desc "list", "View available packages for download"
      method_option :all,        :type => :boolean, :default => false, :aliases => ['-a'],    :desc => 'List all versions available'
      method_option :prerelease, :type => :boolean, :default => false, :aliases => ['--pre'], :desc => 'List prerelease versions available'
      def list(*packages)
        remote = BPM::Remote.new
        index  = remote.list_packages(packages, options[:all], options[:prerelease])
        print_specs(packages, index)
      end

      desc "new [NAME]", "Generate a new project skeleton"
      method_option :path, :type => :string, :default => nil, :desc => 'Specify a different name for the project'
      method_option :package, :type => :string, :default => nil, :desc => 'Specify a package template to build from'
      def new(name)
        package = install_package(options[:package])
        template_path = package ? package.template_path(:project) : nil

        path = File.expand_path(options[:path] || underscore(name))
        generator = get_generator(:project, package)
        success = generator.new(self, name, path, template_path, package).run

        run_init(name, path, package) if success
      end

      desc "init [PATHS]", "Configure a project to use bpm for management"
      method_option :name, :type => :string, :default => nil, :desc => 'Specify a different name for the project'
      method_option :skip, :type => :boolean, :default => false, :desc => 'Skip any conflicting files'
      def init(*paths)
        paths = [Dir.pwd] if paths.empty?
        paths.map!{|p| File.expand_path(p) }

        if paths.length > 1 && options[:name]
          abort "Can't specify a name with multiple paths"
        end

        paths.each do |path|
          run_init(options[:name] || File.basename(path), path)
        end
      end

      desc "build [PACKAGE]", "Build a bpm package from a package.json"
      method_option :email, :type => :string,  :default => nil,   :aliases => ['-e'],    :desc => 'Specify an author email address'
      def build(package_path=nil)
        package_path ||= Dir.pwd
        local = BPM::Local.new
        package = local.pack(File.join(package_path, "package.json"), options[:email])

        if package.errors.empty?
          puts "Successfully built package: #{package.to_ext}"
        else
          failure_message = "BPM encountered the following problems building your package:"
          package.errors.each do |error|
            failure_message << "\n* #{error}"
          end
          abort failure_message
        end
      end

      desc "unpack [PACKAGE]", "Extract files from a bpm package"
      method_option :target, :type => :string, :default => ".", :aliases => ['-t'], :desc => 'Unpack to given directory'
      def unpack(*paths)
        local = BPM::Local.new

        paths.each do |path|
          begin
            package     = local.unpack(path, options[:target])
            unpack_path = File.expand_path(File.join(Dir.pwd, options[:target], package.to_full_name))
            puts "Unpacked package into: #{unpack_path}"
          rescue Errno::EACCES, LibGems::FilePermissionError => ex
            abort "There was a problem unpacking #{path}:\n#{ex.message}"
          end
        end
      end

      private

        def get_generator(type, package=nil)
          require 'bpm/generator'
          generator_pkg = package ? package.name : :default
          package ? package.generator_for(type) : BPM.generator_for(type)
        end

        def run_init(name, path, package=nil)
          template_path = package ? package.template_path(:init) : nil

          generator = get_generator(:init, package)
          generator.new(self, name, path, template_path, package).run

          project = BPM::Project.new(path, name)
          project.fetch_dependencies true
          project.build :debug, true
        end

        def report_arity_error(name)
          self.class.handle_argument_error(self.class.tasks[name], nil)
        end

        def find_project
          if options[:project]
            project_path = File.expand_path options[:project]
            if BPM::Project.is_project_root? project_path
              abort "#{project_path} does not appear to be managed by bpm"
            else
              project = BPM::Project.new project_path
            end
          else
            project = BPM::Project.nearest_project Dir.pwd
            if project.nil?
              abort "You do not appear to be inside of a bpm project"
            end
          end
          
          project
        end
        
        def print_specs(names, index)
          packages = {}

          index.each do |(name, version, platform)|
            packages[name] ||= []
            packages[name] << version
          end

          if packages.size.zero?
            abort %{No packages found matching "#{names.join('", "')}".}
          else
            packages.each do |name, versions|
              puts "#{name} (#{versions.sort.reverse.join(", ")})"
            end
          end
        end

        def install_package(pkg_name)
          return nil unless pkg_name
          begin
            # Try remote first to get the latest versions
            installed = BPM::Remote.new.install(pkg_name, ">= 0", false)
          rescue LibGems::GemNotFoundException
            dep = LibGems::Dependency.new(pkg_name)
            installed = LibGems.source_index.search(dep)
          end
          spec = installed.find{|p| p.name == pkg_name }
          abort "Unable to find package: #{pkg_name}" unless spec
          BPM::Package.from_spec(spec)
        end

        def underscore(str)
          str.gsub(/::/, '/').
            gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
            gsub(/([a-z\d])([A-Z])/,'\1_\2').
            tr("-", "_").
            downcase
        end

    end
  end
end
