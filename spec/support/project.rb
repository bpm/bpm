  module SpecHelpers
  
  def validate_dependency_in_project_file(package_name, package_version, development=false)
    json = JSON.parse File.read(home('hello_world', 'hello_world.json'))
    key = development ? "dependencies:development" : "dependencies"
    json[key][package_name].should == package_version
  end

  def validate_installed_dependency(package_name, package_version)
    bpm_libs = home 'hello_world', 'assets', 'bpm_libs.js'
    bpm_styles   = home 'hello_world', 'assets', 'bpm_styles.css'
    version_regexp = package_version ? Regexp.escape(package_version) : ".+?"
    exp_str = /#{package_name} \(#{version_regexp}\)/

    if package_version
      File.exists?(bpm_libs).should be_true
      File.exists?(bpm_styles).should be_true
      bpm_libs = File.readlines(bpm_libs)[0..6].join("")
      bpm_styles = File.readlines(bpm_styles)[0..6].join("")
    else
      if !File.exists?(bpm_libs)
        File.exists?(bpm_libs).should_not be_true
        bpm_libs = nil
      else
        bpm_libs = File.readlines(bpm_libs)[0..6].join("")
      end

      if !File.exists?(bpm_styles)
        File.exists?(bpm_styles).should_not be_true
        bpm_styles = nil
      else
        bpm_styles = File.readlines(bpm_styles)[0..6].join("")
      end
    end
      
    if package_version
      bpm_libs.should =~ exp_str
      bpm_styles.should   =~ exp_str
    else
      # note: it's ok if the file does not exist; means asset was not built
      bpm_libs.should_not =~ exp_str if bpm_libs
      bpm_styles.should_not   =~ exp_str if bpm_styles
    end
  end
    
  def has_dependency(package_name, package_version, hard_version = '>= 0')
    validate_dependency_in_project_file package_name, hard_version
    validate_installed_dependency package_name, package_version
    # TODO: Verify packages built into bpm_libs.js and css
  end

  def has_development_dependency(package_name, package_version, hard_version = '>= 0')
    validate_dependency_in_project_file package_name, hard_version, true
    validate_installed_dependency package_name, package_version
    # TODO: Verify packages built into bpm_libs.js and css
  end

  def has_soft_dependency(package_name, package_version)
    validate_dependency_in_project_file package_name, nil
    validate_installed_dependency package_name, package_version
    # TODO: Verify packages built into bpm_libs.js and css
  end
  
  def no_dependency(package_name, check_installed=true)
    validate_dependency_in_project_file package_name, nil
    validate_installed_dependency package_name, nil if check_installed
    # TODO: Verify packages not built into bpm_libs.js and css
  end

  def no_development_dependency(package_name, check_installed=true)
    validate_dependency_in_project_file package_name, nil, true
    validate_installed_dependency package_name, nil if check_installed
    # TODO: Verify packages not built into bpm_libs.js and css
  end

end
