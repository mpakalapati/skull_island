# frozen_string_literal: true

module SkullIsland
  # Resource classes go here...
  module Resources
    # The Upstream Target resource class
    #
    # @see https://docs.konghq.com/0.14.x/admin-api/#target-object Target API definition
    class UpstreamTarget < Resource
      property :target, required: true, validate: true, preprocess: true
      property(
        :upstream_id,
        required: true, validate: true, preprocess: true, postprocess: true, as: :upstream
      )
      property :weight, validate: true
      property :created_at, read_only: true, postprocess: true

      def self.get(id, options = {})
        if options[:upstream]&.is_a?(Upstream)
          options[:upstream].target(id)
        elsif options[:upstream]
          upstream_opts = options.merge(lazy: true)
          Upstream.get(options[:upstream], upstream_opts).target(id)
        end
      end

      def relative_uri
        upstream ? "#{upstream.relative_uri}/targets/#{id}" : nil
      end

      def save_uri
        upstream ? "#{upstream.relative_uri}/targets" : nil
      end

      def preprocess_target(input)
        if input.is_a?(URI)
          "#{input.host}:#{input.port || 8000}"
        else
          input
        end
      end

      def preprocess_upstream_id(input)
        if input.is_a?(Hash)
          input['id']
        elsif input.is_a?(String)
          input
        else
          input.id
        end
      end

      def postprocess_upstream_id(value)
        if value.is_a?(String)
          Upstream.new(
            entity: { 'id' => value },
            lazy: true,
            tainted: false
          )
        else
          value
        end
      end

      # Used to validate {#target} on set
      def validate_target(value)
        # only URIs or specific strings
        value.is_a?(URI) || (
          value.is_a?(String) && value.match?(/\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}:\d{1,5}/)
        )
      end

      # Used to validate #upstream on set
      def validate_upstream_id(value)
        # allow either a Upstream object or a String
        value.is_a?(Upstream) || value.is_a?(String)
      end

      # Used to validate {#weight} on set
      def validate_weight(value)
        # only positive Integers (or zero) are allowed
        value.is_a?(Integer) && (0..1000).cover?(value)
      end
    end
  end
end
