module SpecHelpers
  
  def validate_dependency_in_project_file(package_name, package_version)
    json = JSON.parse File.read(home('hello_world', 'hello_world.json'))
    json['dependencies'][package_name].should == package_version
  end

  def validate_installed_dependency(package_name, package_version)
    bpm_packages = home 'hello_world', 'assets', 'bpm_packages.js'
    bpm_styles   = home 'hello_world', 'assets', 'bpm_styles.css'
    exp_str = "#{package_name} (#{package_version})"

    bpm_packages = File.readlines(bpm_packages)[0..6].join("")
    bpm_styles   = File.readlines(bpm_styles)[0..6].join("")

    if package_version
      bpm_packages.should include(exp_str)
      bpm_styles.should   include(exp_str)
    else
      bpm_packages.should_not include exp_str
      bpm_styles.should_not   include exp_str
    end
  end
    
  def has_dependency(package_name, package_version, hard_version = '>= 0')
    validate_dependency_in_project_file package_name, hard_version
    validate_installed_dependency package_name, package_version
    # TODO: Verify packages built into bpm_packages.js and css
  end

  def has_soft_dependency(package_name, package_version)
    validate_dependency_in_project_file package_name, nil
    validate_installed_dependency package_name, package_version
    # TODO: Verify packages built into bpm_packages.js and css
  end
  
  def no_dependency(package_name)
    validate_dependency_in_project_file package_name, nil
    validate_installed_dependency package_name, nil
    # TODO: Verify packages not built into bpm_packages.js and css
  end
  
end
