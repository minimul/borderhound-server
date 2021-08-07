app_dir = File.expand_path('../', __dir__ )
shared_dir = File.expand_path('../../shared/', __dir__)

bind "unix://#{shared_dir}/sockets/puma.sock"
pidfile "#{shared_dir}/tmp/pids/puma.pid"

threads_count = Integer(ENV['RAILS_MAX_THREADS'] || 5)
threads threads_count, threads_count

worker_timeout 3600 if ENV.fetch("RAILS_ENV", "development") == "development"
workers Integer(ENV['WEB_CONCURRENCY'] || 5)

preload_app!

environment ENV.fetch("RAILS_ENV", "development")
prune_bundler

directory app_dir
