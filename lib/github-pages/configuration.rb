# frozen_string_literal: true

require "securerandom"

module GitHubPages
  # Sets and manages Jekyll configuration defaults and overrides
  class Configuration
    # Backward compatability of constants
    DEFAULT_PLUGINS     = GitHubPages::Plugins::DEFAULT_PLUGINS
    PLUGIN_WHITELIST    = GitHubPages::Plugins::PLUGIN_WHITELIST
    DEVELOPMENT_PLUGINS = GitHubPages::Plugins::DEVELOPMENT_PLUGINS
    THEMES              = GitHubPages::Plugins::THEMES

    # Default, user overwritable options
    DEFAULTS = {
      "jailed"   => false,
      "gems"     => GitHubPages::Plugins::DEFAULT_PLUGINS,
      "future"   => true,
      "theme"    => "jekyll-theme-primer",
      "kramdown" => {
        "input"     => "GFM",
        "hard_wrap" => false,
        "gfm_quirks" => "paragraph_end",
      },
    }.freeze

    # Jekyll defaults merged with Pages defaults.
    MERGED_DEFAULTS = Jekyll::Utils.deep_merge_hashes(
      Jekyll::Configuration::DEFAULTS,
      DEFAULTS
    ).freeze

    # Options which GitHub Pages sets, regardless of the user-specified value
    #
    # The following values are also overridden by GitHub Pages, but are not
    # overridden locally, for practical purposes:
    # * source
    # * destination
    # * jailed
    # * verbose
    # * incremental
    # * GH_ENV
    OVERRIDES = {
      "lsi"         => false,
      "safe"        => true,
      "plugins"     => SecureRandom.hex,
      "plugins_dir" => SecureRandom.hex,
      "whitelist"   => GitHubPages::Plugins::PLUGIN_WHITELIST,
      "highlighter" => "rouge",
      "kramdown"    => {
        "template"           => "",
        "math_engine"        => "mathjax",
        "syntax_highlighter" => "rouge",
      },
      "gist"        => {
        "noscript"  => false,
      },
    }.freeze

    # These configuration settings have corresponding instance variables on
    # Jekyll::Site and need to be set properly when the config is updated.
    CONFIGS_WITH_METHODS = %w(
      safe lsi highlighter baseurl exclude include future unpublished
      show_drafts limit_posts keep_files gems
    ).freeze

    class << self
      def processed?(site)
        site.instance_variable_get(:@_github_pages_processed) == true
      end

      def processed(site)
        site.instance_variable_set :@_github_pages_processed, true
      end

      def disable_whitelist?
        development? && !ENV["DISABLE_WHITELIST"].to_s.empty?
      end

      def development?
        Jekyll.env == "development"
      end

      # Given a user's config, determines the effective configuration by building a user
      # configuration sandwhich with our overrides overriding the user's specified
      # values which themselves override our defaults.
      #
      # Returns the effective Configuration
      #
      # Note: this is a highly modified version of Jekyll#configuration
      def effective_config(user_config)
        # Merge user config into defaults
        config = Jekyll::Utils.deep_merge_hashes(MERGED_DEFAULTS, user_config)
          .fix_common_issues
          .add_default_collections

        # Merge overwrites into user config
        config = Jekyll::Utils.deep_merge_hashes config, OVERRIDES

        # Ensure we have those gems we want.
        config["gems"] = Array(config["gems"]) | DEFAULT_PLUGINS
        config["whitelist"] = config["whitelist"] | config["gems"] if disable_whitelist?
        config["whitelist"] = config["whitelist"] | DEVELOPMENT_PLUGINS if development?

        config
      end

      # Set the site's configuration. Implemented as an `after_reset` hook.
      # Equivalent #set! function contains the code of interest. This function
      # guards against double-processing via the value in #processed.
      def set(site)
        return if processed? site
        debug_print_versions
        set!(site)
        processed(site)
      end

      # Print the versions for github-pages and jekyll to the debug
      # stream for debugging purposes. See by running Jekyll with '--verbose'
      def debug_print_versions
        Jekyll.logger.debug "GitHub Pages:", "github-pages v#{GitHubPages::VERSION}"
        Jekyll.logger.debug "GitHub Pages:", "jekyll v#{Jekyll::VERSION}"
      end

      # Set the site's configuration with all the proper defaults and overrides.
      # Should be called by #set to protect against multiple processings.
      def set!(site)
        config = effective_config(site.config)

        # Assign everything to the site
        site.instance_variable_set :@config, config

        # Ensure all
        CONFIGS_WITH_METHODS.each do |opt|
          site.public_send("#{opt}=", site.config[opt])
        end
      end
    end
  end
end
