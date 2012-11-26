require_relative 'types'

module Crystal
  class Program < ModuleType
    include Enumerable

    POINTER_SIZE = 8

    attr_accessor :symbols

    def initialize(options = {})
      super('main')

      object = @types["Object"] = ObjectType.new "Object", nil, self
      value = @types["Value"] = ObjectType.new "Value", object, self
      numeric = @types["Numeric"] = ObjectType.new "Numeric", value, self
      enumerable = @types["Enumerable"] = ModuleType.new "Enumerable", self
      array = @types["Array"] = ArrayType.new object, self
      array.include enumerable

      @types["Bool"] = PrimitiveType.new "Bool", value, LLVM::Int1, 1, self
      @types["Char"] = PrimitiveType.new "Char", value, LLVM::Int8, 1, self
      @types["Int"] = PrimitiveType.new "Int", numeric, LLVM::Int32, 4, self
      @types["Long"] = PrimitiveType.new "Long", numeric, LLVM::Int64, 8, self
      @types["Float"] = PrimitiveType.new "Float", numeric, LLVM::Float, 4, self
      @types["String"] = PrimitiveType.new "String", value, LLVM::Pointer(char.llvm_type), POINTER_SIZE, self
      @types["Symbol"] = PrimitiveType.new "Symbol", value, LLVM::Int32, 4, self
      @types["Pointer"] = PrimitiveType.new "Pointer", value, LLVM::Pointer(char.llvm_type), POINTER_SIZE, self

      string_array = array.clone
      string_array.element_type = @types["String"]
      @types["ARGV"] = Crystal::ARGV.new string_array

      @symbols = Set.new

      define_primitives
      define_builtins options[:load_std]
    end

    def void
      nil
    end

    def value
      @types["Value"]
    end

    def object
      @types["Object"]
    end

    def bool
      @types["Bool"]
    end

    def char
      @types["Char"]
    end

    def int
      @types["Int"]
    end

    def long
      @types["Long"]
    end

    def float
      @types["Float"]
    end

    def string
      @types["String"]
    end

    def symbol
      @types["Symbol"]
    end

    def array
      @types["Array"]
    end

    def define_builtins(load_std)
      if load_std == true
        Dir[File.expand_path("../../../std/**/*.cr",  __FILE__)].each do |file|
          load_std file
        end
      elsif load_std.is_a?(Array)
        load_std.each do |filename|
          load_std File.expand_path("../../../std/#{filename}.cr", __FILE__)
        end
      elsif load_std
        load_std File.expand_path("../../../std/#{load_std}.cr", __FILE__)
      end
    end

    def load_std(file)
      node = Parser.parse(File.read(file))
      node.accept TypeVisitor.new(self)
    end

    def library_names
      libs = []
      @types.values.each do |type|
        if type.is_a?(LibType) && type.libname
          libs << type.libname
        end
      end
      libs
    end
  end
end