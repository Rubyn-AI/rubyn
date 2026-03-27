# frozen_string_literal: true

RSpec.describe Rubyn::Context::ResponseParser do
  describe ".extract_file_blocks" do
    subject(:blocks) { described_class.extract_file_blocks(response) }

    context "with bold Updated/New file headers" do
      let(:response) do
        <<~RESPONSE
          **Summary**

          This service has three responsibilities mixed into one class.

          **Updated file: app/services/post_analytics_service.rb**

          ```ruby
          # frozen_string_literal: true

          class PostAnalyticsService
            def categorize_posts(posts)
              scorer = EngagementScorer.new
              categories = { hot: [], trending: [], normal: [], stale: [], dead: [] }
              posts.each do |post|
                score = scorer.compute(post)
                category = determine_category(post, score)
                categories[category] << post
              end
              categories
            end
          end
          ```

          **New file: app/services/engagement_scorer.rb**

          ```ruby
          # frozen_string_literal: true

          class EngagementScorer
            def compute(post, weight: 1.0)
              score = base_score(post) * weight
              score += comment_bonus(post)
              score.round(2)
            end
          end
          ```

          **Why**

          - Extracted scorer into its own class
        RESPONSE
      end

      it "extracts two file blocks" do
        expect(blocks.length).to eq(2)
      end

      it "identifies the updated file path" do
        expect(blocks[0][:path]).to eq("app/services/post_analytics_service.rb")
      end

      it "identifies the new file path" do
        expect(blocks[1][:path]).to eq("app/services/engagement_scorer.rb")
      end

      it "extracts the code for the updated file" do
        expect(blocks[0][:code]).to include("class PostAnalyticsService")
        expect(blocks[0][:code]).to include("categorize_posts")
      end

      it "extracts the code for the new file" do
        expect(blocks[1][:code]).to include("class EngagementScorer")
        expect(blocks[1][:code]).to include("def compute")
      end

      it "does not include markdown fences in the code" do
        blocks.each do |block|
          expect(block[:code]).not_to include("```")
        end
      end
    end

    context "with the full production response format" do
      let(:response) do
        <<~RESPONSE
          **Summary**

          This service has three responsibilities—engagement scoring, post categorization, and digest generation—mixed into one class. Extract engagement scoring into a separate, testable object.

          **Updated file: app/services/post_analytics_service.rb**

          ```ruby
          # frozen_string_literal: true

          class PostAnalyticsService
            def categorize_posts(posts)
              scorer = EngagementScorer.new
              categories = { hot: [], trending: [], normal: [], stale: [], dead: [] }

              posts.each do |post|
                score = scorer.compute(post)
                category = determine_category(post, score)
                categories[category] << post
              end

              categories
            end

            def generate_weekly_digest(start_date = nil, end_date = nil)
              start_date ||= 7.days.ago
              end_date ||= Time.now

              {
                period: { start: start_date, end: end_date },
                sections: [
                  new_posts_section(start_date, end_date),
                  top_commenters_section(start_date, end_date),
                  author_productivity_section
                ]
              }
            end

            private

            def determine_category(post, engagement_score)
              case engagement_score
              when 100..Float::INFINITY
                :hot
              when 50..99
                :trending
              else
                :normal
              end
            end
          end
          ```

          **New file: app/services/engagement_scorer.rb**

          ```ruby
          # frozen_string_literal: true

          class EngagementScorer
            BASE_SCORES = {
              published_recent: 50,
              published_week: 30,
              published_month: 10,
              published_old: 1,
              draft: 0,
              archived: -10
            }.freeze

            def compute(post, weight: 1.0)
              score = base_score(post) * weight
              score += comment_bonus(post)
              score += view_bonus(post)
              score += admin_bonus(post)
              score.round(2)
            end

            private

            def base_score(post)
              return BASE_SCORES[:draft] if post.status == "draft"
              return BASE_SCORES[:archived] if post.status == "archived"
              return 0 unless post.published_at

              days_old = (Time.now - post.published_at) / 1.day

              case days_old
              when 0...1
                BASE_SCORES[:published_recent]
              when 1...7
                BASE_SCORES[:published_week]
              when 7...30
                BASE_SCORES[:published_month]
              else
                BASE_SCORES[:published_old]
              end
            end

            def comment_bonus(post)
              comment_count = post.comments.count
              return 0 if comment_count.zero?

              bonus = comment_count * 10
              bonus += 20 if comment_count > 5
              bonus += 40 if comment_count > 10
              bonus
            end

            def view_bonus(post)
              views = post.views_count.to_i
              return 25 if views > 100
              return 15 if views > 50
              return 5 if views > 10
              0
            end

            def admin_bonus(post)
              return 10 if post.user.admin?
              return 5 if post.comments.any? { |c| c.user.admin? }
              0
            end
          end
          ```

          **Why**

          - **EngagementScorer is isolated and testable.** All scoring logic moves to one class.
          - **Database queries instead of in-memory filtering.** Digest uses `.where()`, `.group()`, `.count()`.
          - **Categorization logic simplified.** `determine_category` delegates to tiny helpers.
        RESPONSE
      end

      it "extracts exactly two file blocks" do
        expect(blocks.length).to eq(2)
      end

      it "correctly identifies the updated file" do
        expect(blocks[0][:path]).to eq("app/services/post_analytics_service.rb")
      end

      it "correctly identifies the new file" do
        expect(blocks[1][:path]).to eq("app/services/engagement_scorer.rb")
      end

      it "includes complete code for the updated file" do
        expect(blocks[0][:code]).to include("class PostAnalyticsService")
        expect(blocks[0][:code]).to include("generate_weekly_digest")
        expect(blocks[0][:code]).to include("determine_category")
      end

      it "includes complete code for the new file" do
        expect(blocks[1][:code]).to include("class EngagementScorer")
        expect(blocks[1][:code]).to include("BASE_SCORES")
        expect(blocks[1][:code]).to include("comment_bonus")
        expect(blocks[1][:code]).to include("view_bonus")
        expect(blocks[1][:code]).to include("admin_bonus")
      end
    end

    context "with backtick-wrapped path headers" do
      let(:response) do
        <<~RESPONSE
          **Summary**

          Extracting scorer.

          `app/services/post_analytics_service.rb`
          ```ruby
          class PostAnalyticsService
            def score(post)
              EngagementScorer.new.compute(post)
            end
          end
          ```

          `app/services/engagement_scorer.rb`
          ```ruby
          class EngagementScorer
            def compute(post)
              42
            end
          end
          ```
        RESPONSE
      end

      it "extracts two blocks with correct paths" do
        expect(blocks.length).to eq(2)
        expect(blocks[0][:path]).to eq("app/services/post_analytics_service.rb")
        expect(blocks[1][:path]).to eq("app/services/engagement_scorer.rb")
      end
    end

    context "with path as inline comment on first line" do
      let(:response) do
        <<~RESPONSE
          **Summary**

          Splitting service.

          ```ruby
          # app/services/post_analytics_service.rb
          class PostAnalyticsService
            def score(post)
              EngagementScorer.new.compute(post)
            end
          end
          ```

          ```ruby
          # app/services/engagement_scorer.rb
          class EngagementScorer
            def compute(post)
              42
            end
          end
          ```
        RESPONSE
      end

      it "extracts two blocks with correct paths" do
        expect(blocks.length).to eq(2)
        expect(blocks[0][:path]).to eq("app/services/post_analytics_service.rb")
        expect(blocks[1][:path]).to eq("app/services/engagement_scorer.rb")
      end
    end

    context "with a single code block and no path" do
      let(:response) do
        <<~RESPONSE
          **Summary**

          Minor cleanup.

          ```ruby
          class PostAnalyticsService
            def score(post)
              42
            end
          end
          ```
        RESPONSE
      end

      it "extracts one block with nil path" do
        expect(blocks.length).to eq(1)
        expect(blocks[0][:path]).to be_nil
      end
    end

    context "with mixed formats (bold header + inline comment)" do
      let(:response) do
        <<~RESPONSE
          **Updated file: app/services/post_analytics_service.rb**

          ```ruby
          class PostAnalyticsService
            def score(post)
              EngagementScorer.new.compute(post)
            end
          end
          ```

          ```ruby
          # app/services/engagement_scorer.rb
          class EngagementScorer
            def compute(post)
              42
            end
          end
          ```
        RESPONSE
      end

      it "handles bold header for first block" do
        expect(blocks[0][:path]).to eq("app/services/post_analytics_service.rb")
      end

      it "falls back to inline comment for second block" do
        expect(blocks[1][:path]).to eq("app/services/engagement_scorer.rb")
      end
    end

    context "determines new vs modified correctly" do
      let(:original_file) { "app/services/post_analytics_service.rb" }

      let(:response) do
        <<~RESPONSE
          **Updated file: app/services/post_analytics_service.rb**

          ```ruby
          class PostAnalyticsService
          end
          ```

          **New file: app/services/engagement_scorer.rb**

          ```ruby
          class EngagementScorer
          end
          ```
        RESPONSE
      end

      it "identifies the original file as modified" do
        path = blocks[0][:path]
        is_new = path != original_file && !path.end_with?("/#{original_file}") && !original_file.end_with?("/#{path}")
        expect(is_new).to be false
      end

      it "identifies the extracted file as new" do
        path = blocks[1][:path]
        is_new = path != original_file && !path.end_with?("/#{original_file}") && !original_file.end_with?("/#{path}")
        expect(is_new).to be true
      end
    end

    context "does not match bold .rb references in prose" do
      let(:response) do
        <<~RESPONSE
          **Updated file: app/services/post_analytics_service.rb**

          ```ruby
          class PostAnalyticsService
            def score
              EngagementScorer.new.compute
            end
          end
          ```

          **New file: app/services/engagement_scorer.rb**

          ```ruby
          class EngagementScorer
            def compute
              42
            end
          end
          ```

          **Why**

          - Extracted **app/services/engagement_scorer.rb** for single responsibility
          - The **post_analytics_service.rb** is now a thin wrapper
        RESPONSE
      end

      it "extracts exactly two blocks, not more" do
        expect(blocks.length).to eq(2)
      end

      it "does not create phantom headers from Why section" do
        expect(blocks[0][:path]).to eq("app/services/post_analytics_service.rb")
        expect(blocks[1][:path]).to eq("app/services/engagement_scorer.rb")
      end
    end
  end
end
