=begin
also need

%extend Depager::LookAheadLexer ('./plugins/lalex.rb')
%extend Depager::ErrHandle ('./plugins/errhandle.rb')
%extend Depager::Key ('./panicmode/keys.rb')
%extend Depager::AfterErrContinue ('./plugins/aftererrcontinue.rb')

=end

class Depager::LALR::ErrHandleParser < Depager::LALR::AdvancedParser; end

class PanicMode_Recovery < Depager::LALR::ErrHandleParser
  
  DEBUG = true
  
  def initialize *args
    super
    @keys = basis.class::PanicMode_KEYS.collect{|k| nonterm_to_int[k]}.compact
  end
  def errhandle
    super

    removed = [] if DEBUG
    
    loop do
      @keys.each do |key|
        v = goto_table[stack.last][key]
        next unless v
        expected = expected_tokens v
        index = 0
        index += 1 while (la = basis.lex_read(index)) && !expected.include?(la) && la != term_to_int[nil]
        if la
          stack << [key, :NT] << v
          index.times do

            removed << int_to_term[basis.lex_read(0)] if DEBUG
            
            basis.lex_delete(0)
          end

          puts "succeeded: #{int_to_nonterm[key]},\n  removed: #{removed}" if DEBUG
          
          return
        end
      end
      if stack.last == 0 # stack empty: Not found keys

        puts "failed" if DEBUG

        exit 1
      end

      if DEBUG
        key = stack[-2][1] == :NT ? int_to_nonterm[stack[-2][0]] : int_to_term[stack[-2][0]]
        removed.unshift key
      end
          
      stack.pop; stack.pop
    end
  end
end
