module Slim
  # Handle logic less mode
  # This filter can be activated with the option "logic_less"
  # @api private
  class LogicLess < Filter
    DICTIONARY_ACCESS = [:symbol, :string, :method, :instance_variable]

    define_options :logic_less => true,
                   :dictionary => 'self',
                   :dictionary_access => DICTIONARY_ACCESS

    def initialize(opts = {})
      super
      if options[:directory_access] == :wrapped
        puts 'Slim::LogicLess - Wrapped directory access is deprecated'
        options[:directory_access] = DICTIONARY_ACCESS
      end
      access = [options[:dictionary_access]].flatten.compact
      access.each do |type|
        raise ArgumentError, "Invalid dictionary access #{type.inspect}" unless DICTIONARY_ACCESS.include?(type)
      end
      raise ArgumentError, 'Option dictionary access is missing' if access.empty?
      @access = access.inspect
    end

    def call(exp)
      if options[:logic_less]
        @context = unique_name
        [:multi,
         [:code, "#{@context} = ::Slim::LogicLess::Context.new(#{options[:dictionary]}, #{@access})"],
         super]
      else
        exp
      end
    end

    # Interpret control blocks as sections or inverted sections
    def on_slim_control(name, content)
      method =
        if name =~ /\A!\s*(.*)/
          name = $1
          'inverted_section'
        else
          'section'
        end
      [:block, "#{@context}.#{method}(#{name.to_sym.inspect}) do", compile(content)]
    end

    def on_slim_output(escape, name, content)
      if empty_exp?(content)
        [:slim, :output, escape, access(name), compile(content)]
      else
        [:slim, :output, escape, "#{@context}.lambda(#{name.to_sym.inspect}) do", compile(content)]
      end
    end

    def on_slim_attrvalue(escape, value)
      [:slim, :attrvalue, escape, access(value)]
    end

    def on_slim_splat(code)
      [:slim, :splat, access(code)]
    end

    def on_dynamic(code)
      raise Temple::FilterError, 'Embedded code is forbidden in logic less mode'
    end

    def on_code(code)
      raise Temple::FilterError, 'Embedded code is forbidden in logic less mode'
    end

    private

    def access(name)
      name == 'yield' ? name : "#{@context}[#{name.to_sym.inspect}]"
    end
  end
end
