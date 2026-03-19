# frozen_string_literal: true

module Rubyn
  module Tools
    class Registry
      class << self
        def register(name, klass)
          @tools ||= {}
          @tools[name.to_s] = klass
        end

        def get(name)
          @tools ||= {}
          @tools[name.to_s]
        end

        def all
          @tools ||= {}
          @tools.dup
        end

        def tool_definitions
          all.map { |name, klass| { name: name, description: klass::DESCRIPTION, parameters: klass::PARAMETERS } }
        end
      end
    end
  end
end
