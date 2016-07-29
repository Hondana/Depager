=begin
also need

%extend Depager::LookAheadLexer ('./plugins/lalex.rb')
%extend Depager::ErrHandle ('./plugins/errhandle.rb')
%extend Depager::MckenzieCost ('./mckenziecost.rb')
%extend Depager::AfterErrContinue ('./aftererrcontinue.rb')

=end
class Depager::LALR::ErrHandleParser < Depager::LALR::AdvancedParser; end

class Mckenzie_Recovery < Depager::LALR::ErrHandleParser
  #
  DEBUG = true
  AFTER_READ = 3
  #
  def initialize *args
    super
    @recovering = 0
    @icost = [nil, nil]
    @dcost = [nil, nil]
    each_term do |i|
      @icost[i] = basis.class::INSERTION_COST[int_to_term[i]]
      @dcost[i] = basis.class::DELETION_COST[int_to_term[i]]
    end
  end
  def errhandle
    super
    new_recovery = @recovering == 0
    conf = recover
    save_configuration @recovering, new_recovery
    conf.deletion_times.times{ basis.lex_delete 0 }
    conf.insertion_each_with_index do |t, index|
      basis.lex_insert token(int_to_term[t]), index
    end
    puts "ins: #{conf.instance_variable_get(:@inserted).collect{|i| int_to_term[i]}}, del: #{conf.deletion_times}" if DEBUG
  end
  def after_shift
    super
    @recovering -= 1 if @recovering > 0
  end
  def before_error
    super
    basis.errshow = @recovering == 0
  end
  #
  def save_configuration index, new_recovery
    if new_recovery
      @error_stack = stack.clone
      basis.lex_to_array_until index
    else
      old_size = basis.la_array.size
      basis.lex_to_array_until index
      return if old_size == basis.la_array.size
    end
    @error_read = basis.get_tokens index
  end
  def restore_configuration
    basis.stack = @error_stack.clone
    basis.replace_tokens @error_read
  end
  #
  def clear_queue
    @queue = []
  end
  def enqueue conf
    @queue << conf
  end
  def delete_min
    @queue.sort_by!{|c| c.cost}
    @queue.shift
  end
  def recover
    if @recovering == 0
      clear_queue
      enqueue Mckenzie_Configuration.new stack.select.with_index{|s, i| i.even?}
    else
      restore_configuration
    end
    until @queue.empty?
      conf = delete_min
      if conf.deleted_empty?
        expected = expected_tokens(conf.state).select{|i| @icost[i]}
        expected.each do |i|
          a = action_table[conf.state][i] || defred_table[conf.state] 
          if a.nil? || a == ACC
          elsif a > 0
            enqueue conf.insert a, i, @icost[i]
          else
            do_reduce conf.clone, a, i
          end
        end
      end
      if i = basis.lex_read(conf.index)
        enqueue conf.delete @dcost[i] if @dcost[i]        
        return conf.tap{ @recovering = AFTER_READ + conf.count } if expected_tokens_stack(conf.stack).include? i
      end
    end
    puts "recovery failed" if DEBUG
    exit 1
  end
  def do_reduce conf, a, i
    r, x = reduce_table[-a]
    conf.reduce goto_table[conf.state(x)][r], x
    a = action_table[conf.state][i] || defred_table[conf.state]
    if a.nil? || a == ACC
    elsif a > 0
      enqueue conf.insert a, i, @icost[i]
    else
      do_reduce conf, a, i
    end
  end
end

class Mckenzie_Configuration
  attr_reader :index, :cost, :stack
  def initialize stack, index = 0, inserted = nil, cost = 0
    @stack = stack
    @index = index
    @inserted = inserted ? inserted : []
    @cost = cost
  end
  def clone
    self.class.new @stack.clone, @index, @inserted.clone, @cost
  end
  def insert dstack, dinserted, dcost
    self.class.new @stack + [dstack], @index, @inserted + [dinserted], @cost + dcost
  end
  def delete dcost
    self.class.new @stack, @index + 1, @inserted, @cost + dcost
  end
  def reduce v, x
    @stack.pop x
    @stack << v
  end
  def deleted_empty?
    @index == 0
  end
  def state n = 0
    @stack[-n - 1]
  end
  def insertion_each_with_index &block
    @inserted.each_with_index &block
  end
  def deletion_times
    @index
  end
  def count
    @inserted.size
  end
end
