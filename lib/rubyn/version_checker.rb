# frozen_string_literal: true

require "json"
require "net/http"
require "fileutils"

module Rubyn
  class VersionChecker
    CACHE_FILE = File.join(Dir.home, ".rubyn", "version_cache.json")
    CACHE_TTL = 86_400 # 24 hours
    RUBYGEMS_URL = "https://rubygems.org/api/v1/versions/rubyn/latest.json"

    class << self
      def check
        cached = read_cache
        return cached if cached

        latest = fetch_latest_version
        return nil unless latest

        write_cache(latest)
        latest
      rescue Net::HTTPError, SocketError, JSON::ParserError, Errno::ENOENT, Errno::EACCES
        nil
      end

      def update_available?
        latest = check
        return false unless latest && Gem::Version.correct?(latest)

        Gem::Version.new(latest) > Gem::Version.new(Rubyn::VERSION)
      end

      def update_message
        latest = check
        return nil unless latest && Gem::Version.correct?(latest)
        return nil unless Gem::Version.new(latest) > Gem::Version.new(Rubyn::VERSION)

        "Rubyn #{latest} is available (you have #{Rubyn::VERSION}). Run `gem update rubyn` to upgrade."
      end

      private

      def fetch_latest_version
        uri = URI(RUBYGEMS_URL)
        response = Net::HTTP.get_response(uri)
        return nil unless response.is_a?(Net::HTTPSuccess)

        data = JSON.parse(response.body)
        data["version"]
      rescue Net::HTTPError, SocketError, JSON::ParserError, Timeout::Error, Errno::ECONNREFUSED
        nil
      end

      def read_cache
        return nil unless File.exist?(CACHE_FILE)

        data = JSON.parse(File.read(CACHE_FILE))
        return nil if Time.now.to_i - data["checked_at"].to_i > CACHE_TTL

        data["version"]
      rescue JSON::ParserError, Errno::ENOENT, Errno::EACCES
        nil
      end

      def write_cache(version)
        FileUtils.mkdir_p(File.dirname(CACHE_FILE))
        File.write(CACHE_FILE, JSON.generate(version: version, checked_at: Time.now.to_i))
      rescue Errno::EACCES, Errno::ENOENT, Errno::ENOSPC
        # Non-critical — skip if we can't write cache
      end
    end
  end
end
