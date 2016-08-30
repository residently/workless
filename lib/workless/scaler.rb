module Delayed
  module Workless
    module Scaler
      autoload :Heroku,      'workless/scalers/heroku'
      autoload :HerokuCedar, 'workless/scalers/heroku_cedar'
      autoload :Local,       'workless/scalers/local'
      autoload :Null,        'workless/scalers/null'

      def self.included(base)
        base.send :extend, ClassMethods
        if base.to_s =~ /ActiveRecord/
          base.class_eval do
            after_commit 'self.class.scaler.down'.to_sym, on: :update, if: proc { |r| !r.failed_at.nil? }
            after_commit 'self.class.scaler.down'.to_sym, on: :destroy, if: proc { |r| r.destroyed? || !r.failed_at.nil? }
            after_commit 'self.class.scaler.up'.to_sym, on: :create
          end
        elsif base.to_s =~ /Sequel/
          base.send(:define_method, 'after_destroy') do
            super
            self.class.scaler.down
          end
          base.send(:define_method, 'after_create') do
            super
            self.class.scaler.up
          end
          base.send(:define_method, 'after_update') do
            super
            self.class.scaler.down
          end
        else
          base.class_eval do
            after_destroy 'self.class.scaler.down'
            after_create 'self.class.scaler.up'
            after_update 'self.class.scaler.down', unless: proc { |r| r.failed_at.nil? }
          end
        end
      end

      module ClassMethods
        def scaler
          @scaler ||= if ENV.include?('HEROKU_API_KEY')
                        Scaler::HerokuCedar
                      else
                        Scaler::Local
          end
        end

        def scaler=(scaler)
          @scaler = "Delayed::Workless::Scaler::#{scaler.to_s.camelize}".constantize
        end
      end
    end
  end
end
