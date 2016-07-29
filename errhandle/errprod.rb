=begin
also need

%extend Depager::LookAheadLexer ('./plugins/lalex.rb')
%extend Depager::ErrHandle ('./plugins/errhandle.rb')
%extend Depager::AfterErrContinue ('./plugins/aftererrcontinue.rb')

=end

class Depager::LALR::ErrHandleParser < Depager::LALR::AdvancedParser; end

class Error_Production < Depager::LALR::ErrHandleParser
  def initialize *args
    super
    yyerrok
  end
  def yyerrok
    @yyerrcnt = 0
    @yyerrshow = true
  end
  def yyerror
    errhandle
  end
  def errhandle
    super
    @yyerrcnt = 3
    @yyerrshow = false
    action = nil
    loop do
      action = action_table[stack.last][term_to_int[:ERROR]]
      break if action && action != ACC
      exit 1 if stack.last == 0 # stack empty: Not found error-tokens
      stack.pop 2
    end
    basis.lex_insert token(:ERROR), 0
    expected = expected_tokens get_reduced_state action
    basis.lex_delete(1) while (la = basis.lex_read(1)) && !expected.include?(la) && (la != term_to_int[nil] || exit(1))
    exit 1 unless la
  end
  def before_error
    basis.errshow = @yyerrshow
  end
  def after_shift
    super
    if lookahead[0] != term_to_int[:ERROR] && @yyerrcnt != 0
      @yyerrcnt -= 1
      @yyerrshow = true if @yyerrcnt == 0
    end
  end
  def get_reduced_state action
    if action < 0
      temp_stack = stack.clone
      while action < 0
        r, x = reduce_table[-action]
        temp_stack.pop x * 2
        action = goto_table[temp_stack.last][r]
        temp_stack << [r, :NT] << action
      end
    end
    action
  end
end

class Depager::LALR::Parser
  def yyerrok
    @inside.yyerrok
  end
  def yyerror
    @inside.yyerror
  end
end
