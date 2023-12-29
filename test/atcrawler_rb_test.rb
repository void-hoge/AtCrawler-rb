# frozen_string_literal: true

require "test_helper"

class AtcrawlerRbTest < Test::Unit::TestCase
  test "VERSION" do
    assert do
      ::AtcrawlerRb.const_defined?(:VERSION)
    end
  end

  test 'login' do
    session = AtcrawlerRb::AtCoderSession.new
    #session.login
    assert(session.is_logged_in)
  end

  test 'save cookie' do
    session = AtcrawlerRb::AtCoderSession.new
    session.save_cookie
    assert(File.exist?("#{ENV['HOME']}/.local/share/atcrawler_rb/cookie.txt"))
  end

  test 'auto login' do
    session = AtcrawlerRb::AtCoderSession.new
    assert(session.is_logged_in)
  end

  test 'initenv tasks' do
    session = AtcrawlerRb::AtCoderSession.new
    env = AtcrawlerRb::EnvironmentInitializer.new(session, 'abc334')
    tasks = env.tasks
    assert_equal(tasks['a'], {
                   :title => 'Christmas Present',
                   :sanitized => 'christmas-present',
                   :dirname => 'abc334/A-christmas-present',
                   :link => 'https://atcoder.jp/contests/abc334/tasks/abc334_a'
                 })
    assert_equal(tasks['b'], {
                   :title => 'Christmas Trees',
                   :sanitized => 'christmas-trees',
                   :dirname => 'abc334/B-christmas-trees',
                   :link => 'https://atcoder.jp/contests/abc334/tasks/abc334_b'
                 })
    assert_equal(tasks['c'], {
                   :title => 'Socks 2',
                   :sanitized => 'socks-2',
                   :dirname => 'abc334/C-socks-2',
                   :link => 'https://atcoder.jp/contests/abc334/tasks/abc334_c'
                 })
    assert_equal(tasks['d'], {
                   :title => 'Reindeer and Sleigh',
                   :sanitized => 'reindeer-and-sleigh',
                   :dirname => 'abc334/D-reindeer-and-sleigh',
                   :link => 'https://atcoder.jp/contests/abc334/tasks/abc334_d'
                 })
    assert_equal(tasks['e'], {
                   :title => 'Christmas Color Grid 1',
                   :sanitized => 'christmas-color-grid-1',
                   :dirname => 'abc334/E-christmas-color-grid-1',
                   :link => 'https://atcoder.jp/contests/abc334/tasks/abc334_e'
                 })
    assert_equal(tasks['f'], {
                   :title => 'Christmas Present 2',
                   :sanitized => 'christmas-present-2',
                   :dirname => 'abc334/F-christmas-present-2',
                   :link => 'https://atcoder.jp/contests/abc334/tasks/abc334_f'
                 })
    assert_equal(tasks['g'], {
                   :title => 'Christmas Color Grid 2',
                   :sanitized => 'christmas-color-grid-2',
                   :dirname => 'abc334/G-christmas-color-grid-2',
                   :link => 'https://atcoder.jp/contests/abc334/tasks/abc334_g'
                 })
  end

  test 'initenv samples' do
    session = AtcrawlerRb::AtCoderSession.new
    env = AtcrawlerRb::EnvironmentInitializer.new(session, 'abc334')
    samples = env.samples
    assert_equal(samples['a'], [["300 100\n", "Bat\n"], ["334 343\n", "Glove\n"]])
    assert_equal(samples['d'], [["4 3\n5 3 11 8\n16\n7\n1000\n", "3\n1\n4\n"],
                                ["6 6\n1 2 3 4 5 6\n1\n2\n3\n4\n5\n6\n", "1\n1\n2\n2\n2\n3\n"],
                                ["2 2\n1000000000 1000000000\n200000000000000\n1\n", "2\n0\n"]])
  end

  test 'env make directories' do
    session = AtcrawlerRb::AtCoderSession.new
    env = AtcrawlerRb::EnvironmentInitializer.new(session, 'abc334')
    env.build
    env.samples.each do |prefix, sample|
      dirname = env.tasks[prefix][:dirname]
      sample.each_with_index do |io, idx|
        i, o = io
        assert(File.exist?("#{dirname}/test#{idx+1}"))
        assert(File.exist?("#{dirname}/exp#{idx+1}"))
        file = File.open("#{dirname}/test#{idx+1}")
        assert_equal(file.read, i)
        file.close
        file = File.open("#{dirname}/exp#{idx+1}")
        assert_equal(file.read, o)
        file.close
      end
    end
  end

  test 'submission_collector' do
    session = AtcrawlerRb::AtCoderSession.new
    collector = AtcrawlerRb::SubmissionCollector.new(session, 'abc334')
    assert_equal(collector.lang2key("C++"), "C%2B%2B")
    assert_equal(collector.lang2key("Assembly x64"), "Assembly+x64")
    collector.collect(username: "voidhoge", orderby: "created", result: "AC", descending: true)
    assert(File.exist?("abc334/A-christmas-present/48737218.py"))
    assert(File.exist?("abc334/B-christmas-trees/48808497.cpp"))
    assert(File.exist?("abc334/B-christmas-trees/48807489.py"))
    assert(File.exist?("abc334/C-socks-2/48808612.cpp"))
    assert(File.exist?("abc334/D-reindeer-and-sleigh/48776812.cpp"))

    collector.tasks.each do |prefix, task|
      dirname = task[:dirname]
      Dir.foreach(dirname) do |filename|
        if File.extname(filename) == ".cpp"
          `g++ #{dirname}/#{filename} -o #{dirname}/#{filename}.out`
          collector.samples[prefix].each_with_index do |_, idx|
            out = `#{dirname}/#{filename}.out < #{dirname}/test#{idx+1}`
            file = File.open("#{dirname}/exp#{idx+1}")
            exp = file.read
            file.close
            assert_equal(exp, out)
          end
        elsif File.extname(filename) == ".py"
          collector.samples[prefix].each_with_index do |_, idx|
            out = `python3 #{dirname}/#{filename} < #{dirname}/test#{idx+1}`
            file = File.open("#{dirname}/exp#{idx+1}")
            exp = file.read
            file.close
            assert_equal(exp, out)
          end
        end
      end
    end
  end
end
