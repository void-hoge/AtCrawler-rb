# frozen_string_literal: true

require_relative "atcrawler_rb/version"
require 'mechanize'
require 'json'
require 'io/console'
require 'fileutils'
require 'cgi'

module AtcrawlerRb
  class LoginFailedError < StandardError; end
  class CookieNotFoundError < StandardError; end
  class RequestFailedError < RuntimeError; end

  class AtCoderSession
    INTERVAL = 0.5
    @@prev = Time.now
    def initialize
      @agent = Mechanize.new
      begin
        self.load_cookie
      rescue CookieNotFoundError
        self.login
        self.save_cookie
      end
      if not self.is_logged_in
        self.delete_cookie
        raise LoginFailedError
      end
    end

    def wait_until_interval
      current = Time.now
      interval = current - @@prev
      if interval < INTERVAL
        sleep(INTERVAL - interval)
      end
      @@prev = Time.now
    end

    def get(url)
      self.wait_until_interval
      response = @agent.get(url)
      if response.code == "200"
        return response
      else
        raise RequestFailedError(response.code)
      end
    end

    def login
      print 'username: '
      username = $stdin.gets.chomp
      print 'password: '
      password = $stdin.noecho(&:gets).chomp

      page = self.get('https://atcoder.jp/login')
      form = page.forms[1]
      form.field_with(name: 'username').value = username
      form.field_with(name: 'password').value = password
      form.submit()
    end

    def is_logged_in
      return self.get('https://atcoder.jp').body.include?('My Profile')
    end

    def save_cookie
      FileUtils.makedirs("#{ENV['HOME']}/.local/share/atcrawler_rb")
      file = File.open("#{ENV['HOME']}/.local/share/atcrawler_rb/cookie.txt", 'w')
      @agent.cookie_jar.save(file, {:session=>true})
      file.close
    end

    def load_cookie
      begin
        file = File.open("#{ENV['HOME']}/.local/share/atcrawler_rb/cookie.txt", 'r')
      rescue
        raise CookieNotFoundError
      end
      @agent.cookie_jar.load(file)
    end

    def self.delete_cookie
      begin
        File.delete("#{ENV['HOME']}/.local/share/atcrawler_rb/cookie.txt")
      rescue
      end
    end
  end

  class EnvironmentInitializer
    attr_reader :tasks
    attr_reader :samples
    def initialize(session, contest)
      @session = session
      @contest = contest.downcase
      @url = "https://atcoder.jp/contests/#{@contest}"
      puts "#{@contest.upcase} (#{@url} )"
      @tasks = self.get_tasks
      @samples = self.get_samples
    end

    def build
      self.create_directories
      self.create_samples
    end

    def create_directories
      @tasks.each do |prefix, task|
        puts "Creating direcotry for task #{prefix.upcase}..."
        dirname = task[:dirname]
        begin
          FileUtils.makedirs(dirname)
        rescue
        end
      end
    end

    def create_samples
      @samples.each do |prefix, sample|
        puts "Downloading and parsing samples for task #{prefix.upcase}..."
        dirname = @tasks[prefix][:dirname]
        sample.each_with_index do |io, idx|
          i, o = io
          file = File.open("#{dirname}/test#{idx + 1}", "w")
          file.write(i)
          file.close
          file = File.open("#{dirname}/exp#{idx + 1}", "w")
          file.write(o)
          file.close
        end
      end
    end

    def get_tasks
      html = @session.get("#{@url}/tasks").body
      lines = html.split("\n")
      task_re = "<td><a href=\"(/contests/#{@contest}/tasks/#{@contest}_([a-z]))\">(.+)</a></td>"
      tasks = {}
      lines.each do |line|
        match = line.match(task_re)
        if match
          link, prefix, title = match.captures
          sanitized = self.sanitize_text(title)
          dirname = "#{@contest}/#{prefix.upcase}-#{sanitized}"
          tasks[prefix] = {
            :title => title,
            :sanitized => sanitized,
            :dirname => dirname,
            :link => "https://atcoder.jp#{link}"}
          puts "#{prefix.upcase}: #{title}"
        end
      end
      return tasks
    end

    def sanitize_text(text)
      begin
        result = ''
        text.downcase.each_char do |ch|
          if ch.match("[a-z0-9\.]")
            result += ch
          else
            result += '-'
          end
        end
        return result
      rescue
        return text
      end
    end

    def get_samples
      samples = {}
      @tasks.each do |prefix, task|
        link = task[:link]
        html = @session.get(link).body
        samples[prefix] = self.parse_samples(html)
      end
      return samples
    end

    def parse_samples(html)
      lines = html.split("\n")
      inputs = []
      outputs = []
      state = :init
      input_start_re = "<h[0-9]+>Sample Input [0-9]*</h[0-9]+><pre>(.*)$"
      input_end_re = "(.*)</pre>"
      output_start_re = "<h[0-9]+>Sample Output [0-9]*</h[0-9]+><pre>(.*)$"
      output_end_re = "(.*)</pre>"
      lines.each do |line|
        if state == :init
          match = line.match(input_start_re)
          if match
            inputs.push(match.captures[0].gsub("\r", ""))
            state = :input
            next
          end
          match = line.match(output_start_re)
          if match
            outputs.push(match.captures[0].gsub("\r", ""))
            state = :output
            next
          end
        elsif state == :input
          match = line.match(input_end_re)
          if match
            inputs[-1] += "\n#{match.captures[0]}".gsub("\r", "")
            state = :init
          else
            inputs[-1] += "\n#{line}".gsub("\r", "")
          end
        elsif state == :output
          match = line.match(output_end_re)
          if match
            outputs[-1] += "\n#{match.captures[0]}".gsub("\r", "")
            state = :init
          else
            outputs[-1] += "\n#{line}".gsub("\r", "")
          end
        end
      end
      result = []
      inputs.zip(outputs).each do |i, o|
        result.push([i, o])
      end
      return result
    end
  end

  class SubmissionCollector < EnvironmentInitializer
    attr_reader :submission_ids
    @@LANG_SUFFIX = {
      "^C++" => "cpp",
      "^C" => "c",
      "^C#" => "cs",
      "^Java" => "java",
      "^Kotlin" => "kt",
      "^Python" => "py",
      "^Ruby" => "rb",
      "^Rust" => "rs"
    }
    def initialize(session, contest)
      super(session, contest)
    end

    def collect(task: "", username: "", language: "", result: "",
                orderby: nil, descending: false, maxsubmissions: 20)
      @submission_ids = []
      taskkey = task == "" ? "" : "#{@contest}_#{task}"
      page = 1
      while submission_ids.size < maxsubmissions
        stndrd = [1,2,3].include?(page % 10) ? ["st", "nd", "rd"][(page % 10)-1] : "th"
        puts "Downloading and parsing the #{page} #{stndrd} submission page..."
        url = self.url_format(task: taskkey, username: username, language: language,
                              result: result, orderby: orderby, descending: descending, page: page)
        html = @session.get(url).body
        ids = self.parse_submissions_table(html)
        page += 1
        submission_ids.concat(ids)
        if ids.size == 0
          break
        end
      end
      submission_ids.slice!(maxsubmissions..-1)
      puts "Detected #{submission_ids.size} submissions."
      submission_ids.each do |id|
        html = @session.get("#{@url}/submissions/#{id}").body
        prefix, langsys, code = self.parse_submission(html)
        puts "Writing #{langsys} source code for task #{prefix.upcase}."
        dirname = @tasks[prefix][:dirname]
        suffix = ""
        @@LANG_SUFFIX.each do |lang, suff|
          if langsys.match(lang)
            suffix = "." + suff
            break
          end
        end
        file = File.open("#{dirname}/#{id}#{suffix}", "w")
        file.write(code)
        file.close
      end
    end

    def parse_submission(html)
      code = self.parse_submission_codeblock(html)
      langsys = self.parse_submission_language_system(html)
      prefix = self.parse_submission_taskprefix(html)
      return [prefix, langsys, code]
    end

    def parse_submission_taskprefix(html)
      lines = html.split('\n')
      prefix = nil
      task_re = "<td class=\"text-center\"><a href=\"/contests/#{@contest}/tasks/#{@contest}_([a-z])\">.*</a></td>"
      lines.each do |line|
        match = line.match(task_re)
        if match
          prefix = match.captures[0]
          break
        end
      end
      return prefix
    end
    
    def parse_submission_codeblock(html)
      lines = CGI.unescapeHTML(html).split("\n")
      state = :init
      codeblock_start_re = "<pre id=\"submission-code\" data-ace-mode=\".*\">(.*)"
      codeblock_end_re = "^(.*)</pre>$"
      code = ""
      lines.each do |line|
        if state == :init
          match = line.match(codeblock_start_re)
          if match
            code += match.captures[0].gsub("\r", "")
            state = :block
          end
        elsif state == :block
          match = line.match(codeblock_end_re)
          if match
            code += "\n" + match.captures[0].gsub("\r", "")
            state = :init
            break
          else
            code += "\n" + line.gsub("\r", "")
          end
        end
      end
      return code
    end

    def parse_submission_language_system(html)
      lines = CGI.unescapeHTML(html).split("\n")
      state = :init
      tableitem_language_re = "<th>Language</th>"
      langsys_re = "<td class=\"text-center\">(.*)</td>"
      langsys = nil
      lines.each do |line|
        if state == :init
          match = line.match(tableitem_language_re)
          if match
            state = :language
          end
        elsif state == :language
          match = line.match(langsys_re)
          if match
            langsys = match.captures[0]
            state = :init
            break
          end
        end
      end
      return langsys
    end
    
    def parse_submissions_table(html)
      result = []
      lines = html.split("\n")
      id_re = "<td class=\"text-right submission-score\" data-id=\"([0-9]+)\">"
      lines.each do |line|
        match = line.match(id_re)
        if match
          result.push(match.captures[0])
        end
      end
      return result
    end

    def url_format(task: "", username: "", language: "", result: "",
                   orderby: nil, descending: false, page: 1)
      langkey = self.lang2key(language)
      if orderby
        if descending
          url = "#{@url}/submissions?desc=true&f.Task=#{task}&f.LanguageName=#{langkey}&f.Status=#{result}&f.User=#{username}&orderBy=#{orderby}&page=#{page}"
        else
          url = "#{@url}/submissions?f.Task=#{task}&f.LanguageName=#{langkey}&f.Status=#{result}&f.User=#{username}&orderBy=#{orderby}&page=#{page}"
        end
      else
        url = "#{@url}/submissions?f.Task=#{task}&f.LanguageName=#{langkey}&f.Status=#{result}&f.User=#{username}&page=#{page}"
      end
      return url
    end

    def lang2key(lang="")
      key = ""
      lang.each_char do |ch|
        if ch == " "
          key += "+"
        elsif "+#".include?(ch)
          key += "%#{ch.ord.to_s(16).upcase}"
        else
          key += ch
        end
      end
      return key
    end
  end
end
