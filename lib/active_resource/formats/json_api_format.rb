require 'active_support/json'

module ActiveResource
  module Formats
    module JsonApiFormat
      extend self

      def extension
        "json"
      end

      def mime_type
        "application/json"
      end

      def encode(hash, options = nil)
        attributes = case hash
                     when Array
                       { data: hash.map { |h| build_attributes(h) } }
                     when ActiveResource::Base
                       build_data_attributes(hash.attributes)
                     else
                       build_data_attributes(hash)
                     end

        ActiveSupport::JSON.encode(attributes, options)
      end

      def decode(json)
        Formats.remove_root(ActiveSupport::JSON.decode(json))
      end

      private

      def build_data_attributes(attributes)
        { data: build_attributes(attributes) }
      end

      def build_attributes(attributes)
        { attributes: attributes }
      end
    end
  end
end
