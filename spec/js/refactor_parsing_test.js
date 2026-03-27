// Test the extractFileHeaders and isNew logic from application.js
// Run: node spec/js/refactor_parsing_test.js

var passed = 0;
var failed = 0;

function assert(condition, message) {
  if (condition) {
    console.log("  PASS: " + message);
    passed++;
  } else {
    console.log("  FAIL: " + message);
    failed++;
  }
}

function assertEqual(actual, expected, message) {
  if (actual === expected) {
    console.log("  PASS: " + message);
    passed++;
  } else {
    console.log("  FAIL: " + message + " (expected: " + JSON.stringify(expected) + ", got: " + JSON.stringify(actual) + ")");
    failed++;
  }
}

// ---- Functions under test (copied from application.js) ----

function extractFileHeaders(text) {
  var headers = [];
  var parts = text.split(/(```ruby\n[\s\S]*?```)/g);

  for (var i = 0; i < parts.length; i++) {
    if (parts[i].indexOf("```ruby\n") !== 0) continue;

    var code = parts[i].replace(/^```ruby\n/, "").replace(/```$/, "");
    var preceding = i > 0 ? parts[i - 1] : "";
    var path = null;

    // Strategy 1: Bold header (requires New/Updated/Modified prefix)
    var boldMatch = preceding.match(/\*\*(?:New|Updated|Modified)\s*(?:file)?:\s*([a-zA-Z0-9_\/\.\-]+\.rb)\*\*/i);
    if (boldMatch) path = boldMatch[1];

    // Strategy 2: Backtick-wrapped path
    if (!path) {
      var tickMatch = preceding.match(/`([a-zA-Z0-9_\/\.\-]+\.rb)`\s*$/);
      if (tickMatch) path = tickMatch[1];
    }

    // Strategy 3: Path as comment on first line
    if (!path) {
      var firstLine = code.split("\n")[0].trim();
      var commentMatch = firstLine.match(/^#\s*([a-zA-Z0-9_\/\.\-]+\.rb)/);
      if (commentMatch) path = commentMatch[1];
    }

    headers.push({ path: path });
  }

  return headers;
}

function extractCodeBlocks(text) {
  var blocks = [];
  var regex = /```ruby\n([\s\S]*?)```/g;
  var match;
  while ((match = regex.exec(text)) !== null) {
    blocks.push(match[1]);
  }
  return blocks;
}

function isNewFile(path, originalFile) {
  return !!(path && originalFile && path !== originalFile && path.indexOf(originalFile) === -1 && originalFile.indexOf(path) === -1);
}

// ---- Tests ----

console.log("\n=== Bold Updated/New file headers ===");
(function() {
  var response = [
    "**Summary**",
    "",
    "Splitting service.",
    "",
    "**Updated file: app/services/post_analytics_service.rb**",
    "",
    "```ruby",
    "class PostAnalyticsService",
    "  def categorize_posts(posts)",
    "    EngagementScorer.new.compute(posts)",
    "  end",
    "end",
    "```",
    "",
    "**New file: app/services/engagement_scorer.rb**",
    "",
    "```ruby",
    "class EngagementScorer",
    "  def compute(posts)",
    "    42",
    "  end",
    "end",
    "```",
    "",
    "**Why**",
    "- Extracted scorer"
  ].join("\n");

  var headers = extractFileHeaders(response);
  var codeBlocks = extractCodeBlocks(response);

  assertEqual(headers.length, 2, "extracts two headers");
  assertEqual(codeBlocks.length, 2, "extracts two code blocks");
  assertEqual(headers[0].path, "app/services/post_analytics_service.rb", "updated file path correct");
  assertEqual(headers[1].path, "app/services/engagement_scorer.rb", "new file path correct");
  assert(codeBlocks[0].indexOf("PostAnalyticsService") !== -1, "first code block has updated class");
  assert(codeBlocks[1].indexOf("EngagementScorer") !== -1, "second code block has new class");

  var file = "app/services/post_analytics_service.rb";
  assertEqual(isNewFile(headers[0].path, file), false, "updated file is NOT new");
  assertEqual(isNewFile(headers[1].path, file), true, "extracted file IS new");
})();

console.log("\n=== Full production response ===");
(function() {
  var response = [
    "**Summary**",
    "",
    "This service has three responsibilities mixed into one class.",
    "",
    "**Updated file: app/services/post_analytics_service.rb**",
    "",
    "```ruby",
    "# frozen_string_literal: true",
    "",
    "class PostAnalyticsService",
    "  def categorize_posts(posts)",
    "    scorer = EngagementScorer.new",
    "    categories = { hot: [], trending: [], normal: [], stale: [], dead: [] }",
    "    posts.each do |post|",
    "      score = scorer.compute(post)",
    "      category = determine_category(post, score)",
    "      categories[category] << post",
    "    end",
    "    categories",
    "  end",
    "",
    "  def generate_weekly_digest(start_date = nil, end_date = nil)",
    "    start_date ||= 7.days.ago",
    "    end_date ||= Time.now",
    "    { period: { start: start_date, end: end_date } }",
    "  end",
    "",
    "  private",
    "",
    "  def determine_category(post, engagement_score)",
    "    case engagement_score",
    "    when 100..Float::INFINITY then :hot",
    "    when 50..99 then :trending",
    "    else :normal",
    "    end",
    "  end",
    "end",
    "```",
    "",
    "**New file: app/services/engagement_scorer.rb**",
    "",
    "```ruby",
    "# frozen_string_literal: true",
    "",
    "class EngagementScorer",
    "  BASE_SCORES = {",
    "    published_recent: 50,",
    "    published_week: 30",
    "  }.freeze",
    "",
    "  def compute(post, weight: 1.0)",
    "    score = base_score(post) * weight",
    "    score += comment_bonus(post)",
    "    score.round(2)",
    "  end",
    "",
    "  private",
    "",
    "  def base_score(post)",
    "    0",
    "  end",
    "",
    "  def comment_bonus(post)",
    "    post.comments.count * 10",
    "  end",
    "end",
    "```",
    "",
    "**Why**",
    "",
    "- Extracted scorer into its own class.",
    "- Simplified categorization."
  ].join("\n");

  var headers = extractFileHeaders(response);
  var codeBlocks = extractCodeBlocks(response);

  assertEqual(headers.length, 2, "extracts two headers");
  assertEqual(headers[0].path, "app/services/post_analytics_service.rb", "updated file path");
  assertEqual(headers[1].path, "app/services/engagement_scorer.rb", "new file path");
  assert(codeBlocks[0].indexOf("generate_weekly_digest") !== -1, "updated file has digest method");
  assert(codeBlocks[0].indexOf("determine_category") !== -1, "updated file has category method");
  assert(codeBlocks[1].indexOf("BASE_SCORES") !== -1, "new file has constants");
  assert(codeBlocks[1].indexOf("comment_bonus") !== -1, "new file has bonus method");
})();

console.log("\n=== Backtick-wrapped path headers ===");
(function() {
  var response = [
    "`app/services/post_analytics_service.rb`",
    "```ruby",
    "class PostAnalyticsService",
    "end",
    "```",
    "",
    "`app/services/engagement_scorer.rb`",
    "```ruby",
    "class EngagementScorer",
    "end",
    "```"
  ].join("\n");

  var headers = extractFileHeaders(response);
  assertEqual(headers.length, 2, "extracts two headers");
  assertEqual(headers[0].path, "app/services/post_analytics_service.rb", "first path");
  assertEqual(headers[1].path, "app/services/engagement_scorer.rb", "second path");
})();

console.log("\n=== Inline comment paths ===");
(function() {
  var response = [
    "```ruby",
    "# app/services/post_analytics_service.rb",
    "class PostAnalyticsService",
    "end",
    "```",
    "",
    "```ruby",
    "# app/services/engagement_scorer.rb",
    "class EngagementScorer",
    "end",
    "```"
  ].join("\n");

  var headers = extractFileHeaders(response);
  assertEqual(headers.length, 2, "extracts two headers");
  assertEqual(headers[0].path, "app/services/post_analytics_service.rb", "first path");
  assertEqual(headers[1].path, "app/services/engagement_scorer.rb", "second path");
})();

console.log("\n=== Single code block no path ===");
(function() {
  var response = [
    "```ruby",
    "class PostAnalyticsService",
    "  def score(post)",
    "    42",
    "  end",
    "end",
    "```"
  ].join("\n");

  var headers = extractFileHeaders(response);
  assertEqual(headers.length, 1, "extracts one header");
  assertEqual(headers[0].path, null, "path is null");
})();

console.log("\n=== Mixed formats ===");
(function() {
  var response = [
    "**Updated file: app/services/post_analytics_service.rb**",
    "",
    "```ruby",
    "class PostAnalyticsService",
    "end",
    "```",
    "",
    "```ruby",
    "# app/services/engagement_scorer.rb",
    "class EngagementScorer",
    "end",
    "```"
  ].join("\n");

  var headers = extractFileHeaders(response);
  assertEqual(headers.length, 2, "extracts two headers");
  assertEqual(headers[0].path, "app/services/post_analytics_service.rb", "bold header works");
  assertEqual(headers[1].path, "app/services/engagement_scorer.rb", "inline comment fallback works");
})();

console.log("\n=== isNew detection ===");
(function() {
  var file = "app/services/post_analytics_service.rb";

  assertEqual(isNewFile("app/services/post_analytics_service.rb", file), false, "same path is not new");
  assertEqual(isNewFile("app/services/engagement_scorer.rb", file), true, "different path is new");
  assertEqual(isNewFile(null, file), false, "null path is not new");
  assertEqual(isNewFile("app/services/post_analytics_service.rb", null), false, "null file is not new");
})();

console.log("\n=== UI renders correct badge ===");
(function() {
  var response = [
    "**Updated file: app/services/post_analytics_service.rb**",
    "",
    "```ruby",
    "class PostAnalyticsService",
    "end",
    "```",
    "",
    "**New file: app/services/engagement_scorer.rb**",
    "",
    "```ruby",
    "class EngagementScorer",
    "end",
    "```"
  ].join("\n");

  var file = "app/services/post_analytics_service.rb";
  var headers = extractFileHeaders(response);
  var codeBlocks = extractCodeBlocks(response);

  var fileChanges = codeBlocks.map(function(code, i) {
    var header = headers[i];
    var path = (header && header.path) ? header.path : file;
    var isNew = path && file && path !== file && path.indexOf(file) === -1 && file.indexOf(path) === -1;
    return { path: path, isNew: isNew, code: code };
  });

  assertEqual(fileChanges.length, 2, "two file changes");
  assertEqual(fileChanges[0].path, "app/services/post_analytics_service.rb", "first is original file");
  assertEqual(fileChanges[0].isNew, false, "original file is NOT new");
  assertEqual(fileChanges[1].path, "app/services/engagement_scorer.rb", "second is extracted file");
  assertEqual(fileChanges[1].isNew, true, "extracted file IS new");

  // Simulate badge rendering
  var badges = fileChanges.map(function(c) {
    return c.isNew ? "NEW" : null;
  });
  assertEqual(badges[0], null, "no badge on modified file");
  assertEqual(badges[1], "NEW", "NEW badge on new file");
})();

console.log("\n=== Does not match bold .rb references in prose ===");
(function() {
  var response = [
    "**Updated file: app/services/post_analytics_service.rb**",
    "",
    "```ruby",
    "class PostAnalyticsService",
    "  def score",
    "    EngagementScorer.new.compute",
    "  end",
    "end",
    "```",
    "",
    "**New file: app/services/engagement_scorer.rb**",
    "",
    "```ruby",
    "class EngagementScorer",
    "  def compute",
    "    42",
    "  end",
    "end",
    "```",
    "",
    "**Why**",
    "",
    "- Extracted **app/services/engagement_scorer.rb** for single responsibility",
    "- The **post_analytics_service.rb** is now a thin wrapper"
  ].join("\n");

  var headers = extractFileHeaders(response);
  var codeBlocks = extractCodeBlocks(response);

  assertEqual(headers.length, 2, "extracts exactly two headers, not more");
  assertEqual(codeBlocks.length, 2, "extracts exactly two code blocks");
  assertEqual(headers[0].path, "app/services/post_analytics_service.rb", "first header is correct");
  assertEqual(headers[1].path, "app/services/engagement_scorer.rb", "second header is correct");

  var file = "app/services/post_analytics_service.rb";
  var fileChanges = codeBlocks.map(function(code, i) {
    var header = headers[i];
    var path = (header && header.path) ? header.path : file;
    var isNew = !!(path && file && path !== file && path.indexOf(file) === -1 && file.indexOf(path) === -1);
    return { path: path, isNew: isNew };
  });

  assertEqual(fileChanges[0].isNew, false, "updated file is NOT marked new");
  assertEqual(fileChanges[1].isNew, true, "new file IS marked new");
})();

// ---- Summary ----
console.log("\n" + "=".repeat(40));
console.log("Results: " + passed + " passed, " + failed + " failed");
if (failed > 0) {
  process.exit(1);
} else {
  console.log("All tests passed!");
}
