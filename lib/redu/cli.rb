require 'thor'
require 'redu/analyzer'

module Redu
  class CLI < Thor
    default_task("analyze")

    desc "analyze", "Analyze a redis server on a particular host"
    method_option :host, :type => :string, :aliases => '-h',:default => 'localhost'
    method_option :port, :type => :numeric, :aliases => '-p', :default => 6379
    method_option :delimiter, :type => :string, :aliases => '-d', :default => '|'
    method_option :worst_offender_count, :type => :string, :aliases => '-w', :default => 25
    def analyze
      Redu::Analyzer.new(options).start
    end
  end
end
