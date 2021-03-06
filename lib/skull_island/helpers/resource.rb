# frozen_string_literal: true

module SkullIsland
  module Helpers
    # Simple helper methods for Resources
    module Resource
      def datetime_from_params(params, actual_key)
        DateTime.new(
          params["#{actual_key}(1i)"].to_i,
          params["#{actual_key}(2i)"].to_i,
          params["#{actual_key}(3i)"].to_i,
          params["#{actual_key}(4i)"].to_i,
          params["#{actual_key}(5i)"].to_i
        )
      end

      def fresh?
        !tainted?
      end

      def host_regex
        /^(([\w]|[\w][\w\-]*[\w])\.)*([\w]|[\w][\w\-]*[\w])$/
      end

      def id_property
        self.class.properties.select { |_, opts| opts[:id_property] }.keys.first || 'id'
      end

      def id
        @entity[id_property.to_s]
      end

      def immutable?
        self.class.immutable?
      end

      # ActiveRecord ActiveModel::Name compatibility method
      def model_name
        self.class
      end

      def new?
        !@entity.key?(id_property.to_s)
      end

      # ActiveRecord ActiveModel::Model compatibility method
      def persisted?
        !new?
      end

      def postprocess_created_at(value)
        Time.at(value).utc.to_datetime
      end

      def postprocess_updated_at(value)
        Time.at(value).utc.to_datetime
      end

      def properties
        self.class.properties
      end

      def required_properties
        properties.select { |_key, value| value[:required] }
      end

      def tainted?
        @tainted ? true : false
      end

      # ActiveRecord ActiveModel::Conversion compatibility method
      def to_key
        new? ? [] : [id]
      end

      # ActiveRecord ActiveModel::Conversion compatibility method
      def to_model
        self
      end

      # ActiveRecord ActiveModel::Conversion compatibility method
      def to_param
        new? ? nil : id.to_s
      end

      def destroy
        raise Exceptions::ImmutableModification if immutable?

        unless new?
          @api_client.delete(relative_uri.to_s)
          @api_client.invalidate_cache_for(relative_uri.to_s)
          @lazy = false
          @tainted = true
          @entity.delete('id')
        end
        true
      end

      def reload
        if new?
          # Can't reload a new resource
          false
        else
          @api_client.invalidate_cache_for(relative_uri.to_s)
          entity_data = @api_client.cache(relative_uri.to_s) do |client|
            client.get(relative_uri.to_s)
          end
          @entity  = entity_data
          @lazy    = false
          @tainted = false
          true
        end
      end

      def save
        saveable_data = prune_for_save(@entity)
        validate_required_properties(saveable_data)

        if new?
          @entity  = @api_client.post(save_uri.to_s, saveable_data)
          @lazy    = true
        else
          @api_client.invalidate_cache_for(relative_uri.to_s)
          @entity = @api_client.put(relative_uri, saveable_data)
        end
        @tainted = false
        true
      end

      def save_uri
        self.class.relative_uri
      end

      # ActiveRecord ActiveModel compatibility method
      def update(params)
        new_params = {}
        # need to convert multi-part datetime params
        params.each do |key, value|
          if /([^(]+)\(1i/.match?(key)
            actual_key = key.match(/([^(]+)\(/)[1]
            new_params[actual_key] = datetime_from_params(params, actual_key)
          else
            new_params[key] = value
          end
        end

        new_params.each do |key, value|
          setter_key = "#{key}=".to_sym
          raise Exceptions::InvalidProperty unless respond_to?(setter_key)

          send(setter_key, value)
        end
        save
      end

      def <=>(other)
        if id < other.id
          -1
        elsif id > other.id
          1
        elsif id == other.id
          0
        else
          raise Exceptions::InvalidArguments
        end
      end

      def prune_for_save(data)
        data.reject do |k, v|
          k.to_sym == id_property ||
            !properties[k.to_sym] ||
            properties[k.to_sym][:read_only] ||
            v.nil?
        end
      end
    end
  end
end
