require 'requirejs/rails'
require 'requirejs/error'

require 'active_support/ordered_options'
require 'erubis'
require 'pathname'

module Requirejs::Rails
  class Config < ::ActiveSupport::OrderedOptions
    LOADERS = [ :requirejs, :almond ]

    def initialize(application)
      super
      self.manifest = nil

      self.logical_asset_filter = [/\.js$/,/\.html$/,/\.txt$/]
      self.tmp_dir = application.root + 'tmp'
      self.bin_dir = Pathname.new(__FILE__+'/../../../../bin').cleanpath

      self.source_dir = self.tmp_dir + 'assets'
      self.target_dir = application.root + 'public/assets'
      self.rjs_path   = self.bin_dir+'r.js'

      self.loader = :requirejs

      self.driver_template_path = Pathname.new(__FILE__+'/../rjs_driver.js.erb').cleanpath
      self.driver_path = self.tmp_dir + 'rjs_driver.js'

      self.user_config = {}

      self.run_config_whitelist = %w{
        baseUrl
        callback
        catchError
        config
        context
        deps
        jQuery
        locale
        map
        packages
        paths
        priority
        scriptType
        shim
        urlArgs
        waitSeconds
        xhtml
      }

      self.build_config_whitelist = %w{
        appDir
        baseUrl
        closure
        cssImportIgnore
        cssIn
        dir
        fileExclusionRegExp
        findNestedDependencies
        generateSourceMaps
        has
        hasOnSave
        include
        inlineText
        locale
        mainConfigFile
        map
        modules
        name
        namespace
        onBuildRead
        onBuildWrite
        optimize
        optimizeAllPluginResources
        optimizeCss
        out
        packagePaths
        packages
        paths
        pragmas
        pragmasOnSave
        preserveLicenseComments
        shim
        skipModuleInsertion
        skipPragmas
        uglify
        uglify2
        useStrict
        wrap
      }
    end

    def loader=(sym)
      unless LOADERS.include?(sym)
        raise Requirejs::ConfigError, "Attempt to set unknown loader: #{sym}"
      end
      self[:loader] = sym
    end

    def build_config
      unless self.has_key?(:build_config)
        self[:build_config] = self.run_config.merge "baseUrl" => source_dir.to_s,
                                                    "modules" => [ { 'name' => 'application' } ]
        self[:build_config].merge!(self.user_config).slice!(*self.build_config_whitelist)
        case self.loader
        when :requirejs
          # nothing to do
        when :almond
          mods = self[:build_config]['modules']
          mods.each do |mod|
            name = mod['name']
            mod['name'] = 'almond'
            mod['include'] = name
          end
        end
      end
      self[:build_config]
    end

    def run_config
      unless self.has_key?(:run_config)
        self[:run_config] = { "baseUrl" => "/assets" }
        self[:run_config].merge!(self.user_config).slice!(*self.run_config_whitelist)
      end
      self[:run_config]
    end

    def user_config=(cfg)
      if url = cfg.delete('baseUrl')
        raise Requirejs::ConfigError, "baseUrl is not needed or permitted in the configuration"
      end
      self[:user_config] = cfg
    end

    def module_name_for(mod)
      case self.loader
      when :almond
        return mod['include']
      when :requirejs
        return mod['name']
      end
    end

    def module_path_for(mod)
      self.target_dir+(module_name_for(mod)+'.js')
    end

    def get_binding
      return binding()
    end

    def asset_allowed?(asset)
      self.logical_asset_filter.reduce(false) do |accum, matcher|
        accum || (matcher =~ asset)
      end ? true : false
    end
  end
end
