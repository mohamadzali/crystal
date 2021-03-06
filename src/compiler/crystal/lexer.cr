require "token"

class Char
  def ident_start?
    alpha? || self == '_'
  end

  def ident_part?
    ident_start? || digit?
  end

  def ident_part_or_end?
    ident_part? || self == '?' || self == '!'
  end
end

module Crystal
  class Lexer
    def initialize(str)
      @buffer = str.cstr
      @token = Token.new
      @line_number = 1
      @column_number = 1
      @filename = ""
    end

    def filename=(filename)
      @filename = filename
    end

    def next_token
      reset_token

      # Skip comments
      if @buffer.value == '#'
        char = next_char_no_column_increment
        while char != '\n' && char != '\0'
          char = next_char_no_column_increment
        end
      end

      start = @buffer
      start_column = @column_number

      case @buffer.value
      when '\0'
        @token.type = :EOF
      when ' ', '\t'
        @token.type = :SPACE
        next_char
        while @buffer.value == ' ' || @buffer.value == '\t'
          @buffer += 1
          @column_number += 1
        end
      when '\n'
        @token.type = :NEWLINE
        next_char
        @line_number += 1
        @column_number = 1
        while @buffer.value == '\n'
          @buffer += 1
          @line_number += 1
        end
      when '='
        case next_char
        when '='
          case next_char
          when '='
            next_char :"==="
          else
            @token.type = :"=="
          end
        when '>'
          next_char :"=>"
        when '~'
          next_char :"=~"
        else
          @token.type = :"="
        end
      when '!'
        case next_char
        when '='
          next_char :"!="
        when '@'
          if @buffer[1].ident_start?
            @token.type = :"!"
          else
            next_char :"!@"
          end
        else
          @token.type = :"!"
        end
      when '<'
        case next_char
        when '='
          case next_char
          when '>'
            next_char :"<=>"
          else
            @token.type = :"<="
          end
        when '<'
          case next_char
          when '='
            next_char :"<<="
          else
            @token.type = :"<<"
          end
        else
          @token.type = :"<"
        end
      when '>'
        case next_char
        when '='
          next_char :">="
        when '>'
          case next_char
          when '='
            next_char :">>="
          else
            @token.type = :">>"
          end
        else
          @token.type = :">"
        end
      when '+'
        case next_char
        when '='
          next_char :"+="
        when '@'
          if @buffer[1].ident_start?
            @token.type = :"+"
          else
            next_char :"+@"
          end
        when '0'
          case @buffer[1]
          when 'x'
            scan_hex_number
          when 'b'
            scan_bin_number
          else
            scan_number(@buffer - 1, 2)
          end
        when '1', '2', '3', '4', '5', '6', '7', '8', '9'
          scan_number(@buffer - 1, 2)
        else
          @token.type = :"+"
        end
      when '-'
        case next_char
        when '='
          next_char :"-="
        when '@'
          if @buffer[1].ident_start?
            @token.type = :"-"
          else
            next_char :"-@"
          end
        when '>'
          next_char :"->"
        when '0'
          case @buffer[1]
          when 'x'
            scan_hex_number(-1)
          when 'b'
            scan_bin_number(-1)
          else
            scan_number(@buffer - 1, 2)
          end
        when '1', '2', '3', '4', '5', '6', '7', '8', '9'
          scan_number(@buffer - 1, 2)
        else
          @token.type = :"-"
        end
      when '*'
        case next_char
        when '='
          next_char :"*="
        when '*'
          case next_char
          when '='
            next_char :"**="
          else
            @token.type = :"**"
          end
        else
          @token.type = :"*"
        end
      when '/'
        char = next_char
        if char == '='
          next_char :"/="
        elsif char.whitespace? || char == '\0' || char == ';'
          @token.type = :"/"
        else
          start = @buffer
          count = 1
          while next_char != '/'
            count += 1
          end
          next_char
          @token.type = :REGEXP
          @token.value = String.new(start, count)
        end
      when '%'
        case next_char
        when '='
          next_char :"%="
        when '('
          string_start_pair '(', ')'
        when '['
          string_start_pair '[', ']'
        when '{'
          string_start_pair '{', '}'
        when '<'
          string_start_pair '<', '>'
        when 'w'
          if @buffer[1] == '('
            next_char
            next_char :STRING_ARRAY_START
          else
            @token.type = :"%"
          end
        else
          @token.type = :"%"
        end
      when '(' then next_char :"("
      when ')' then next_char :")"
      when '{' then next_char :"{"
      when '}' then next_char :"}"
      when '['
        case next_char
        when ']'
          case next_char
          when '='
            next_char :"[]="
          when '?'
            next_char :"[]?"
          else
            @token.type = :"[]"
          end
        else
          @token.type = :"["
        end
      when ']' then next_char :"]"
      when ',' then next_char :","
      when '?' then next_char :"?"
      when ';' then next_char :";"
      when ':'
        char = next_char
        if char == ':'
          next_char :"::"
        elsif char.ident_start?
          start = @buffer
          count = 1
          while next_char.ident_part?
            count += 1
          end
          if @buffer.value == '!' || @buffer.value == '?'
            next_char
            count += 1
          end
          @token.type = :SYMBOL
          @token.value = String.new(start, count)
        elsif char == '"'
          start = @buffer + 1
          count = 0
          while next_char != '"'
            count += 1
          end
          next_char
          @token.type = :SYMBOL
          @token.value = String.new(start, count)
        else
          @token.type = :":"
        end
      when '~'
        case next_char
        when '@'
          next_char :"~@"
        else
          @token.type = :"~"
        end
      when '.'
        case next_char
        when '.'
          case next_char
          when '.'
            next_char :"..."
          else
            @token.type = :".."
          end
        else
          @token.type = :"."
        end
      when '&'
        case next_char
        when '&'
          case next_char
          when '='
            next_char :"&&="
          else
            @token.type = :"&&"
          end
        when '='
          next_char :"&="
        else
          @token.type = :"&"
        end
      when '|'
        case next_char
        when '|'
          case next_char
          when '='
            next_char :"||="
          else
            @token.type = :"||"
          end
        when '='
          next_char :"|="
        else
          @token.type = :"|"
        end
      when '^'
        case next_char
        when '='
          next_char :"^="
        else
          @token.type = :"^"
        end
      when '\''
        @token.type = :CHAR
        case char1 = next_char
        when '\\'
          case char2 = next_char
          when 'e'
            @token.value = '\e'
          when 'f'
            @token.value = '\f'
          when 'n'
            @token.value = '\n'
          when 'r'
            @token.value = '\r'
          when 't'
            @token.value = '\t'
          when 'v'
            @token.value = '\v'
          when 'x'
            value = consume_hex_escape
            @token.value = value.chr
          when '0', '1', '2', '3', '4', '5', '6', '7', '8'
            char_value = consume_octal_escape(char2)
            @token.value = char_value.chr
          else
            @token.value = char2
          end
        else
          @token.value = char1
        end
        if next_char != '\''
          raise "unterminated char literal", @line_number, @column_number
        end
        next_char
      when '"'
        next_char
        @token.type = :STRING_START
        @token.string_nest = '"'
        @token.string_end = '"'
        @token.string_open_count = 0
      when '0'
        case @buffer[1]
        when 'x'
          scan_hex_number
        when 'b'
          scan_bin_number
        else
          scan_number @buffer, 1
        end
      when '1', '2', '3', '4', '5', '6', '7', '8', '9'
        scan_number @buffer, 1
      when '@'
        start = @buffer
        next_char
        class_var = false
        count = 2
        if @buffer.value == '@'
          class_var = true
          count += 1
          next_char
        end
        if @buffer.value.ident_start?
          while next_char.ident_part?
            count += 1
          end
          @token.type = class_var ? :CLASS_VAR : :INSTANCE_VAR
          @token.value = String.new(start, count)
        else
          raise "unknown token: #{@buffer.value}", @line_number, @column_number
        end
      when '$'
        start = @buffer
        next_char
        if @buffer.value == '~'
          next_char
          @token.type = :GLOBAL
          @token.value = "$~"
        elsif @buffer.value.digit?
          number = @buffer.value - '0'
          while (char = next_char).digit?
            number *= 10
            number += char - '0'
          end
          @token.type = :GLOBAL_MATCH
          @token.value = number
        elsif @buffer.value.ident_start?
          count = 2
          while next_char.ident_part?
            count += 1
          end
          @token.type = :GLOBAL
          @token.value = String.new(start, count)
        else
          raise "unknown token: #{@buffer.value}", @line_number, @column_number
        end
      when 'a'
        case next_char
        when 'b'
          if next_char == 's' && next_char == 't' && next_char == 'r' && next_char == 'a' && next_char == 'c' && next_char == 't'
            return check_ident_or_keyword(:abstract, start, start_column)
          end
        when 'l'
          if next_char == 'i' && next_char == 'a' && next_char == 's'
            return check_ident_or_keyword(:alias, start, start_column)
          end
        end
        scan_ident(start, start_column)
      when 'b'
        case next_char
        when 'e'
          if next_char == 'g' && next_char == 'i' && next_char == 'n'
            return check_ident_or_keyword(:begin, start, start_column)
          end
        when 'r'
          if next_char == 'e' && next_char == 'a' && next_char == 'k'
            return check_ident_or_keyword(:break, start, start_column)
          end
        end
        scan_ident(start, start_column)
      when 'c'
        case next_char
        when 'a'
          if next_char == 's' && next_char == 'e'
            return check_ident_or_keyword(:case, start, start_column)
          end
        when 'l'
          if next_char == 'a' && next_char == 's' && next_char == 's'
            return check_ident_or_keyword(:class, start, start_column)
          end
        end
        scan_ident(start, start_column)
      when 'd'
        case next_char
        when 'e'
          if next_char == 'f'
            return check_ident_or_keyword(:def, start, start_column)
          end
        when 'o' then return check_ident_or_keyword(:do, start, start_column)
        end
        scan_ident(start, start_column)
      when 'e'
        case next_char
        when 'l'
          case next_char
          when 's'
            case next_char
            when 'e' then return check_ident_or_keyword(:else, start, start_column)
            when 'i'
              if next_char == 'f'
                return check_ident_or_keyword(:elsif, start, start_column)
              end
            end
          end
        when 'n'
          case next_char
          when 'd'
            return check_ident_or_keyword(:end, start, start_column)
          when 's'
            if next_char == 'u' && next_char == 'r' && next_char == 'e'
              return check_ident_or_keyword(:ensure, start, start_column)
            end
          when 'u'
            if next_char == 'm'
              return check_ident_or_keyword(:enum, start, start_column)
            end
          end
        end
        scan_ident(start, start_column)
      when 'f'
        case next_char
        when 'a'
          if next_char == 'l' && next_char == 's' && next_char == 'e'
            return check_ident_or_keyword(:false, start, start_column)
          end
        when 'u'
          if next_char == 'n'
            return check_ident_or_keyword(:fun, start, start_column)
          end
        end
        scan_ident(start, start_column)
      when 'i'
        case next_char
        when 'f' then return check_ident_or_keyword(:if, start, start_column)
        when 'n'
          if next_char == 'c' && next_char == 'l' && next_char == 'u' && next_char == 'd' && next_char == 'e'
            return check_ident_or_keyword(:include, start, start_column)
          end
        when 's'
          if next_char == '_' && next_char == 'a' && next_char == '?'
            return check_ident_or_keyword(:is_a?, start, start_column)
          end
        end
        scan_ident(start, start_column)
      when 'l'
        case next_char
        when 'i'
          if next_char == 'b'
            return check_ident_or_keyword(:lib, start, start_column)
          end
        end
        scan_ident(start, start_column)
      when 'm'
        case next_char
        when 'a'
          if next_char == 'c' && next_char == 'r' && next_char == 'o'
            return check_ident_or_keyword(:macro, start, start_column)
          end
        when 'o'
          case next_char
          when 'd'
            if next_char == 'u' && next_char == 'l' && next_char == 'e'
              return check_ident_or_keyword(:module, start, start_column)
            end
          end
        end
        scan_ident(start, start_column)
      when 'n'
        case next_char
        when 'e'
          if next_char == 'x' && next_char == 't'
            return check_ident_or_keyword(:next, start, start_column)
          end
        when 'i'
          case next_char
          when 'l' then return check_ident_or_keyword(:nil, start, start_column)
          end
        end
        scan_ident(start, start_column)
      when 'o'
        case next_char
        when 'f'
            return check_ident_or_keyword(:of, start, start_column)
        when 'u'
          if next_char == 't'
            return check_ident_or_keyword(:out, start, start_column)
          end
        end
        scan_ident(start, start_column)
      when 'p'
        if next_char == 't' && next_char == 'r'
          return check_ident_or_keyword(:ptr, start, start_column)
        end
        scan_ident(start, start_column)
      when 'r'
        case next_char
        when 'e'
          case next_char
          when 's'
            if next_char == 'c' && next_char == 'u' && next_char == 'e'
              return check_ident_or_keyword(:rescue, start, start_column)
            end
          when 't'
            if next_char == 'u' && next_char == 'r' && next_char == 'n'
              return check_ident_or_keyword(:return, start, start_column)
            end
          when 'q'
            if next_char == 'u' && next_char == 'i' && next_char == 'r' && next_char == 'e'
              return check_ident_or_keyword(:require, start, start_column)
            end
          end
        end
        scan_ident(start, start_column)
      when 's'
        if next_char == 't' && next_char == 'r' && next_char == 'u' && next_char == 'c' && next_char == 't'
          return check_ident_or_keyword(:struct, start, start_column)
        end
        scan_ident(start, start_column)
      when 't'
        case next_char
        when 'h'
          if next_char == 'e' && next_char == 'n'
            return check_ident_or_keyword(:then, start, start_column)
          end
        when 'r'
          case next_char
          when 'u'
            if next_char == 'e'
              return check_ident_or_keyword(:true, start, start_column)
            end
          end
        when 'y'
          if next_char == 'p' && next_char == 'e'
            return check_ident_or_keyword(:type, start, start_column)
          end
        end
        scan_ident(start, start_column)
      when 'u'
        if next_char == 'n'
          case next_char
          when 'i'
            if next_char == 'o' && next_char == 'n'
              return check_ident_or_keyword(:union, start, start_column)
            end
          when 'l'
            if next_char == 'e' && next_char == 's' && next_char == 's'
              return check_ident_or_keyword(:unless, start, start_column)
            end
          end
        end
        scan_ident(start, start_column)
      when 'w'
        case next_char
        when 'h'
          case next_char
          when 'e'
            if next_char == 'n'
              return check_ident_or_keyword(:when, start, start_column)
            end
          when 'i'
            if next_char == 'l' && next_char == 'e'
              return check_ident_or_keyword(:while, start, start_column)
            end
          end
        end
        scan_ident(start, start_column)
      when 'y'
        if next_char == 'i' && next_char == 'e' && next_char == 'l' && next_char == 'd'
          return check_ident_or_keyword(:yield, start, start_column)
        end
        scan_ident(start, start_column)
      when '_'
        case next_char
        when '_'
          case next_char
          when 'D'
            if next_char == 'I' && next_char == 'R' next_char == '_' && next_char == '_'
              if @buffer[1].ident_part_or_end?
                scan_ident(start, start_column)
              else
                next_char
                filename = @filename
                @token.type = :STRING
                @token.value = filename.is_a?(String) ? File.dirname(filename) : "-"
                return @token
              end
            end
          when 'F'
            if next_char == 'I' && next_char == 'L' && next_char == 'E' && next_char == '_' && next_char == '_'
              if @buffer[1].ident_part_or_end?
                scan_ident(start, start_column)
              else
                next_char
                @token.type = :STRING
                @token.value = @filename
                return @token
              end
            end
          when 'L'
            if next_char == 'I' && next_char == 'N' && next_char == 'E' && next_char == '_' && next_char == '_'
              if @buffer[1].ident_part_or_end?
                scan_ident(start, start_column)
              else
                next_char
                @token.type = :INT
                @token.value = @line_number
                return @token
              end
            end
          end
        else
        end
        scan_ident(start, start_column)
      else
        if 'A' <= @buffer.value <= 'Z'
          start = @buffer
          count = 1
          while next_char.ident_part?
            count += 1
          end
          @token.type = :CONST
          @token.value = String.new(start, count)
        elsif ('a' <= @buffer.value <= 'z') || @buffer.value == '_'
          next_char
          scan_ident(start, start_column)
        else
          raise "unknown token: #{@buffer.value}", @line_number, @column_number
        end
      end

      @token
    end

    def check_ident_or_keyword(symbol, start, start_column)
      if @buffer[1].ident_part_or_end?
        scan_ident(start, start_column)
      else
        next_char
        @token.type = :IDENT
        @token.value = symbol
      end
      @token
    end

    def scan_ident(start, start_column)
      while @buffer.value.ident_part?
        next_char
      end
      case @buffer.value
      when '!', '?'
        next_char
      when '$'
        next_char
        while @buffer.value.digit?
          next_char
        end
      end
      @token.type = :IDENT
      @token.value = String.new(start, @column_number - start_column)
      @token
    end

    def scan_number(start, count)
      @token.type = :NUMBER

      has_underscore = false

      while true
        char = next_char
        if char.digit?
          count += 1
        elsif char == '_'
          count += 1
          has_underscore = true
        else
          break
        end
      end

      case @buffer.value
      when '.'
        if @buffer[1].digit?
          count += 1

          while true
            char = next_char
            if char.digit?
              count += 1
            elsif char == '_'
              count += 1
              has_underscore = true
            else
              break
            end
          end

          if @buffer.value == 'e' || @buffer.value == 'E'
            count += 1
            next_char

            if @buffer.value == '+' || @buffer.value == '-'
              count += 1
              next_char
            end

            while true
              if @buffer.value.digit?
                count += 1
              elsif @buffer.value == '_'
                count += 1
                has_underscore = true
              else
                break
              end
              next_char
            end
          end

          if @buffer.value == 'f' || @buffer.value == 'F'
            consume_float_suffix :f64
          else
            @token.number_kind = :f64
          end
        else
          @token.number_kind = :i32
        end
      when 'e', 'E'
        count += 1
        next_char

        if @buffer.value == '+' || @buffer.value == '-'
          count += 1
          next_char
        end

        while true
          if @buffer.value.digit?
            count += 1
          elsif @buffer.value == '_'
            count += 1
            has_underscore = true
          else
            break
          end
          next_char
        end

        if @buffer.value == 'f' || @buffer.value == 'F'
          consume_float_suffix :f64
        else
          @token.number_kind = :f64
        end
      when 'f', 'F'
        consume_float_suffix :i32
      when 'i'
        consume_int_suffix :i32
      when 'u'
        consume_uint_suffix :u32
      else
        @token.number_kind = :i32
      end

      string_value = String.new(start, count)
      string_value = string_value.delete('_') if has_underscore
      @token.value = string_value
    end

    def scan_hex_number(multiplier = 1)
      @token.type = :NUMBER
      num = 0
      next_char

      while true
        char = next_char
        if char.digit?
          num = num * 16 + (char - '0')
        elsif ('a' <= char <= 'f')
          num = num * 16 + 10 + (char - 'a')
        elsif ('A' <= char <= 'F')
          num = num * 16 + 10 + (char - 'A')
        elsif char == '_'
        else
          break
        end
      end

      num *= multiplier

      case @buffer.value
      when 'i'
        consume_int_suffix :i32
      when 'u'
        consume_uint_suffix :u32
      else
        @token.number_kind = :i32
      end

      @token.value = num.to_s
    end

    def scan_bin_number(multiplier = 1)
      @token.type = :NUMBER
      num = 0
      next_char

      while true
        case next_char
        when '0'
          num *= 2
        when '1'
          num = num * 2 + 1
        when '_'
          # Nothing
        else
          break
        end
      end

      num *= multiplier

      @token.value = num.to_s
      @token.number_kind = :i32
    end

    def consume_int_suffix(default)
      if @buffer[1] == '8'
        next_char
        next_char
        @token.number_kind = :i8
      elsif @buffer[1] == '1' && @buffer[2] == '6'
        next_char
        next_char
        next_char
        @token.number_kind = :i16
      elsif @buffer[1] == '3' && @buffer[2] == '2'
        next_char
        next_char
        next_char
        @token.number_kind = :i32
      elsif @buffer[1] == '6' && @buffer[2] == '4'
        next_char
        next_char
        next_char
        @token.number_kind = :i64
      else
        @token.number_kind = default
      end
    end

    def consume_uint_suffix(default)
      if @buffer[1] == '8'
        next_char
        next_char
        @token.number_kind = :u8
      elsif @buffer[1] == '1' && @buffer[2] == '6'
        next_char
        next_char
        next_char
        @token.number_kind = :u16
      elsif @buffer[1] == '3' && @buffer[2] == '2'
        next_char
        next_char
        next_char
        @token.number_kind = :u32
      elsif @buffer[1] == '6' && @buffer[2] == '4'
        next_char
        next_char
        next_char
        @token.number_kind = :u64
      else
        @token.number_kind = default
      end
    end

    def consume_float_suffix(default)
      if @buffer[1] == '3' && @buffer[2] == '2'
        next_char
        next_char
        next_char
        @token.number_kind = :f32
      elsif @buffer[1] == '6' && @buffer[2] == '4'
        next_char
        next_char
        next_char
        @token.number_kind = :f64
      else
        @token.number_kind = default
      end
    end

    def next_string_token(string_nest, string_end, string_open_count)
      case @buffer.value
      when '\0'
        raise "unterminated string literal", @line_number, @column_number
      when string_end
        next_char
        if string_open_count == 0
          @token.type = :STRING_END
        else
          @token.type = :STRING
          @token.value = string_end.to_s
          @token.string_open_count = string_open_count - 1
        end
      when string_nest
        next_char
        @token.type = :STRING
        @token.value = string_nest.to_s
        @token.string_open_count = string_open_count + 1
      when '\\'
        case char = next_char
        when 'n'
          string_token_escape_value "\n"
        when 'r'
          string_token_escape_value "\r"
        when 't'
          string_token_escape_value "\t"
        when 'v'
          string_token_escape_value "\v"
        when 'f'
          string_token_escape_value "\f"
        when 'e'
          string_token_escape_value "\e"
        when 'x'
          value = consume_hex_escape
          next_char
          @token.type = :STRING
          @token.value = value.chr.to_s
        when '0', '1', '2', '3', '4', '5', '6', '7', '8'
          char_value = consume_octal_escape(char)
          next_char
          @token.type = :STRING
          @token.value = char_value.chr.to_s
        else
          @token.type = :STRING
          @token.value = @buffer.value.to_s
          next_char
        end
      when '#'
        if @buffer[1] == '{'
          next_char
          next_char
          @token.type = :INTERPOLATION_START
        else
          next_char
          @token.type = :STRING
          @token.value = "#"
        end
      when '\n'
        next_char
        @column_number = 1
        @line_number += 1
        @token.type = :STRING
        @token.value = "\n"
      else
        start = @buffer
        count = 0
        while @buffer.value != string_end &&
              @buffer.value != string_nest &&
              @buffer.value != '\0' &&
              @buffer.value != '\\' &&
              @buffer.value != '#' &&
              @buffer.value != '\n'
          next_char
          count += 1
        end

        @token.type = :STRING
        @token.value = String.new(start, count)
      end

      @token
    end

    def consume_octal_escape(char)
      char_value = char - '0'
      count = 1
      while count <= 3 && '0' <= @buffer[1] && @buffer[1] <= '8'
        next_char
        char_value = char_value * 8 + (@buffer.value - '0')
        count += 1
      end
      char_value
    end

    def consume_hex_escape
      after_x = next_char
      if '0' <= after_x <= '9'
        value = after_x - '0'
      elsif 'a' <= after_x <= 'f'
        value = 10 + (after_x - 'a')
      elsif 'A' <= after_x <= 'F'
        value = 10 + (after_x - 'A')
      else
        raise "invalid hex escape", @line_number, @column_number
      end

      value = value.not_nil!

      after_x2 = @buffer[1]
      if '0' <= after_x2 <= '9'
        value = 16 * value + (after_x2 - '0')
        next_char
      elsif 'a' <= after_x2 <= 'f'
        value = 16 * value + (10 + (after_x2 - 'a'))
        next_char
      elsif 'A' <= after_x2 <= 'F'
        value = 16 * value + (10 + (after_x2 - 'A'))
        next_char
      end

      value
    end

    def string_token_escape_value(value)
      next_char
      @token.type = :STRING
      @token.value = value
    end

    def string_start_pair(string_nest, string_end)
      next_char
      @token.type = :STRING_START
      @token.string_nest = string_nest
      @token.string_end = string_end
      @token.string_open_count = 0
    end

    def next_string_array_token
      while true
        if @buffer.value == '\n'
          next_char
          @column_number = 1
          @line_number += 1
        elsif @buffer.value.whitespace?
          next_char
        else
          break
        end
      end

      if @buffer.value == ')'
        next_char
        @token.type = :STRING_ARRAY_END
        return @token
      end

      start = @buffer
      count = 0
      while !@buffer.value.whitespace? && @buffer.value != '\0' && @buffer.value != ')'
        next_char
        count += 1
      end

      @token.type = :STRING
      @token.value = String.new(start, count)

      @token
    end

    def next_char_no_column_increment
      @buffer += 1
      @buffer.value
    end

    def next_char
      @column_number += 1
      next_char_no_column_increment
    end

    def next_char(token_type)
      next_char
      @token.type = token_type
    end

    def reset_token
      @token.value = nil
      @token.line_number = @line_number
      @token.column_number = @column_number
      @token.filename = @filename
    end

    def next_comes_uppercase
      i = 0
      while @buffer[i].whitespace?
        i += 1
      end
      return 'A' <= @buffer[i] <= 'Z'
    end

    def next_token_skip_space
      next_token
      skip_space
    end

    def next_token_skip_space_or_newline
      next_token
      skip_space_or_newline
    end

    def next_token_skip_statement_end
      next_token
      skip_statement_end
    end

    def skip_space
      while @token.type == :SPACE
        next_token
      end
    end

    def skip_space_or_newline
      while (@token.type == :SPACE || @token.type == :NEWLINE)
        next_token
      end
    end

    def skip_statement_end
      while (@token.type == :SPACE || @token.type == :NEWLINE || @token.type == :";")
        next_token
      end
    end

    def raise(message, line_number = @line_number, column_number = @token.column_number, filename = @filename)
      ::raise Crystal::SyntaxException.new(message, line_number, column_number, filename)
    end

    def raise(message, location : Location)
      raise message, location.line_number, location.column_number, location.filename
    end
  end
end
