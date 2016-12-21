module Kontena
  class Registrator
    # TODO: this module is currently not used
    #
    # This dynamic Eval module is intended for a future custom policy language,
    # which would allow loading untrusted user-defined Policies from etcd
    module Eval
      class Context
        def initialize(**context)
          context.each_pair do |sym, value|
            self.set(sym, value)
          end
        end

        # Evaluate some expression in this context
        def eval(expr)
          case expr
          when String
            # TODO: late interpolate?
            return expr # self.instance_eval('%Q[' + expr + ']')
          when Proc
            return self.instance_eval(&expr)
          when Array
            return expr.map{|subexpr| self.eval(subexpr)}
          when Hash
            return Hash[expr.map{|key, value| [self.eval(key), self.eval(value)]}]
          else
            return expr
          end
        end

        # Evaluate some expression and register the result for further evals
        def set(sym, expr)
          self.instance_variable_set("@#{sym}", self.eval(expr))
        end

        def to_s
          return self.instance_variables.map { |var|
            value = self.instance_variable_get(var)

            "#{var}=#{value}"
          }.join ' '
        end
      end
    end
  end
end
