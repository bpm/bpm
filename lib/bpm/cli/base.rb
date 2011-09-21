require 'thor'
require 'json'
require 'bpm/version'

module BPM
  module CLI
    LOGIN_MESSAGE = "Please login first with `bpm login`."

    class Base < Thor

      class_option :verbose, :type => :boolean, :default => false,
        :aliases => ['-V'],
        :desc => 'Show additional debug information while running'

      class << self

        def help(shell, subcommand = false)
          shell.say <<LONGDESC
bpm (v#{BPM::VERSION}) - the browser package manager

BPM is a tool for aiding in development of JavaScript-based web applications.
It manages dependencies, custom file formats, minification and more.

Sample Usage:

  bpm init my_app
  cd my_app
  bpm add my_dependency
  bpm preview

LONGDESC

          super shell, subcommand
        end

        # Hacked so long description isn't wrapped
        def task_help(shell, task_name)
          meth = normalize_task_name(task_name)
          task = all_tasks[meth]
          handle_no_task_error(meth) unless task

          shell.say "Usage:"
          shell.say "  #{banner(task)}"
          shell.say
          class_options_help(shell, nil => task.options.map { |_, o| o })
          if task.long_description
            shell.say "Description:"
            shell.print_wrapped(task.long_description, :ident => 2)
          else
            shell.say task.description
          end
        end

        def start(given_args=ARGV, config={})
          if given_args.include?('--verbose') || given_args.include?('-V')
            BPM.show_deprecations = true
          end

          super

          if BPM.deprecation_count > 0
            puts "[WARN] #{BPM.deprecation_count} deprecation warnings were hidden. Run with --verbose to see them."
          end
        end
      end

      def help(*args)
        if args.first == "owner"
          CLI::Owner.start( [ "help" ] + args[1..-1] )
        else
          super
        end
      end

      desc "owner", "Manage users for a package"
      subcommand "owner", BPM::CLI::Owner

      desc "fetch [PACKAGE]", "Fetch one or many bpm packages to local cache"
      long_desc <<-LONGDESC
        Fetch one or many bpm packages to local cache.

        If no packages are specified, BPM will use the current project.

        Note: This command is used internally and should not normally need to be called directly.
      LONGDESC
      method_option :version,    :type => :string,  :default => ">= 0", :aliases => ['-v'],    :desc => 'Specify a version to install'
      method_option :prerelease, :type => :boolean, :default => false,  :aliases => ['--pre'], :desc => 'Install a prerelease version'
      method_option :project,    :type => :string,  :default => nil,    :aliases => ['-p'],    :desc => 'Specify project location other than working directory'
      method_option :package,    :type => :boolean, :default => false,  :desc => "Fetch for a package, instead of a project"
      def fetch(*packages)
        project = find_project(false) if packages.empty?
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
            raise BPM::Error.new("Fetch error: #{e}")
          rescue LibGems::GemNotFoundException => e
            abort "Can't find package #{e.name} #{e.version} available for fetch"
          rescue Errno::EACCES, LibGems::FilePermissionError => e
            raise BPM::Error.new(e.message)
          end
        end
      end


      desc "fetched [PACKAGE]", "Displays a list of locally cached BPM packages"
      def fetched(*packages)
        local = BPM::Local.new
        index = local.installed(packages)
        print_specs(packages, index)
      end

      desc "add [PACKAGE]", "Add one or more dependencies to a bpm project"
      long_desc <<-LONGDESC
        Adds one or more dependencies to a bpm project.

        It first fetches the dependency from getbpm.org (or uses the locally vendored version)
        and then adds it to your project's JSON config.

        If multiple package names are passed they will all be added.

        Run with --pre to install a prerelease version of your package.

        Run with --version to specify a specific package version other than
        the most recent.

        To remove a dependency just run `bpm remove`.
      LONGDESC
      method_option :version,     :type => :string,  :default => nil,   :aliases => ['-v'],    :desc => 'Specify a version to install'
      method_option :project,     :type => :string,  :default => nil,   :aliases => ['-p'],    :desc => 'Specify project location other than working directory'
      method_option :prerelease,  :type => :boolean, :default => false, :aliases => ['--pre'], :desc => 'Install a prerelease version'
      method_option :development, :type => :boolean, :default => false, :aliases => ['--dev'], :desc => "Add as a development dependency"
      method_option :mode,        :type => :string,  :default => :production, :aliases => ['-m'], :desc => "Build mode for compile"
      method_option :package,     :type => :boolean, :default => false, :desc => "Add to a package, instead of a project"
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
            vers = options[:version] || (options[:prerelease] ? '>= 0.pre' : '>= 0')
            if name =~ /^(.+?)(-(\d[\w\.]*))?\.bpkg$/
              name = $1
              vers = $3 if $3
            end
            deps[name] = vers
          end
        end

        # find project
        project = find_project

        project.add_dependencies deps, options[:development], true
        project.build options[:mode], true
      end

      desc "remove [PACKAGE]", "Remove one or more dependencies from a BPM project"
      long_desc <<-LONGDESC
        Remove one or more dependencies from a BPM project.

        This command will remove the dependency declaration from the project JSON.
        It will then rebuild the project without the depedency.
      LONGDESC
      method_option :project, :type => :string,  :default => nil,         :aliases => ['-p'], :desc => 'Specify project location other than working directory'
      method_option :mode,    :type => :string,  :default => :production, :aliases => ['-m'], :desc => "Build mode for compile"
      method_option :package, :type => :boolean, :default => false,       :desc => "Remove from a package, instead of a project"
      def remove(*package_names)

        # map to dependencies
        if package_names.size.zero?
          abort "You must specify at least one package"
        end

        project = find_project
        project.unbuild options[:verbose]
        project.remove_dependencies package_names, true
        project.build options[:mode], true
      end

      desc "preview", "Preview server that autocompiles assets as they are requested"
      long_desc <<-LONGDESC
        Preview server that autocompiles assets as they are requested.

        The primary use of `bpm preview` is that it is faster to use that `bpm rebuild`.
        When developing with the preview server changes to your code are automatically
        recognized and will be present when the page is reloaded.

        Once you are satisfied with your project you will still need to run `bpm rebuild`
        to save your updated assets to disk.
      LONGDESC
      method_option :mode,    :type => :string,  :default => :debug, :aliases => ['-m'], :desc => 'Build mode for compile'
      method_option :project, :type => :string,  :default => nil,    :aliases => ['-p'],    :desc => 'Specify project location other than working directory'
      method_option :port,    :type => :string,  :default => '4020', :desc => "Port to host server on"
      method_option :package, :type => :boolean, :default => false,  :desc => "Preview a package, instead of a project"
      def preview
        project = find_project
        project.verify_and_repair options[:mode], options[:verbose]
        BPM::Server.start project, :Port => options[:port], :mode => options[:mode].to_sym
      end

      desc "rebuild", "Rebuilds BPM assets"
      long_desc <<-LONGDESC
        Rebuilds BPM assets

        `bpm rebuild` will rebuild all assets managed by BPM as declared in your project's
        JSON config. This should always be run before deploying to the server. During active
        development, consider using `bpm preview`. Though remember that you will have to run
        `bpm rebuild` before deploying.
      LONGDESC
      method_option :mode,    :type => :string, :default => :production, :aliases => ['-m'], :desc => 'Build mode for compile'
      method_option :project, :type => :string,  :default => nil, :aliases => ['-p'],    :desc => 'Specify project location other than working directory'
      method_option :update,  :type => :boolean, :default => false, :aliases => ['-u'], :desc => 'Updates dependencies to latest compatible version'
      method_option :package, :type => :boolean, :default => false, :desc => "Rebuild package, instead of a project"
      def rebuild
        find_project.fetch_dependencies(true) if options[:update]
        find_project.build options[:mode].to_sym, true
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

      desc "push PACKAGE", "Distribute your BPM package on GetBPM.org"
      long_desc <<-LONGDESC
        Distribute your BPM package on GetBPM.org

        Pushes your package to GetBPM.org. You will need to run
        `bpm pack` before you can run this command. You will also need
        an account on GetBPM.org.
      LONGDESC
      def push(package)
        remote = BPM::Remote.new
        if remote.logged_in?
          say remote.push(package)
        else
          say LOGIN_MESSAGE
        end
      end

      desc "yank PACKAGE", "Remove a specific package version release from GetBPM.org"
      long_desc <<-LONGDESC
        Remove a specific package version release from GetBPM.org

        This is useful if you have pushed a version in error or have discovered a serious bug.
        Beware, however, that you cannot repush a version number. When you yank a package that
        version number still remains active in the event that other pacakges depend on it. If
        you need a package gone for good, please contact BPM support.
      LONGDESC
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

      desc "list", "List BPM Packages"
      long_desc <<-LONGDESC
        List BPM Packages

        By default this provides a list of all dependencies of the current project.

        To see a list of all available BPM packages, run with --remote. Add --all to
        see all possible (non-prerelease) versions and --pre to see prerelease versions.
      LONGDESC
      method_option :remote,     :type => :boolean, :default => false, :aliases => ['-r'],
                                    :desc => 'List packages on remote server'
      method_option :all,        :type => :boolean, :default => false, :aliases => ['-a'],
                                    :desc => 'List all (non-prerelease) versions available (remote only)'
      method_option :prerelease, :type => :boolean, :default => false, :aliases => ['--pre'],
                                    :desc => 'List prerelease versions available (remote only)'
      method_option :development, :type => :boolean, :default => false, :aliases => ['--dev'],
                                    :desc => 'List development dependencies instead of runtime (local only)'
      method_option :package,     :type => :boolean, :default => false,
                                    :desc => "List for a package, instead of a project"
      def list(*packages)
        if options[:remote]
          remote = BPM::Remote.new
          index  = remote.list_packages(packages, options[:all], options[:prerelease])
          print_specs(packages, index)
        else
          packages = nil if packages.size == 0
          project  = find_project
          project.verify_and_repair

          deps = options[:development] ? project.sorted_development_deps : project.sorted_runtime_deps
          deps.each do |dep|
            next if packages && !packages.include?(dep.name)
            say "#{dep.name} (#{dep.version})"
          end
        end
      end

      desc "init [PATHS]", "Configure a project to use BPM for management"
      long_desc <<-LONGDESC
        Configure a project to use BPM for management

        If the specified path does not exist it will be created with a basic BPM directory
        structure. For existing directories, BPM does not create the full directory structure,
        assuming that the current structure is adequate. In the event that you do want BPM to
        create its full structure, pass --app.

        By default, the app is given the same name as the directory it resides
        in. If a different name is desired, pass the --name option.
      LONGDESC
      method_option :name, :type => :string, :default => nil,    :desc => 'Specify a different name for the project'
      method_option :skip, :type => :boolean, :default => false, :desc => 'Skip any conflicting files'
      method_option :app,  :type => :boolean, :default => false, :desc => 'Manage app files as well as packages. (Always true for new directories.)'
      #method_option :package, :type => :string, :default => nil, :desc => 'Specify a package template to build from'
      def init(*paths)
        paths = [Dir.pwd] if paths.empty?
        paths.map!{|p| File.expand_path(p) }

        if paths.length > 1 && options[:name]
          abort "Can't specify a name with multiple paths"
        end

        paths.each do |path|
          name = options[:name] || File.basename(path)

          # if someone specified both a name and path assume they meant
          # exactly what they said
          if name == File.basename(path)
            new_path = File.join(File.dirname(path), File.basename(path))
            path = new_path if !File.directory?(path)
          end

          if File.directory?(path)
            run_init(name, options[:app], path)
          else
            #package = install_package(options[:package])
            package = nil
            template_path = package ? package.template_path(:project) : nil
            generator = get_generator(:project, package)
            success = generator.new(self, name, path, template_path, package).run
            run_init(name, true, path, package) if success
          end
        end
      end

      desc "pack [PACKAGE]", "Build a BPM package from a package.json"
      long_desc <<-LONGDESC
        Build a BPM package from a package.json

        This provides a .bpkg file that can be distributed directly or via GetBPM.org.
        If distributed directly, the package can be installed with `bpm add PACKAGE.bpkg`.
        If using GetBPM.org, run `bpm push PACKAGE.bpkg` and it can then be installed
        via a normal `bpm add NAME`.
      LONGDESC
      method_option :email, :type => :string,  :default => nil,   :aliases => ['-e'],    :desc => 'Specify an author email address'
      def pack(package_path=nil)
        package_path ||= Dir.pwd
        local = BPM::Local.new
        package = local.pack(File.join(package_path, "package.json"), options[:email])

        if package.errors.empty?
          say "Successfully built package: #{package.file_name}"
        else
          failure_message = "BPM encountered the following problems building your package:"
          package.errors.each do |error|
            failure_message << "\n* #{error}"
          end
          abort failure_message
        end
      end

      desc "unpack [PACKAGE]", "Extract files from a BPM package"
      long_desc <<-LONGDESC
        Extract files from a BPM package

        This is primarily useful for testing. If, for instance, a package
        is not behaving as expected, it may be useful to unpack it to review
        the contents.
      LONGDESC
      method_option :target, :type => :string, :default => ".", :aliases => ['-t'], :desc => 'Unpack to given directory'
      def unpack(*paths)
        local = BPM::Local.new

        paths.each do |path|
          begin
            package     = local.unpack(path, options[:target])
            unpack_path = File.expand_path(File.join(Dir.pwd, options[:target], package.full_name))
            say "Unpacked package into: #{unpack_path}"
          rescue Errno::EACCES, LibGems::FilePermissionError => ex
            abort "There was a problem unpacking #{path}:\n#{ex.message}"
          end
        end
      end

      desc "debug [OPTION]", "Display various options for debugging"
      long_desc <<-LONGDESC
        Display various options for debugging.

        * build - Shows all project build settings

        * repair - Verify and repair project
      LONGDESC
      method_option :project, :type => :string,  :default => nil, :aliases => ['-p'], :desc => 'Specify project location other than working directory'
      method_option :mode, :type => :string, :default => :debug, :aliases => ['-m'], :desc => 'Build mode'
      def debug(option)
        case option
        when 'build'
          say JSON.pretty_generate find_project.build_settings(options[:mode].to_sym)
        when 'repair'
          say "Verifying and repairing project..."
          find_project.verify_and_repair options[:mode].to_sym, true
        else
          abort "Do not know how to display #{option}"
        end
      end

      private

        def get_generator(type, package=nil)
          require 'bpm/generator'
          generator_pkg = package ? package.name : :default
          package ? package.generator_for(type) : BPM.generator_for(type)
        end

        def run_init(name, include_app, path, package=nil)

          # we only need to create a new project.json if one does not
          # already exist.
          unless BPM::Project.is_project_root? path
            template_path = package ? package.template_path(:init) : nil

            generator = get_generator(:init, package)
            generator.new(self, name, path, template_path, package).run
          end

          # make sure the project app status matches
          project = BPM::Project.new path

          if project.build_app? != !!include_app
            project.build_app = include_app
            project.save!
          end

          project.build :production, true

          if package
            deps = {}
            deps[package.name] = package.version
            project.add_dependencies deps, false, true
          end

        end

        def report_arity_error(name)
          self.class.handle_argument_error(self.class.tasks[name], nil)
        end

        def find_project(required=true)
          klass = options[:package] ? BPM::PackageProject : BPM::Project
          if options[:project]
            project_path = File.expand_path options[:project]
            if required && !klass.is_project_root?(project_path)
              abort "#{project_path} does not appear to be managed by BPM"
            else
              project = klass.new project_path
            end
          else
            project = klass.nearest_project Dir.pwd
            if required && project.nil?
              abort "You do not appear to be inside of a BPM project"
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
              say "#{name} (#{versions.sort.reverse.join(", ")})"
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

    end
  end
end
