# frozen_string_literal: true

module Github
  class FeedService
    CACHE_KEY = "github_lab_feed"
    CACHE_TTL = 5.minutes
    GITHUB_USER = "rogue-media-lab"

    EVENT_MAP = {
      "PushEvent"            => { label: "COMMIT",    color: "green"  },
      "CreateEvent"          => { label: "CREATED",   color: "green"  },
      "DeleteEvent"          => { label: "DELETED",   color: "orange" },
      "PullRequestEvent"     => { label: "PR",        color: "blue"   },
      "IssuesEvent"          => { label: "ISSUE",     color: "purple" },
      "IssueCommentEvent"    => { label: "COMMENT",   color: "purple" },
      "ReleaseEvent"         => { label: "RELEASE",   color: "orange" },
      "WatchEvent"           => { label: "STAR",      color: "yellow" },
      "ForkEvent"            => { label: "FORK",      color: "blue"   },
      "DeploymentEvent"      => { label: "DEPLOY",    color: "orange" },
      "DeploymentStatusEvent"=> { label: "DEPLOY",    color: "green"  },
      "GollumEvent"          => { label: "WIKI",      color: "purple" }
    }.freeze

    def self.fetch(limit: 4)
      Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) do
        new.fetch_events(limit: limit)
      end
    rescue StandardError => e
      Rails.logger.error("GitHub feed error: #{e.message}")
      []
    end

    def fetch_events(limit: 4)
      @client = Octokit::Client.new(access_token: github_token)
      @client.auto_paginate = false

      # Try user public events
      events = @client.user_public_events(GITHUB_USER, per_page: limit * 2)

      events.first(limit).map { |e| format_event(e) }.compact
    rescue Octokit::TooManyRequests
      Rails.logger.warn("GitHub API rate limited")
      []
    rescue Octokit::NotFound
      # Fallback to repo activity
      fetch_from_repos(limit)
    end

    private

    def github_token
      Rails.application.credentials.dig(:github, :token).presence
    end

    def format_event(event)
      type = event.type.to_s
      info = EVENT_MAP[type]
      return nil unless info

      repo_name = event.repo&.name&.split("/")&.last || "unknown"
      description = build_description(event, type, repo_name)

      {
        source: repo_name.upcase.gsub("-", "_"),
        action: info[:label],
        color: info[:color],
        description: description,
        time_ago: time_ago(Time.parse(event.created_at.to_s))
      }
    end

    def build_description(event, type, repo_name)
      payload = event.payload

      case type
      when "PushEvent"
        ref = payload.ref&.gsub("refs/heads/", "") || "main"
        "Pushed to #{ref}"
      when "PullRequestEvent"
        action = payload.action || "updated"
        title = payload.pull_request&.title&.truncate(50) || repo_name
        "PR #{action}: #{title}"
      when "IssuesEvent"
        action = payload.action || "updated"
        title = payload.issue&.title&.truncate(50) || repo_name
        "Issue #{action}: #{title}"
      when "CreateEvent"
        ref_type = payload.ref_type || "branch"
        ref = payload.ref || repo_name
        "Created #{ref_type}: #{ref}"
      when "ReleaseEvent"
        tag = payload.release&.tag_name || "new release"
        "Released #{tag}"
      when "WatchEvent"
        "Starred #{repo_name}"
      when "ForkEvent"
        "Forked #{repo_name}"
      else
        "#{type.gsub('Event', '')} on #{repo_name}"
      end
    end

    def time_ago(time)
      seconds = (Time.current - time).to_i
      return "#{seconds}s ago" if seconds < 60
      return "#{seconds / 60}m ago" if seconds < 3600
      return "#{seconds / 3600}h ago" if seconds < 86400
      "#{seconds / 86400}d ago"
    end

    def fetch_from_repos(limit)
      repos = @client.repos(GITHUB_USER, per_page: 5)
      events = []

      repos.first(3).each do |repo|
        begin
          repo_events = @client.repository_events(repo.full_name, per_page: limit)
          events.concat(repo_events.first(limit))
        rescue Octokit::NotFound, Octokit::Forbidden
          next
        end
      end

      events.sort_by { |e| e.created_at.to_s }.reverse.first(limit).map { |e| format_event(e) }.compact
    end
  end
end
