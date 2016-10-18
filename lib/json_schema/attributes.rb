module JsonSchema
  # Attributes mixes in some useful attribute-related methods for use in
  # defining schema classes in a spirit similar to Ruby's attr_accessor and
  # friends.
  module Attributes
    # Provides class-level methods for the Attributes module.
    module ClassMethods
      attr_reader :copyable_attrs

      # Attributes that are part of the JSON schema and hyper-schema
      # specifications. These are allowed to be accessed with the [] operator.
      #
      # Hash contains the access key mapped to the name of the method that should
      # be invoked to retrieve a value. For example, `type` maps to `type` and
      # `additionalItems` maps to `additional_items`.
      attr_reader :schema_attrs

      # identical to attr_accessible, but allows us to copy in values from a
      # target schema to help preserve our hierarchy during reference expansion
      def attr_copyable(attr)
        attr_accessor(attr)
        self.copyable_attrs << "@#{attr}".to_sym
      end

      def attr_schema(attr, options = {})
        attr_copyable(attr)
        self.schema_attrs[options[:schema_name] || attr] = attr
      end

      def attr_reader_default(attr, default)
        # remove the reader already created by attr_accessor
        remove_method(attr)

        class_eval("def #{attr} ; !@#{attr}.nil? ? @#{attr} : #{default} ; end")
      end

      # Directive indicating that attributes should be inherited from a parent
      # class.
      #
      # Must appear as first statement in class that mixes in (or whose parent
      # mixes in) the Attributes module.
      def inherit_attrs
        @copyable_attrs = self.superclass.instance_variable_get(:@copyable_attrs)
        @schema_attrs = self.superclass.instance_variable_get(:@schema_attrs)
      end

      # Initializes some class instance variables required to make other
      # methods in the Attributes module work. Run automatically when the
      # module is mixed into another class.
      def initialize_attrs
        @copyable_attrs = []
        @schema_attrs = {}
      end
    end

    def self.included(klass)
      klass.extend(ClassMethods)
      klass.send(:initialize_attrs)
    end

    # Allows the values of schema attributes to be accessed with a symbol or a
    # string. So for example, the value of `schema.additional_items` could be
    # procured with `schema[:additionalItems]`. This only works for attributes
    # that are part of the JSON schema specification; other methods on the
    # class are not available (e.g. `expanded`.)
    #
    # This is implemented so that `JsonPointer::Evaluator` can evaluate a
    # reference on an sintance of this class (as well as plain JSON data).
    def [](name)
      name = name.to_sym
      if self.class.schema_attrs.key?(name)
        send(self.class.schema_attrs[name])
      else
        raise NoMethodError, "Schema does not respond to ##{name}"
      end
    end

    def copy_from(schema)
      self.class.copyable_attrs.each do |copyable|
        instance_variable_set(copyable, schema.instance_variable_get(copyable))
      end
    end

    def initialize_schema_attrs
      self.class.schema_attrs.each do |_, a|
        send(:"#{a}=", nil)
      end
    end
  end
end
