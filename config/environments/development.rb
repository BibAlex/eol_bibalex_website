Rails.application.configure do
# Settings specified here will take precedence over those in config/application.rb.

# In the development environment your application's code is reloaded on
# every request. This slows down response time but is perfect for development
# since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = true

  # Show full error reports.
  config.consider_all_requests_local = true
  config.action_controller.enable_fragment_cache_logging = true
  #if config.respond_to?(:action_mailer)
  # config.action_mailer.default_url_options = { host: '172.16.0.186', port: 80 }
  #config.action_mailer.delivery_method = :smtp
  #config.action_mailer.smtp_settings = {:address => "localhost", :port => 1025}

  # Enable/disable cacurching. By default caching is disabled.
  if Rails.root.join('tmp/caching-dev.txt').exist?
    config.action_controller.perform_caching = true
    config.cache_store = :memory_store, { size: 64.megabytes }
    # config.public_file_server.headers = {
      # 'Cache-Control' => "public, max-age= 60"
    # }
  else
    config.action_controller.perform_caching = false
    config.cache_store = :null_store
  end
  config.cache_versioning = false

  # Don't care if the mailer can't send.
  #config.action_mailer.raise_delivery_errors = true

  #config.action_mailer.perform_caching = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = false
  #config.assets.debug = true

  # Suppress logger output for asset requests.
  config.assets.quiet = true
  config.assets.compile = true
  # config.assets.compile = false
  # config.public_file_server.enabled = true
  # config.serve_static_files = true
  # config.serve_static_assets = false
  config.assets.initialize_on_precompile = true
  config.assets.digest = true
  # config.assets.concat = true
  config.assets.compress = false
  # config.assets.css_compressor = nil
  # config.assets.js_compressor = nil
  config.assets.prefix = '/assets'
  config.assets.enabled = true

  #config.action_mailer.raise_delivery_errors = true

  #config.action_mailer.perform_caching = true
  #config.action_mailer_sender = 'nada.eliba@bibalex.org'
  #config.action_mailer.perform_deliveries = true
  #config.action_mailer.delivery_method = :sendmail
  #config.action_mailer.default_url_options = { host: 'eol.bibalex.org'}

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true

  # Use an evented file watcher to asynchronously detect changes in source code,
  # routes, locales, etc. This feature depends on the listen gem.
  config.file_watcher = ActiveSupport::EventedFileUpdateChecker
end
