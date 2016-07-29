# coding: utf-8
=begin
also need

%extend Depager::LookAheadLexer ('./plugins/lalex.rb')
%extend Depager::ErrHandle ('./plugins/errhandle.rb')
%extend Depager::AfterErrContinue ('./plugins/aftererrcontinue.rb')
=end

module Corchuelo_Module
  DEBUG = true
  
  # parameters
  N  = 3
  Nt = 10
  Ni = 4
  Nd = 3
  
  # constants(do not change)
  DELETE = false
  FMOVE  = nil
  
end

class Depager::LALR::ErrHandleParser < Depager::LALR::AdvancedParser; end

class Corchuelo_Recovery < Depager::LALR::ErrHandleParser  
  include Corchuelo_Module
  #
  def initialize *args
    super
    @queue = []
  end
  def errhandle
    super
    @queue << Corchuelo_Configuration.new(stack.select.with_index{|s, i| i.even?})
    result = try_repair
    if result && result.repaired?
      
      if DEBUG
        s = []
        result.repair_each{|r| s << (r == DELETE ? "del" : r == FMOVE ? "shf" : ("ins #{int_to_term[r]}"))}
        puts "repair succeeded #{s}"
      end
      
      index = 0
      result.repair_each do |r|
        case r
        when DELETE
          basis.lex_delete index
        when FMOVE
          index += 1
        else
          basis.lex_insert token(int_to_term[r]), index
          index += 1
        end
      end
    else
      
      puts "repair failed" if DEBUG
      
      exit 1
    end
    @queue.clear
  end
  #
  def next_conf
    @queue.sort_by!{|c| c.cost }
    @queue.shift
  end
  def add conf
    @queue << conf if conf.repaired? || conf.more_repair?
  end
  def try_shift conf, act, repair
    conf.spush(act).rpush(repair)
    while v = defred_after_shift_table[conf.state]
      try_reduce conf, v
    end
  end
  def try_reduce conf, act
    r, x = reduce_table[-act]
    conf.reduce goto_table[conf.state(x)][r], x
  end
  #
  def try_repair
    while (conf = next_conf) && !conf.repaired?
      try_ER1 conf
      try_ER2 conf
      try_ER3 conf
    end
    conf
  end
  def try_ER1 conf
    return unless conf.more_insertion?
    shifti = basis.lex_read(conf.index)
    expected_tokens(conf.state).each do |i|
      next if i == shifti
      c = conf.clone
      loop do
        a = action_table[c.state][i] || defred_table[c.state]
        if a.nil?
          break
        elsif a == ACC
          add c.spush(a).rpush(i).make_repaired if
            (t = basis.lex_read(c.index)) && t == term_to_int[nil]
          break
        elsif a > 0
          try_shift c, a, i
          add c
          break
        else
          try_reduce c, a
        end
      end
    end
  end
  def try_ER2 conf
    add conf.clone.lex_forward.rpush(DELETE) if conf.more_deletion?
  end
  def try_ER3 conf
    return unless t = basis.lex_read(conf.index)
    c = conf.clone.lex_forward
    loop do
      a = action_table[c.state][t] || defred_table[c.state]
      if a.nil?
        break
      elsif a == ACC
        add c.spush(a).rpush(FMOVE).make_repaired
        break
      elsif a > 0
        try_shift c, a, FMOVE
        c.judge unless c.repaired?
        add c
        break
      else
        try_reduce c, a
      end
    end
  end
end

class Corchuelo_Configuration
  include Corchuelo_Module
  attr_reader :index#, :repair
  def initialize stack, index = 0, repair = nil
    @stack = stack.clone
    @index = index
    @repair = repair ? repair.clone : []
    @repaired = false
  end
  def state n = 0
    @stack[-n - 1]
  end
  def cost
    @repair.select{|r| r != FMOVE }.size
  end
  def more_repair?
    @repair.size < Nt
  end
  def more_insertion?
    @repair.select{|r| r }.size < Ni
  end
  def more_deletion?
    @repair.count(DELETE) < Nd
  end
  def repaired?
    @repaired
  end
  def judge
    make_repaired if @repair.size > N && @repair[@repair.size - N, N].all?{|r| r == FMOVE }
  end
  def clone
    self.class.new @stack, @index, @repair
  end
  def reduce v, x
    @stack.pop x
    @stack << v
  end
  def spush v
    @stack << v; self
  end
  def rpush v
    @repair << v; self
  end
  def lex_forward
    @index += 1; self
  end
  def make_repaired
    N.times{ @repair.last == FMOVE ? @repair.pop : break }
    @repaired = true
    self
  end
  def repair_each &block
    @repair.each &block
  end
end
