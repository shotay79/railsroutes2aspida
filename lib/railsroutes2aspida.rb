# frozen_string_literal: true

require_relative 'railsroutes2aspida/configuration'
require_relative 'railsroutes2aspida/version'
require 'colorize'

module Railsroutes2aspida
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def execute
      if Railsroutes2aspida.configuration.api_dir.blank?
        raise 'Please set Railsroutes2aspida.configuration.api_dir'
      end

      routes.each do |route|
        parts = route[:path].split('/').filter(&:present?)
        dir = Railsroutes2aspida.configuration.api_dir
        method = route[:method].downcase

        parts.each_with_index do |part, i|
          dir += "/#{part.start_with?(':') ? "_#{part[1..]}@string" : part}"
          FileUtils.mkdir_p(dir) unless Dir.exist?(dir)

          if i == parts.length - 1
            file_path = "#{dir}/index.ts"
            if File.exist?(file_path)
              content = File.read(file_path)
              unless content.include?("#{method}:")
                new_content = content.gsub(/export type Methods = DefineMethods<\{/, "export type Methods = DefineMethods<{\n  #{method}: {\n    // TODO: Define request and response types\n    resBody: Response<{}, unknown>;\n  },")
                File.write(file_path, new_content)
                puts "Added #{method} method to #{file_path}".green
              end
            else
              File.write(file_path, <<~TS)
                import type { DefineMethods } from "aspida";
                import type { Response } from "@/app/_aspida";

                export type Methods = DefineMethods<{
                  #{method}: {
                    // TODO: Define request and response types
                    resBody: Response<{}, unknown>;
                  },
                }>;
              TS
              puts "Created #{file_path}".green
            end
          end
        end
      end
    end

    private

    def routes
      Rails.application.routes.routes.map do |route|
        path = route.path.spec.to_s
        next if path.match(/rails|cable/)

        method = route.verb.downcase
        next if method == 'patch'

        {
          method: route.verb.downcase,
          path: route.path.spec.to_s.gsub('(.:format)', ''),
        }
      end.compact.uniq.sort_by do |route|
        case route[:method]
        when 'delete' then 1
        when 'put' then 2
        when 'post' then 3
        when 'get' then 4
        end
      end
    end
  end
end
