require 'libgems/config_file'

module LibGems
  class ConfigFile

    # Duplicate, with slight work-arounds, but needed for SYSTEM_WIDE_CONFIG_FILE
    system_config_path =
      if defined?(Win32API) # Already required in original version
        CSIDL_COMMON_APPDATA = 0x0023
        path = 0.chr * 260
        if RUBY_VERSION > '1.9' then
          SHGetFolderPath = Win32API.new 'shell32', 'SHGetFolderPath', 'PLPLP',
                                         'L', :stdcall
          SHGetFolderPath.call nil, CSIDL_COMMON_APPDATA, nil, 1, path
        else
          SHGetFolderPath = Win32API.new 'shell32', 'SHGetFolderPath', 'LLLLP',
                                         'L'
          SHGetFolderPath.call 0, CSIDL_COMMON_APPDATA, 0, 1, path
        end

        path.strip
      else
        '/etc'
      end

    remove_const(:SYSTEM_WIDE_CONFIG_FILE)
    SYSTEM_WIDE_CONFIG_FILE = File.join system_config_path, 'spaderc'

    def credentials_path
      File.join(LibGems.user_dir, "credentials")
    end
  end
end
