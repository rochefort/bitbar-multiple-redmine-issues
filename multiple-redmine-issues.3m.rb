#!/usr/bin/env ruby
# coding: utf-8

# <bitbar.title>Multiple Redmine Issues</bitbar.title>
# <bitbar.version>v1.0.0</bitbar.version>
# <bitbar.author>rochefort</bitbar.author>
# <bitbar.author.github>rochefort</bitbar.author.github>
# <bitbar.desc>Show my tickets of multiple Redmine</bitbar.desc>
# <bitbar.image>https://raw.githubusercontent.com/hikouki/bitbar-redmine/master/preview.png</bitbar.image>
# <bitbar.dependencies>ruby</bitbar.dependencies>
# <bitbar.abouturl>https://github.com/rochefort</bitbar.abouturl>

require "net/http"
require "uri"
require "json"
require "pp"

module Bitbar
  class Setting < Struct.new(:token, :url); end

  class MutipleRedmineIssues
    DARK_MODE = true
    SETTING_JSON_PATH = "#{ENV['HOME']}/.config/bitbar/multiple-redmine-show-my-task.json"
    # JSON Example:
    # {
    #   "redmine_settings": [
    #     {
    #       "token": "your_token",
    #       "url": "http://192.168.1.10/"
    #     },
    #     {
    #       "token": "your_token",
    #       "url": "http://192.168.1.12:10081/"
    #      }
    #   ]
    # }
    def initialize
      abort_exit unless File.exist? SETTING_JSON_PATH
      json = File.open(SETTING_JSON_PATH) { |f| JSON.load(f) }
      abort_exit unless (json || json["redmine_settings"])

      @settings = json["redmine_settings"].map { |json| Setting.new(json["token"], json["url"]) }
      abort_exit unless @settings
    end

    def run
      projects = []
      @settings.each do |setting|
        url   = setting.url
        token = setting.token
        uri = URI.join(url, "issues.json?key=#{token}&limit=100&status_id=open&assigned_to_id=me")
        res = request(uri)
        result = JSON.parse(res.body, symbolize_names: true)
        issues = result[:issues]
        projects << convert_projects(issues, url)
      end
      render(projects)
    rescue
      abort_exit
    end

    private
      def request(uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true if (uri.scheme == "https")
        res = http.start { http.get(uri.request_uri) }
        raise "error #{res.code} #{res.message}" if res.code != "200"
        res
      end

      def genrate_redmine
        {
          url: "",
          issues_count: 0,
          projects: Hash.new do |h1, k1|
            h1[k1] = {
              id: nil,
              name: "",
              issues_count: 0,
              trackers: Hash.new do |h2, k2|
                h2[k2] = {
                  id: nil,
                  name: "",
                  issues: Hash.new { |h3, k3| h3[k3] = [] }
                }
              end
            }
          end
        }
      end

      def convert_projects(issues, url)
        redmines = genrate_redmine
        issues.each do |issue|
          project_id   = issue[:project][:id]
          project_name = issue[:project][:name]
          status_id    = issue[:status][:id]
          tracker_id   = issue[:tracker][:id]
          tracker_name = issue[:tracker][:name]

          redmines[:url] = url
          redmines[:issues_count] += 1
          redmines[:projects][project_id][:id] = project_id
          redmines[:projects][project_id][:issues_count] += 1
          redmines[:projects][project_id][:name] = project_name
          redmines[:projects][project_id][:trackers][tracker_id][:name] = tracker_name
          redmines[:projects][project_id][:trackers][tracker_id][:issues][status_id].push(issue)
        end
        redmines
      end

      def render(redmines)
        issue_total_count = redmines.inject(0) { |total, pr| total += pr[:issues_count] }
        issue_total_count = issue_total_count > 99 ? "99+" : issue_total_count
        puts issue_total_count.zero? ? "✦ | color=#7d7d7d" : "✦ #{issue_total_count}"

        redmines.each do |redmine|
          puts "---"
          puts "#{redmine[:url]} | color=#{base_color} href=#{redmine[:url]}"
          puts "---"

          redmine[:projects].each do |_, project|
            puts "#{project[:name]}: #{project[:issues_count]} | size=11"
            project[:trackers].each do |_, tracker|
              puts "➠ #{tracker[:name]} | color=#33BFDB size=11"
              tracker[:issues].each do |_, status|
                puts "[#{status.first[:status][:name]}] | color=#58BE89 size=11"
                status.each do |issue|
                  prefix = status.last == issue ? "└" : "├"
                  puts "#{prefix} ##{issue[:id]} #{issue[:subject]} | color=#{base_color} href=#{URI.join(redmine[:url], "/issues/#{issue[:id]}")} size=11"
                end
              end
            end
            puts "---"
          end
        end
      end

      def abort_exit
        render_abort
        exit
      end

      # TODO: error message
      def render_abort
        puts "✦ ! | color=#ECB935"
        puts "---"
        # TODO:
        puts "Exception: #{$!}"
      end

      def base_color
        @base_color ||= (DARK_MODE ? "white" : "black")
      end
  end
end

Bitbar::MutipleRedmineIssues.new.run
