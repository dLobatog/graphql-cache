# frozen_string_literal: true

require 'graphql/cache/deconstructor'

module GraphQL
  module Cache
    # Used to marshal cache fetches into either writes or reads
    class Marshal
      # The cache key to marshal around
      #
      # @return [String] The cache key
      attr_accessor :key

      # Initializer helper to allow syntax like
      # `Marshal[key].read(config, &block)`
      #
      # @return [GraphQL::Cache::Marshal]
      def self.[](key)
        new(key)
      end

      # Initialize a new instance of {GraphQL::Cache::Marshal}
      def initialize(key)
        self.key = key.to_s
      end

      # Read a value from cache if it exists and re-hydrate it or
      # execute the block and write it's result to cache
      #
      # @param config [Hash] The object passed to `cache:` on the field definition
      # @return [Object]
      def read(config, force: false, &block)
        # write new data from resolver if forced
        return write(config, &block) if force

        cached = cache.read(key)

        if cached.nil?
          logger.debug "Cache miss: (#{key})"
          write config, &block
        else
          logger.debug "Cache hit: (#{key})"
          cached
        end
      end

      # Executes the resolution block and writes the result to cache
      #
      # @see GraphQL::Cache::Deconstruct#perform
      # @param config [Hash] The middleware resolution config hash
      def write(config)
        resolved = yield

        document = Deconstructor[resolved].perform

        with_resolved_document(document) do |resolved_document|
          cache.write(key, resolved_document, expires_in: expiry(config))

          resolved
        end
      end

      # @private
      def with_resolved_document(document)
        if document_is_lazy?(document)
          document.then { |promise_value| yield promise_value }
        else
          yield document
        end
      end

      # @private
      def document_is_lazy?(document)
        ['GraphQL::Execution::Lazy', 'Promise'].include?(document.class.name)
      end

      # @private
      def expiry(config)
        if config.is_a?(Hash) && config[:expiry]
          config[:expiry]
        else
          GraphQL::Cache.expiry
        end
      end

      # @private
      def cache
        GraphQL::Cache.cache
      end

      # @private
      def logger
        GraphQL::Cache.logger
      end
    end
  end
end
