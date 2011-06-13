require 'thor'
require 'highline'

module Spade
  module Packager
    module CLI
      LOGIN_MESSAGE = "Please login first with `spade login`."

      class Base < Thor

        class_option :verbose, :type => :boolean, :default => false,
          :aliases => ['-V'],
          :desc => 'Show additional debug information while running'

        desc "owner", "Manage users for a package"
        subcommand "owner", Spade::Packager::CLI::Owner

        desc "install [PACKAGE]", "Installs one or many spade packages"
        method_option :version,    :type => :string,  :default => ">= 0", :aliases => ['-v'],    :desc => 'Specify a version to install'
        method_option :prerelease, :type => :boolean, :default => false,  :aliases => ['--pre'], :desc => 'Install a prerelease version'
        def install(*packages)
          report_arity_error("install") and return if packages.size.zero?

          begin
            packages.each do |package|
              installed = Spade::Packager::Remote.new.install(package, options[:version], options[:prerelease])
              installed.each do |spec|
                say "Successfully installed #{spec.full_name}"
              end
            end
          rescue LibGems::InstallError => e
            abort "Install error: #{e}"
          rescue LibGems::GemNotFoundException => e
            abort "Can't find package #{e.name} #{e.version} available for install"
          rescue Errno::EACCES, LibGems::FilePermissionError => e
            abort e.message
          end
        end

        desc "installed [PACKAGE]", "Shows what spade packages are installed"
        def installed(*packages)
          local = Spade::Packager::Local.new
          index = local.installed(packages)
          print_specs(packages, index)
        end

        desc "uninstall [PACKAGE]", "Uninstalls one or many packages"
        def uninstall(*packages)
          local = Spade::Packager::Local.new
          if packages.size > 0
            packages.each do |package|
              if !local.uninstall(package)
                abort %{No packages installed named "#{package}"}
              end
            end
          else
            report_arity_error('uninstall')
          end
        end

        desc "login", "Log in with your Spade credentials"
        def login
          highline = HighLine.new
          say "Enter your Spade credentials."

          begin
            email = highline.ask "\nEmail:" do |q|
              next unless STDIN.tty?
              q.readline = true
            end

            password = highline.ask "\nPassword:" do |q|
              next unless STDIN.tty?
              q.echo = "*"
            end
          rescue Interrupt => ex
            abort "Cancelled login."
          end

          say "\nLogging in as #{email}..."

          if Spade::Packager::Remote.new.login(email, password)
            say "Logged in!"
          else
            say "Incorrect email or password."
            login
          end
        end

        desc "push", "Distribute your spade package"
        def push(package)
          remote = Spade::Packager::Remote.new
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
            remote = Spade::Packager::Remote.new
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
          remote = Spade::Packager::Remote.new
          index  = remote.list_packages(packages, options[:all], options[:prerelease])
          print_specs(packages, index)
        end

        desc "new [NAME]", "Generate a new project skeleton"
        def new(name)
          ProjectGenerator.new(self,
            name, File.expand_path(name)).run
        end

        desc "build", "Build a spade package from a package.json"
        def build
          local = Spade::Packager::Local.new
          if local.logged_in?
            package = local.pack("package.json")
            if package.errors.empty?
              puts "Successfully built package: #{package.to_ext}"
            else
              failure_message = "Spade encountered the following problems building your package:"
              package.errors.each do |error|
                failure_message << "\n* #{error}"
              end
              abort failure_message
            end
          else
            abort LOGIN_MESSAGE
          end
        end

        desc "unpack [PACKAGE]", "Extract files from a spade package"
        method_option :target, :type => :string, :default => ".", :aliases => ['-t'], :desc => 'Unpack to given directory'
        def unpack(*paths)
          local = Spade::Packager::Local.new

          paths.each do |path|
            begin
              package     = local.unpack(path, options[:target])
              unpack_path = File.expand_path(File.join(Dir.pwd, options[:target], package.to_full_name))
              puts "Unpacked spade into: #{unpack_path}"
            rescue Errno::EACCES, LibGems::FilePermissionError => ex
              abort "There was a problem unpacking #{path}:\n#{ex.message}"
            end
          end
        end

        private

          def report_arity_error(name)
            self.class.handle_argument_error(self.class.tasks[name], nil)
          end

          def print_specs(packages, index)
            spades = {}

            index.each do |(name, version, platform)|
              spades[name] ||= []
              spades[name] << version
            end

            if spades.size.zero?
              abort %{No packages found matching "#{packages.join('", "')}".}
            else
              spades.each do |name, versions|
                puts "#{name} (#{versions.sort.reverse.join(", ")})"
              end
            end
          end

      end
    end
  end
end
