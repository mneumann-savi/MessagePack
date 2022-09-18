require 'yaml'

TYPES = %w(nil bool number string binary bignum ext array map timestamp)
$IT_COUNT = Hash.new(0)

module MessagePack
  class Binary < Struct.new(:hexstr); end
  class Ext < Struct.new(:kind, :hexstr); end
  class Timestamp < Struct.new(:hi, :lo); end
end

def convert_tests(tests, title, out=[])
  for test in tests
    expected_value = get_expected_value(test)
    for fixture in (test['msgpack'] || raise)
      gen_test_fixture(expected_value, fixture, title, out)
    end
  end
  out
end

def gen_test_fixture(expected_value, input, title, out)
  out << %|  :it "reads #{title} (#{$IT_COUNT[title] += 1})"|
  out << %|    data = b"#{hexstr_to_bytes(input)}"|
  out << %|    rd   = MessagePack.Reader.new(data)|

  gen_test_value(expected_value, out)
  out << %|    assert: rd.is_exhausted|

  out << %||
end

def gen_test_value(expected_value, out)
  case expected_value
  in nil
    out << %|    assert: rd.read_nil! <: None|
  in true
    out << %|    assert: rd.read_bool! == True|
  in false
    out << %|    assert: rd.read_bool! == False|
  in Integer => n
    asserts = []
    asserts << "rd.read_uint! == U64[#{n}]" if n >= 0
    asserts << "rd.read_int! == I64[#{n}]" if n.negative? or n < 2**63
    asserts << "rd.read_f64! == F64[#{n}.0]" if n.to_f.to_i == n
    gen_asserts(asserts, out)
  in Float => n
    asserts = []
    asserts << "rd.read_f64! == F64[#{n}]"
    if n.truncate.to_f == n
      n = n.truncate
      asserts << "rd.read_uint! == U64[#{n}]" if n >= 0
      asserts << "rd.read_int! == I64[#{n}]" if n.negative? or n < 2**63
    end
    gen_asserts(asserts, out)

  in String => s
    out << %|    assert: rd.read_string! == #{s.inspect}|
  in MessagePack::Binary => bin
    out << %|    assert: rd.read_binary! == b"#{hexstr_to_bytes(bin.hexstr)}"|
  in MessagePack::Ext => ext
    out << %|    assert no_error: (|
    out << %|      actual = rd.read_ext!|
    out << %|      assert: actual.first == I8[#{ext.kind}]|
    out << %|      assert: actual.second == b"#{hexstr_to_bytes(ext.hexstr)}"|
    out << %|    )|
    # out << %|    assert: rd.read_ext! == Pair(I8, Bytes).new(I8[#{kind}], b"#{hexstr_to_bytes(bin)}")|
  in MessagePack::Timestamp => ts
    out << %|    assert no_error: (|
    out << %|      ts = rd.read_timestamp!|
    out << %|      assert: ts.hi == I64[#{ts.hi}]|
    out << %|      assert: ts.lo == U64[#{ts.lo}]|
    out << %|    )|
  in Array => ary
    out << %|    assert: rd.read_array_head! == USize[#{ary.size}]|
  
    for value in ary
      gen_test_value(value, out)
    end
  in Hash => map
    out << %|    assert: rd.read_map_head! == USize[#{map.size}]|

    for key, value in map 
      gen_test_value(key, out)
      gen_test_value(value, out)
    end
  else
    raise
  end
end

def gen_asserts(asserts, out)
  case asserts
  in []
    raise
  in [assert]
    out << %|    assert: #{assert}|
  in [*asserts]
    out << %|    rd.mark_here|
    asserts.each_with_index do |assert, i|
      out << %|    rd.rewind_to_mark| if i > 0
      out << %|    assert: #{assert}|
    end
  end
end

def get_expected_value(test)
  for ty in TYPES
    if test.has_key? ty
      value = test[ty]
      case ty
      when 'nil', 'bool', 'number', 'string', 'array', 'map'
        return value
      when 'binary'
        return MessagePack::Binary.new(value)
      when 'bignum'
        return Integer(value)
      when 'ext'
        return MessagePack::Ext.new(*value)
      when 'timestamp'
        return MessagePack::Timestamp.new(*value)
      end
    end
  end
  raise "Test type not recognized: #{test}"
end

def hexstr_to_bytes(hexstr)
  hexstr.split('-').map {|h| "\\x#{h}"}.join
end

if __FILE__ == $0
  out = []
  out << %|:class MessagePack.Reader.Spec|
  out << %|  :is Spec|
  out << %|  :const describes: "MessagePack.Reader"|
  out << %||

  for file in Dir["msgpack-test-suite/src/*.yaml"].sort_by{|f| File.basename(f).split('.').first.to_i}
    begin
      title = File.basename(file).split('.')[1].split('-').join(' ')
      out.append(*convert_tests(YAML.load_file(file), title))
    rescue => ex
      STDERR.puts "FAILED: #{file} (#{ex})"
    end
  end

  STDOUT << out.join("\n")
end
