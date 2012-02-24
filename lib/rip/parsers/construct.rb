require 'parslet'

require 'rip'
require 'rip/parsers/helpers'
require 'rip/parsers/object'

module Rip::Parsers
  module Construct
    include Parslet
    include Rip::Parsers::Helpers
    include Rip::Parsers::Object

    [:if, :unless].each do |cond|
      name = "#{cond}_condition".to_sym
      rule(name) { str(cond) >> spaces? >> binary_condition }
    end

    rule(:binary_condition) { surround_with('(', object.as(:binary_condition), ')') }

    #---------------------------------------------

    rule(:exiter) { exit_keyword | return_keyword | throw_keyword | break_keyword | next_keyword }

    [:exit, :return, :throw, :break, :next].each do |keyword|
      name = "#{keyword}_keyword".to_sym
      rule(name) { str(keyword).as(name) }
    end
  end
end