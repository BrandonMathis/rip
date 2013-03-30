require 'parslet'
require 'pathname'

module Rip::Compiler
  class Parser < Parslet::Parser
    root(:lines)


    rule(:whitespace) { space | line_break }
    rule(:whitespaces) { whitespace.repeat(1) }
    rule(:whitespaces?) { whitespaces.maybe }

    rule(:space) { str(' ') | str("\t") }
    rule(:spaces) { space.repeat(1) }
    rule(:spaces?) { spaces.maybe }

    rule(:line_break) { str("\r\n") | str("\n") | str("\r") }
    rule(:line_breaks) { line_break.repeat(1) }
    rule(:line_breaks?) { line_breaks.maybe }


    rule(:expression_terminator) { semicolon | line_break }
    rule(:expression_terminator?) { expression_terminator.maybe }


    rule(:eof) { any.absent? }

    rule(:dot) { str('.') }
    rule(:comma) { str(',') }
    rule(:semicolon) { str(';') }
    rule(:colon) { str(':') }
    rule(:pound) { str('#') }
    rule(:underscore) { str('_') }
    rule(:equals) { str('=') }

    rule(:slash_back) { str('\\') }
    rule(:slash_forward) { str('/') }

    rule(:angled_open) { str('<') }
    rule(:angled_close) { str('>') }

    rule(:brace_open) { str('{') }
    rule(:brace_close) { str('}') }

    rule(:bracket_open) { str('[') }
    rule(:bracket_close) { str(']') }

    rule(:parenthesis_open) { str('(') }
    rule(:parenthesis_close) { str(')') }

    rule(:quote_single) { str('\'') }
    rule(:quote_double) { str('"') }
    rule(:backtick) { str('`') }


    rule(:lines) { line.repeat }
    rule(:line) { whitespaces | expression | comment }

    rule(:comment) { pound >> (line_break.absent? >> any).repeat.as(:comment) >> (line_break | eof) }

    rule(:expression) { expression_base >> spaces? >> expression_terminator? }

    rule(:expression_base) { (keyword.as(:keyword) >> spaces >> (reference_assignment | phrase).as(:payload)) | keyword.as(:keyword) | reference_assignment | phrase }

    rule(:keyword) { %i[exit raise return].map { |kw| str(kw.to_s).as(kw) }.inject(:|) }


    rule(:reference_assignment) { (reference >> whitespaces? >> equals >> whitespaces? >> phrase).as(:reference_assignment) }

    rule(:phrase) { (phrase_base >> (key_value_pair | range | operator_invocation | regular_invocation | index_invocation | property).repeat).as(:phrase) }


    rule(:regular_invocation) { multiple_arguments.as(:regular_invocation) }

    rule(:index_invocation) { (bracket_open >> csv(phrase).as(:arguments) >> bracket_close).as(:index_invocation) }

    rule(:key_value_pair) { (whitespaces? >> colon >> whitespaces? >> phrase.as(:value)).as(:key_value_pair) }

    rule(:range) { (whitespaces? >> dot >> dot >> dot.maybe.as(:exclusivity) >> phrase.as(:end)).as(:range) }

    rule(:operator_invocation) { (whitespaces >> reference.as(:operator) >> whitespaces >> phrase.as(:argument)).as(:operator_invocation) }

    rule(:property) { dot >> property_name.as(:property_name) }
    rule(:property_name) { reference | (bracket_open >> bracket_close) }

    rule(:phrase_base) do
      condition_block_sequence.as(:block_sequence) |
      exception_block_sequence.as(:block_sequence) |
      class_block |
      lambda_block |
      switch_block |
      object |
      parenthesis_open >> phrase >> parenthesis_close
    end


    rule(:condition_block_sequence) { (if_block | unless_block) >> whitespaces? >> else_block.maybe }

    rule(:exception_block_sequence) { try_block >> (whitespaces? >> catch_block).repeat >> whitespaces? >> finally_block.maybe }

    rule(:lambda_block) { ((str('->').as(:dash_rocket) | str('=>').as(:fat_rocket)) >> spaces? >> parameters.as(:parameters).maybe >> block_body).as(:lambda_block) }

    rule(:class_block) { (str('class').as(:class) >> spaces? >> multiple_arguments.maybe >> block_body).as(:class_block) }
    rule(:case_block)  { (str('case').as(:case)   >> spaces? >> multiple_arguments       >> block_body).as(:case_block) }

    rule(:catch_block)  { (str('catch').as(:catch)   >> spaces? >> single_argument >> block_body).as(:catch_block) }
    rule(:if_block)     { (str('if').as(:if)         >> spaces? >> single_argument >> block_body).as(:if_block) }
    rule(:unless_block) { (str('unless').as(:unless) >> spaces? >> single_argument >> block_body).as(:unless_block) }
    rule(:switch_block) { (str('switch').as(:switch) >> spaces? >> single_argument >> block_body_switch).as(:switch_block) }

    rule(:try_block)     { (str('try').as(:try)         >> block_body).as(:try_block) }
    rule(:finally_block) { (str('finally').as(:finally) >> block_body).as(:finally_block) }
    rule(:else_block)    { (str('else').as(:else)       >> block_body).as(:else_block) }

    rule(:parameters) { parenthesis_open >> whitespaces? >> csv(optional_parameter | required_parameter) >> whitespaces? >> parenthesis_close }
    rule(:required_parameter) { reference }
    rule(:optional_parameter) { reference_assignment }

    rule(:multiple_arguments) { parenthesis_open >> whitespaces? >> csv(phrase).as(:arguments) >> whitespaces? >> parenthesis_close }

    rule(:single_argument) { parenthesis_open >> whitespaces? >> phrase.as(:argument) >> whitespaces? >> parenthesis_close }

    rule(:block_body) { whitespaces? >> brace_open >> whitespaces? >> lines.as(:body) >> whitespaces? >> brace_close }
    rule(:block_body_switch) { (case_block.repeat(1) >> whitespaces? >> else_block.maybe).as(:body) }

    # TODO literals for heredoc
    # TODO literals for datetime, date, time, version (maybe)
    # TODO literals for unit
    rule(:object) { number | character | string | regular_expression | map | list | reference }


    # WARNING order is important here: decimal must be before integer or the integral part of
    #   a decimal could be interpreted as a integer followed by a decimal starting with a dot
    rule(:number) { sign.maybe >> (decimal | integer) }

    rule(:decimal) { (digits.maybe >> dot >> digits).as(:decimal) }
    rule(:integer) { digits.as(:integer) }

    rule(:sign) { match['+-'].as(:sign) }

    rule(:digit) { match['0-9'] }
    rule(:digits) { digit.repeat(1) >> (underscore.maybe >> digit.repeat(1)).repeat }


    rule(:character) { backtick >> (escape_advanced | character_legal).as(:character) }
    rule(:character_legal) { digit | word_legal }


    rule(:escape_simple)   { escape_token_quote_single  | escape_token_slash_back }
    rule(:escape_regex)    { escape_token_slash_forward | escape_token_slash_back }
    rule(:escape_advanced) { escape_token_unicode       | escape_token_any }

    rule(:escape_token_quote_single)  { slash_back >> quote_single.as(:escaped_quote_single) }
    rule(:escape_token_double)        { slash_back >> quote_double.as(:escaped_quote_double) }
    rule(:escape_token_slash_back)    { slash_back >> slash_back.as(:escaped_slash_back) }
    rule(:escape_token_slash_forward) { slash_back >> slash_forward.as(:escaped_slash_forward) }
    rule(:escape_token_unicode)       { slash_back >> str('u') >> match['0-9a-f'].repeat(4, 4).as(:escaped_unicode) }
    rule(:escape_token_any)           { slash_back >> any.as(:escaped_any) }


    rule(:string) { string_symbol | string_single | string_double }

    rule(:string_symbol) { colon >> (escape_advanced | character_legal.as(:raw_string)).repeat(1).as(:string) }

    rule(:string_single) { string_parser(quote_single, escape_simple) }
    rule(:string_double) { string_parser(quote_double, escape_advanced | interpolation) }

    rule(:regular_expression) { string_parser(slash_forward, escape_regex | interpolation, :regex, :raw_regex) }


    rule(:interpolation) { interpolation_start >> (interpolation_end.absent? >> line.repeat(1)).repeat.as(:interpolation) >> interpolation_end }
    rule(:interpolation_start) { pound >> brace_open }
    rule(:interpolation_end) { brace_close }


    rule(:reference) { (word | slash_forward).repeat(1).as(:reference) }

    rule(:word) { word_legal >> (word_legal | digit).repeat }
    rule(:word_legal) { match['^\d\s\`\'",.:;#\/\\()<>\[\]{}'] }


    rule(:map) { brace_open >> whitespaces? >> csv(phrase).as(:map) >> whitespaces? >> brace_close }

    rule(:list) { bracket_open >> whitespaces? >> csv(phrase).as(:list) >> whitespaces? >> bracket_close }


    protected

    # "borrowed" from http://jmettraux.wordpress.com/2011/05/11/parslet-and-json/
    def csv(value)
      _value = whitespaces? >> value >> whitespaces?
      (_value >> (comma >> _value).repeat).repeat(0, 1)
    end

    def string_parser(delimiter, inner_special, delimited_flag = :string, any_flag = :raw_string)
      delimiter >> (delimiter.absent? >> (inner_special | any.as(any_flag))).repeat.as(delimited_flag) >> delimiter
    end
  end
end