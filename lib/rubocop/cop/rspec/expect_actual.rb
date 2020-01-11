# frozen_string_literal: true

module RuboCop
  module Cop
    module RSpec
      # Checks for `expect(...)` calls containing literal values.
      #
      # @example
      #   # bad
      #   expect(5).to eq(price)
      #   expect(/foo/).to eq(pattern)
      #   expect("John").to eq(name)
      #
      #   # good
      #   expect(price).to eq(5)
      #   expect(pattern).to eq(/foo/)
      #   expect(name).to eq("John")
      #
      class ExpectActual < Cop
        MSG = 'Provide the actual you are testing to `expect(...)`.'

        SIMPLE_LITERALS = %i[
          true
          false
          nil
          int
          float
          str
          sym
          complex
          rational
          regopt
        ].freeze

        COMPLEX_LITERALS = %i[
          array
          hash
          pair
          irange
          erange
          regexp
        ].freeze

        def_node_matcher :expect_literal, <<~PATTERN
          (send
            (send nil? :expect $#literal?)
            #{Runners::ALL.node_pattern_union}
            $(send nil? ...)
          )
        PATTERN

        def on_send(node)
          expect_literal(node) do |argument|
            add_offense(node, location: argument.source_range)
          end
        end

        def autocorrect(node)
          argument, matcher = expect_literal(node)
          lambda do |corrector|
            return if matcher.method_name != :eq

            swap_order(corrector, argument, matcher.arguments.first)
          end
        end

        private

        # This is not implement using a NodePattern because it seems
        # to not be able to match against an explicit (nil) sexp
        def literal?(node)
          node && (simple_literal?(node) || complex_literal?(node))
        end

        def simple_literal?(node)
          SIMPLE_LITERALS.include?(node.type)
        end

        def complex_literal?(node)
          COMPLEX_LITERALS.include?(node.type) &&
            node.each_child_node.all?(&method(:literal?))
        end

        def swap_order(corrector, lhs_arg, rhs_arg)
          corrector.replace(lhs_arg.source_range, rhs_arg.source)
          corrector.replace(rhs_arg.source_range, lhs_arg.source)
        end
      end
    end
  end
end
