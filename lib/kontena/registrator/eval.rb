module Kontena::Registrator::Eval
  class Context
    def initialize(**context)
      context.each_pair do |sym, value|
        self.set(sym, value)
      end
    end

    # Evaluate some expression in the context of this daemon
    def eval(expr)
      case expr
      when String
        # XXX: late interpolate?
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
