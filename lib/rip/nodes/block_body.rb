module Rip::Nodes
  class BlockBody < Base
    attr_reader :statements

    def initialize(location, statements)
      super(location)
      @statements = statements
    end

    def ==(other)
      super &&
        (statements == other.statements)
    end

    def to_debug(level = 0)
      statements.inject([]) do |reply, statement|
        reply + statement.to_debug(level)
      end
    end
  end
end
