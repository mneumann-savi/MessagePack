require 'yaml'

TYPES = %w(nil bool number string binary bignum)
$IT_COUNT = Hash.new(0)

def convert_tests(tests, title, out=[])
  for test in tests
    expected_value, ty = get_expected_value_and_type(test)
    for fixture in (test['msgpack'] || raise)
      gen_test_fixture(ty, expected_value, fixture, title, out)
    end
  end
  out
end

def gen_test_fixture(ty, expected_value, input, title, out)
  out << %|  :it "reads #{title} (#{$IT_COUNT[title] += 1})"|
  out << %|    data = b"#{hexstr_to_bytes(input)}"|
  out << %|    rd   = MessagePack.Reader.new(data)|

  case [ty, expected_value]
  in ['nil', nil]
    out << %|    assert: rd.read_nil! <: None|
  in ['bool', true]
    out << %|    assert: rd.read_bool! == True|
  in ['bool', false]
    out << %|    assert: rd.read_bool! == False|
  in ['number', Integer => n]
    read_fn, savi_type = if n.negative?
                           ['read_int', 'I64']
                         else
                           ['read_uint', 'U64']
                         end
    out << %|    assert: rd.#{read_fn}! == #{savi_type}[#{n}]|
  in ['bignum', String => bign]
    n = Integer(bign)
    read_fn, savi_type = if n.negative?
                           ['read_int', 'I64']
                         else
                           ['read_uint', 'U64']
                         end
    out << %|    assert: rd.#{read_fn}! == #{savi_type}[#{n}]|
  in ['number', Float => n]
    out << %|    assert: rd.read_f64! == F64[#{n}]|
  in ['string', String => s]
    out << %|    assert: rd.read_string! == #{s.inspect}|
  in ['binary', String => bin]
    out << %|    assert: rd.read_binary! == b"#{hexstr_to_bytes(bin)}"|
  else
    raise
  end

  out << %||
end

def get_expected_value_and_type(test)
  for ty in TYPES
    return [test[ty], ty] if test.has_key? ty
  end
  raise
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
    rescue
      STDERR.puts "FAILED: #{file}"
    end
  end

  STDOUT << out.join("\n")
end
