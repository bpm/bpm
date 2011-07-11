module SpecHelpers
  def reset!
    FileUtils.rm_rf   tmp
    [ home, local ].each do |dir|
      FileUtils.mkdir_p(dir)
    end
  end

  def cd(path, &blk)
    Dir.chdir(path, &blk)
  end

  def cwd(*args)
    Pathname.new(Dir.pwd).join(*args)
  end

  def rm(path)
    FileUtils.rm path
  end

  def rm_r(path)
    FileUtils.rm_r path
  end

  def rm_rf(path)
    FileUtils.rm_rf(path)
  end

  def root
    @root ||= Pathname.new(File.expand_path("../../..", __FILE__))
  end

  def fixtures(*path)
    root.join('spec/fixtures', *path)
  end

  def project_fixture(*path)
    fixtures 'projects', *path
  end
  
  def package_fixture(*path)
    fixtures 'packages', *path
  end
  
  def tmp(*path)
    root.join("tmp", *path)
  end

  def home(*path)
    tmp.join("home", *path)
  end

  def local(*path)
    tmp.join("local", *path)
  end

  def bpm_dir(*path)
    home(BPM::BPM_DIR, *path)
  end

  def goto_home
    cd(home)
    env["HOME"] = home.to_s
    env["BPM_HOME"] = bpm_dir.to_s
    env["BPM_PATH"] = bpm_dir.to_s
    LibGems.clear_paths
  end

  module_function :root, :tmp, :home, :local, :goto_home
end

