require 'parslet'

require 'rip'
require 'rip/parsers/helpers'
require 'rip/parsers/keyword'
require 'rip/parsers/reference'

module Rip::Parsers
  module Object
    include Parslet
    include Rip::Parsers::Helpers
    include Rip::Parsers::Keyword
    include Rip::Parsers::Reference

    rule(:object) { (recursive_object | simple_object | structural_object | regular_invocation | reference) >> property.repeat.as(:property_chain) }

    rule(:property) { str('.') >> (regular_invocation | reference) }

    rule(:simple_object) { numeric | character | string | regular_expression }

    rule(:recursive_object) { key_value_pair | range | hash_literal | list }

    rule(:structural_object) { class_literal | lambda_literal }

    #---------------------------------------------

    # WARNING order is important here: decimal must be before integer or the integral part of a decimal could be interpreted as a integer followed by a decimal starting with a '.' (dot)
    rule(:numeric) { decimal | integer }

    rule(:decimal) { (sign.maybe >> digits.maybe >> str('.') >> digits).as(:decimal) }

    rule(:integer) { (sign.maybe >> digits).as(:integer) }

    rule(:sign) { match['+-'] }

    rule(:digit) { match['0-9'] }

    # allow _ to be used to group digits ( 3_423_752 )
    # _ may not come first or last
    rule(:digits) { digit.repeat(1) >> (str('_').maybe >> digit.repeat(1)).repeat }

    #---------------------------------------------

    # FIXME should match any single printable unicode character
    rule(:character) { str('`') >> match['0-9a-zA-Z_'].as(:character) }

    #---------------------------------------------

    # NOTE a string is just a list with characters allowed in it
    rule(:string) { symbol_string | single_quoted_string | double_quoted_string | here_doc }

    # FIXME should match most (all?) non-whitespace characters
    rule(:symbol_string) { str(':') >> match['a-zA-Z_'].repeat(1).as(:string) }

    rule(:single_quoted_string) { str('\'') >> (str('\'').absent? >> any).repeat.as(:string) >> str('\'') }

    rule(:double_quoted_string) { str('"') >> (str('"').absent? >> any).repeat.as(:string) >> str('"') }

    rule(:here_doc) do
      label = match['A-Z_'].repeat(1)
      start = str('<<') >> label.as(:here_doc_start) >> eol
      content = (label.absent? >> any).repeat.as(:string)
      finish = label.as(:here_doc_end) >> eol.maybe
      start >> content >> finish
    end

    #---------------------------------------------

    # TODO expand regular expression pattern
    rule(:regular_expression) { str('/') >> (str('/').absent? >> any).repeat.as(:regex) >> str('/') }

    #---------------------------------------------

    # TODO allow type restriction
    # FIXME allow more types to be used as the key
    rule(:key_value_pair) { (simple_object | reference).as(:key) >> spaces? >> str(':') >> spaces? >> object.as(:value) }

    rule(:range) do
      rangable_object = integer | character | reference
      rangable_object.as(:start) >> str('..') >> str('.').maybe.as(:exclusivity) >> rangable_object.as(:end)
    end

    # NOTE a hash is just a list with only key_value_pairs allowed in it
    # TODO allow type restriction (to be passed on to key value pairs and list)
    rule(:hash_literal) { surround_with('{', thing_list(key_value_pair | reference).as(:hash), '}') }

    # TODO allow type restriction
    rule(:list) { surround_with('[', thing_list(object).as(:list), ']') }

    #---------------------------------------------

    rule(:class_literal) do
      ancestors = surround_with('(', thing_list(class_literal | reference).as(:ancestors).maybe, ')')
      (class_keyword >> whitespaces? >> ancestors.maybe >> whitespaces? >> block).as(:class)
    end

    rule(:lambda_literal) do
      parameters = surround_with('(', thing_list(assignment | simple_reference.as(:reference)).as(:parameters), ')')
      (lambda_keyword >> whitespaces? >> parameters.maybe >> whitespaces? >> block).as(:lambda)
    end
  end
end
