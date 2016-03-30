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
gem 'devise_invitable', '~> 1.3.4'
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

gem_group :workers do
  gem 'sidekiq', '~> 3.2.6'
  gem 'redis'
  gem 'redis-namespace'
end

gem_group :android do
  gem 'gcm' # Google Cloud Messageing
end

# Logging & BI
gem_group :logging do
  gem 'google-analytics-rails'
  gem 'rollbar', '~> 2.2.1'
end

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
run "cat << EOF >> .gitignore
# Ignore bundler config.
/.bundle

# Ignore the default SQLite database.
/db/*.sqlite3
/db/*.sqlite3-journal
/db/schema.rb

# Ignore all logfiles and tempfiles.
/log/*.log
/tmp

.DS_Store
/public/uploads

# vagrant
/.vagrant
/Vagrantfile
/puppet
/bootstrap.sh

#sublime
*.sublime-workspace
EOF"

# Ignore rails doc files, Vim/Emacs swap files, .DS_Store, and more
# ===================================================
run "cat << EOF >> #{app_name.gsub!('_', '-')}.sublime-project
{
  \"folders\":
  [
    {
      \"follow_symlinks\": true,
      \"path\": \".\"
    }
  ]
}
EOF"

# devise & devise token installation
run 'rails generate devise:install'
run 'rails g devise_token_auth:install User auth'
run 'rails g migration add_type_to_user type:string'
rake "db:migrate", :env => 'test'
rake "db:migrate", :env => 'development'
run "cat << EOF >> app/controllers/registrations_controller.rb
class RegistrationsController < DeviseTokenAuth::RegistrationsController

  before_filter :configure_sign_up_params, only: [:create]
  before_filter :configure_account_update_params, only: [:update]

  private

    def configure_sign_up_params
      devise_parameter_sanitizer.for(:sign_up).push(:name)
    end

    def configure_account_update_params
      devise_parameter_sanitizer.for(:account_update).push(:name)
    end

end
EOF"
gsub_file "config/routes.rb", /mount_devise_token_auth_for 'User', at: 'auth'/,  "mount_devise_token_auth_for 'User', at: 'auth', controllers: {
    registrations:  'registrations'
  }"
run 'rails g controller users update_image'
gsub_file "app/controllers/users_controller.rb", /class UsersController < ApplicationController
  def update_image
  end/,  "class UsersController < ApplicationController
  before_action :authenticate_user!

  def update_image
    current_user.update(update_image_params)
    render json: current_user
  end

  def update_image_params
    params.permit(:image, :image_cache)
  end"
run 'rails g scaffold_controller admin'
gsub_file "app/controllers/admins_controller.rb", /class AdminsController < ApplicationController/,  "class AdminsController < ApplicationController
  before_action :authenticate_user!"
run "cat << EOF >> app/models/admin.rb
class Admin < User
end
EOF"
gsub_file "config/routes.rb", /get 'users\/update_image'/,  "post 'users/update_image', to: \"users#update_image\""

# carrierwave
run "cat << EOF >> config/initializers/carrierwave.rb
CarrierWave.configure do |config|
  if Rails.env.production?
    config.storage = :aws
    config.aws_bucket =  \"#{app_name.gsub!('-', '.')}.live\"
  elsif (Rails.env.development? && Rails.application.secrets.aws_access_key_id.present?)
    config.storage = :aws
    config.aws_bucket =  \"#{app_name}.dev\"
  else
    config.storage = :file
    config.aws_bucket =  \"#{app_name}\"
  end
  config.aws_acl    =  :public_read

  config.aws_credentials = {
    access_key_id:      Rails.application.secrets.aws_access_key_id,    # required
    secret_access_key:  Rails.application.secrets.aws_secret_access_key,    # required
    region: \"sa-east-1\"
  }
end
EOF"
#run "cp ../../template_file_size_validator.rb lib/file_size_validator.rb"
copy_file "template_file_size_validator.rb", "lib/file_size_validator.rb"
inside('app') do 
  run "mkdir uploaders" 
end
#run "cp ../../template_user_image_uploader.rb app/uploaders/user_image_uploader.rb"
copy_file "template_user_image_uploader.rb", "app/uploaders/user_image_uploader.rb"

gsub_file "app/models/user.rb", /class User < ActiveRecord::Base/,  "require 'file_size_validator'

class User < ActiveRecord::Base"

gsub_file "app/models/user.rb", /include DeviseTokenAuth::Concerns::User/,  "include DeviseTokenAuth::Concerns::User
  
  mount_uploader :image, UserImageUploader
  validates :image, allow_blank: true, file_size: { maximum: 3.megabytes.to_i,  message: \"O arquivo enviado é muito grande. Tamanho máximo 3 MB.\"}"

run 'annotate'