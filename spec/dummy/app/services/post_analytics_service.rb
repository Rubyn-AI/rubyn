# frozen_string_literal: true

class PostAnalyticsService
  def compute_engagement_score(post, weight: 1.0)
    EngagementScorer.compute(post, weight: weight)
  end
end
