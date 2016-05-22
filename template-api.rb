def source_paths
  [File.expand_path(File.dirname(__FILE__))]
end

gsub_file "Gemfile", /.*$/,''
gsub_file "Gemfile", /^$\n/, ''

add_source 'https://rubygems.org'

insert_into_file 'Gemfile', "\nruby ENV['CUSTOM_RUBY_VERSION'] || '2.2.4'", 
                 after: "source 'https://rubygems.org'\n"

gem 'rails', '4.2.5'
gem 'rails-api'
gem 'rack-cors'
gem 'actionmailer'
gem 'devise'
gem 'devise'
gem 'omniauth'
gem 'devise_token_auth'
gem 'devise_invitable'
gem 'carrierwave'
gem 'carrierwave-aws'
gem 'carrierwave_backgrounder'

gem 'kaminari'
gem 'api-pagination'

gem "tzinfo-data", platforms: [:mswin, :mingw, :jruby, :x64_mingw]

gem_group :database do
  gem_group :postgresql do
    gem 'pg'
  end
end

gem 'sidekiq'
gem 'redis'
gem 'redis-namespace'

gem 'gcm' # Google Cloud Messageing

# Logging & BI
gem 'google-analytics-rails'
  gem 'rollbar'

gem_group :development do
  gem 'annotate', '>=2.6.0'
  gem 'spring' # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'letter_opener'
end

# sets database to postgresql
gsub_file "config/database.yml", /adapter: sqlite3/, "adapter: postgresql\n\s\sencoding: unicode"
gsub_file "config/database.yml", /database: db\/development.sqlite3/, "database: #{app_name.gsub!('-', '_')}_development"
gsub_file "config/database.yml", /database: db\/test.sqlite3/,        "database: #{app_name}_test"
gsub_file "config/database.yml", /database: db\/production.sqlite3/,  "database: #{app_name}_production"

insert_into_file 'config.ru', "\n\nrequire 'rack/cors'
use Rack::Cors do

  # allow all origins in development
  allow do
    origins '*'
    resource '*',
             :headers => :any,
             :expose  => ['access-token', 'expiry', 'token-type', 'uid', 'client', 'total', 'page', 'per-page'],
             :methods => [:get, :post, :delete, :put, :patch, :options]
  end
end\n", after: "run Rails.application"

gsub_file "config/application.rb", /# Do not swallow errors in after_commit\/after_rollback callbacks./,  "config.i18n.default_locale = 'pt-BR'
    config.i18n.available_locales = ['pt-BR']
    config.time_zone = 'Brasilia'
    config.i18n.enforce_available_locales = false

    # Do not swallow errors in after_commit\/after_rollback callbacks."

gsub_file "config/environments/development.rb", /# config.action_view.raise_on_missing_translations = true/,  "# config.action_view.raise_on_missing_translations = true

  config.action_mailer.default_url_options = { :host => ENV[\"HOST_URL\"] || 'localhost:3000' }\n"

run 'bundle install'

rake "db:reset", :env => 'test'
rake "db:reset", :env => 'development'
rake "db:create", :env => 'test'
rake "db:create", :env => 'development'


# Ignore rails doc files, Vim/Emacs swap files, .DS_Store, and more
# ===================================================
copy_file "template.gitignore", ".gitignore"


# Sublime Project
# ===================================================
sublime_file_name = "#{app_name.gsub!('_', '-')}"
copy_file "template.sublime-project", sublime_file_name


# Devise & devise token installation
# ===================================================
run 'rails generate devise:install'
run 'rails g devise_token_auth:install User auth'
run 'rails g migration add_type_to_user type:string'
rake "db:migrate", :env => 'test'
rake "db:migrate", :env => 'development'

# Devise controllers
inside('app/controllers') { run "mkdir overrides"  }
copy_file "template_registrations_controller.rb", "app/controllers/overrides/registrations_controller.rb"
copy_file "template_token_validations_controller.rb", "app/controllers/overrides/token_validations_controller.rb"
run 'rails g controller users update_image me'
copy_file "template_users_controller.rb", "app/controllers/users_controller.rb"

# Devise Routes
gsub_file "config/routes.rb", /mount_devise_token_auth_for 'User', at: 'auth'/,  "mount_devise_token_auth_for 'User', at: 'auth', controllers: {
    token_validations:  'overrides/token_validations', 
    registrations:  'overrides/registrations'
  }"
gsub_file "config/routes.rb", /get 'users\/update_image'/,  "post 'users/update_image', to: \"users#update_image\""
gsub_file "config/routes.rb", /get 'users\/me'/,  "get 'me', to: \"users#me\""

# Devise ADMIN
run 'rails g model admin --parent User'
run 'rails g scaffold_controller admin'
gsub_file "app/controllers/admins_controller.rb", /class AdminsController < ApplicationController/,  "class AdminsController < ApplicationController
  before_action :authenticate_user!"


# Carrierwave & Uploader
# ===================================================
# Carierwave
copy_file "template_carrierwave.rb", "config/initializers/carrierwave.rb"
gsub_file "config/initializers/carrierwave.rb", /APP_NAME/, app_name.gsub!('-', '.')

# Validator
copy_file "template_file_size_validator.rb", "lib/file_size_validator.rb"

# Uploader
inside('app') { run "mkdir uploaders"  }
copy_file "template_user_image_uploader.rb", "app/uploaders/user_image_uploader.rb"

# User Image Property
# ===================================================
gsub_file "app/models/user.rb", /class User < ActiveRecord::Base/,  "require 'file_size_validator'

class User < ActiveRecord::Base"

gsub_file "app/models/user.rb", /include DeviseTokenAuth::Concerns::User/,  "include DeviseTokenAuth::Concerns::User
  attr_accessor :skip_image_storage
  
  mount_uploader :image, UserImageUploader
  validates :image, allow_blank: true, file_size: { maximum: 3.megabytes.to_i,  message: \"O arquivo enviado é muito grande. Tamanho máximo 3 MB.\"}, if: :check_storage?

  def check_storage?
    !self.skip_image_storage
  end

  def skip_storage?
    self.skip_image_storage
  end"

run 'annotate'