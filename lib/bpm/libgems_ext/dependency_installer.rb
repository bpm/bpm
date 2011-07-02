require 'libgems/dependency_installer'

module LibGems
  class DependencyInstaller

    # Had to overwrite this all just to change the match from /gem$/ to /bpkg$/
    # TODO: Consider whether extension should be settable in LibGems
    def find_spec_by_name_and_version(gem_name,
                                      version = LibGems::Requirement.default,
                                      prerelease = false)
      spec_and_source = nil

      glob = if File::ALT_SEPARATOR then
               gem_name.gsub File::ALT_SEPARATOR, File::SEPARATOR
             else
               gem_name
             end

      local_gems = Dir["#{glob}*"].sort.reverse

      unless local_gems.empty? then
        local_gems.each do |gem_file|
          next unless gem_file =~ /bpkg$/
          begin
            spec = LibGems::Format.from_file_by_path(gem_file).spec
            spec_and_source = [spec, gem_file]
            break
          rescue SystemCallError, LibGems::Package::FormatError
          end
        end
      end

      if spec_and_source.nil? then
        dep = LibGems::Dependency.new gem_name, version
        dep.prerelease = true if prerelease
        spec_and_sources = find_gems_with_sources(dep).reverse

        spec_and_source = spec_and_sources.find { |spec, source|
          LibGems::Platform.match spec.platform
        }
      end

      if spec_and_source.nil? then
        raise LibGems::GemNotFoundException.new(
          "Could not find #{prerelease ? 'prerelease ' : ''}package '#{gem_name}' (#{version}) locally or in a repository",
          gem_name, version, @errors)
      end

      @specs_and_sources = [spec_and_source]
    end

    # Overwrite this to use our custom installer
    def install dep_or_name, version = LibGems::Requirement.default
      LibGems.with_rubygems_compat do
        if String === dep_or_name then
          find_spec_by_name_and_version dep_or_name, version, @prerelease
        else
          dep_or_name.prerelease = @prerelease
          @specs_and_sources = [find_gems_with_sources(dep_or_name).last]
        end

        @installed_gems = []

        gather_dependencies

        @gems_to_install.each do |spec|
          last = spec == @gems_to_install.last
          # HACK is this test for full_name acceptable?
          next if @source_index.any? { |n,_| n == spec.full_name } and not last

          # TODO: make this sorta_verbose so other users can benefit from it
          say "Installing bpkg #{spec.full_name}" if LibGems.configuration.really_verbose

          _, source_uri = @specs_and_sources.assoc spec
          begin
            local_gem_path = LibGems::RemoteFetcher.fetcher.download spec, source_uri,
                                                                 @cache_dir
          rescue LibGems::RemoteFetcher::FetchError
            next if @force
            raise
          end

          inst = LibGems::Installer.new local_gem_path,
                                    :bin_dir             => @bin_dir,
                                    :development         => @development,
                                    :env_shebang         => @env_shebang,
                                    :force               => @force,
                                    :format_executable   => @format_executable,
                                    :ignore_dependencies => @ignore_dependencies,
                                    :install_dir         => @install_dir,
                                    :security_policy     => @security_policy,
                                    :source_index        => @source_index,
                                    :user_install        => @user_install,
                                    :wrappers            => @wrappers

          spec = inst.install

          @installed_gems << spec
        end

        @installed_gems
      end
    end

    def find_gems_with_sources(dep)
      # Reset the errors
      @errors = nil
      gems_and_sources = []

      if @domain == :both or @domain == :local then
        Dir[File.join(Dir.pwd, "#{dep.name}-[0-9]*.bpkg")].each do |gem_file|
          spec = LibGems::Format.from_file_by_path(gem_file).spec
          gems_and_sources << [spec, gem_file] if spec.name == dep.name
        end
      end

      if @domain == :both or @domain == :remote then
        begin
          requirements = dep.requirement.requirements.map do |req, ver|
            req
          end

          all = !dep.prerelease? &&
                # we only need latest if there's one requirement and it is
                # guaranteed to match the newest specs
                (requirements.length > 1 or
                  (requirements.first != ">=" and requirements.first != ">"))

          found, @errors = LibGems::SpecFetcher.fetcher.fetch_with_errors dep, all, true, dep.prerelease?

          gems_and_sources.push(*found)

        rescue LibGems::RemoteFetcher::FetchError => e
          if LibGems.configuration.really_verbose then
            say "Error fetching remote data:\t\t#{e.message}"
            say "Falling back to local-only install"
          end
          @domain = :local
        end
      end

      gems_and_sources.sort_by do |gem, source|
        [gem, source =~ /^http:\/\// ? 0 : 1] # local gems win
      end
    end

  end
end


