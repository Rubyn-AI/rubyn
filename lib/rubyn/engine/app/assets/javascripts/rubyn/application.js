// Rubyn Dashboard JavaScript
(function() {
  "use strict";

  var pendingRequests = 0;

  function trackRequest(promise) {
    pendingRequests++;
    return promise.finally(function() { pendingRequests--; });
  }

  window.addEventListener("beforeunload", function(e) {
    if (pendingRequests > 0) {
      e.preventDefault();
      e.returnValue = "";
    }
  });

  document.addEventListener("DOMContentLoaded", function() {
    initChatForm();
    initToolPages();
  });

  function initChatForm() {
    var form = document.getElementById("chat-form");
    if (!form) return;

    var input = document.getElementById("message-input");

    // Submit on Enter (Shift+Enter for newline)
    input.addEventListener("keydown", function(e) {
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault();
        form.dispatchEvent(new Event("submit"));
      }
    });

    form.addEventListener("submit", function(e) {
      e.preventDefault();
      var message = input.value.trim();
      if (!message) return;

      hideEmptyState();
      appendMessage("you", message);
      input.value = "";
      input.focus();
      sendMessage(message);
    });
  }

  function hideEmptyState() {
    var empty = document.getElementById("empty-state");
    if (empty) empty.remove();
  }

  function appendMessage(role, content) {
    var container = document.getElementById("messages");
    if (!container) return;

    var div = document.createElement("div");
    div.className = "rubyn-message rubyn-message-" + role;

    var label = document.createElement("div");
    label.className = "rubyn-message-label";
    label.textContent = role === "you" ? "You" : "Rubyn";

    var body = document.createElement("div");
    body.className = "rubyn-message-body";

    if (role === "rubyn" && content.includes("```")) {
      body.innerHTML = formatMessageWithCode(content);
      highlightCodeBlocks(body);
    } else {
      body.textContent = content;
    }

    div.appendChild(label);
    div.appendChild(body);
    container.appendChild(div);
    container.scrollTop = container.scrollHeight;

    return div;
  }

  function appendThinking() {
    var container = document.getElementById("messages");
    if (!container) return;

    var div = document.createElement("div");
    div.className = "rubyn-message rubyn-message-rubyn";
    div.id = "thinking-indicator";

    var label = document.createElement("div");
    label.className = "rubyn-message-label";
    label.textContent = "Rubyn";

    var dots = document.createElement("div");
    dots.className = "rubyn-dots";
    dots.innerHTML = "<span></span><span></span><span></span>";

    div.appendChild(label);
    div.appendChild(dots);
    container.appendChild(div);
    container.scrollTop = container.scrollHeight;
  }

  function removeThinking() {
    var el = document.getElementById("thinking-indicator");
    if (el) el.remove();
  }

  var conversationId = null;

  function sendMessage(message) {
    appendThinking();

    var csrfToken = document.querySelector('meta[name="csrf-token"]');
    var headers = { "Content-Type": "application/json" };
    if (csrfToken) headers["X-CSRF-Token"] = csrfToken.content;

    trackRequest(
      fetch(mountPath() + "/agent", {
        method: "POST",
        headers: headers,
        body: JSON.stringify({
          message: message,
          conversation_id: conversationId
        })
      })
      .then(function(res) { return res.json(); })
      .then(function(data) {
        removeThinking();
        if (data.error) {
          appendMessage("rubyn", "Error: " + data.error);
        } else {
          conversationId = data.conversation_id || conversationId;
          appendMessage("rubyn", data.response || data.content || "No response");
        }
      })
      .catch(function(err) {
        removeThinking();
        appendMessage("rubyn", "Connection error: " + err.message);
      })
    );
  }

  // ---- Tool pages (refactor, spec, review) ----

  var TOOL_PAGES = {
    "diff-container": "refactor",
    "spec-container": "specs",
    "review-container": "reviews"
  };

  function initToolPages() {
    Object.keys(TOOL_PAGES).forEach(function(containerId) {
      var container = document.getElementById(containerId);
      if (!container) return;

      var resource = TOOL_PAGES[containerId];
      var fileParam = new URLSearchParams(window.location.search).get("file");
      if (!fileParam) return;

      // Restore from sessionStorage if available
      var cacheKey = "rubyn:" + resource + ":" + fileParam;
      var cached = sessionStorage.getItem(cacheKey);
      if (cached) {
        var headers = buildHeaders();
        var cachedId = sessionStorage.getItem(cacheKey + ":id");
        var cachedCredits = sessionStorage.getItem(cacheKey + ":credits");
        renderToolResponse(container, resource, fileParam, cached, headers, cachedId ? parseInt(cachedId) : null, cachedCredits ? parseFloat(cachedCredits) : null);
        return;
      }

      runTool(container, resource, fileParam);
    });
  }

  function buildHeaders() {
    var csrfToken = document.querySelector('meta[name="csrf-token"]');
    var headers = { "Content-Type": "application/json" };
    if (csrfToken) headers["X-CSRF-Token"] = csrfToken.content;
    return headers;
  }

  function runTool(container, resource, file) {
    var headers = buildHeaders();

    trackRequest(
      fetch(rubynMountPath() + "/" + resource, {
        method: "POST",
        headers: headers,
        body: JSON.stringify({ file: file })
      })
      .then(function(res) { return res.json(); })
      .then(function(data) {
        if (data.error) {
          container.innerHTML = '<div class="rubyn-tool-empty"><p>Error: ' + escapeHtml(data.error) + '</p></div>';
        } else {
          var response = data.response || "No response";
          var interactionId = data.interaction_id;
          var creditsUsed = data.credits_used;
          // Cache the response and interaction ID so they survive page navigation
          var cacheKey = "rubyn:" + resource + ":" + file;
          sessionStorage.setItem(cacheKey, response);
          if (interactionId) sessionStorage.setItem(cacheKey + ":id", String(interactionId));
          if (creditsUsed != null) sessionStorage.setItem(cacheKey + ":credits", String(creditsUsed));
          renderToolResponse(container, resource, file, response, headers, interactionId, creditsUsed);
        }
      })
      .catch(function(err) {
        container.innerHTML = '<div class="rubyn-tool-empty"><p>Connection error: ' + escapeHtml(err.message) + '</p></div>';
      })
    );
  }

  function renderToolResponse(container, resource, file, response, headers, interactionId, creditsUsed) {
    var codeBlocks = extractCodeBlocks(response);

    if (resource === "refactor" && codeBlocks.length > 0) {
      renderRefactorResponse(container, file, response, codeBlocks, headers, interactionId);
    } else if (resource === "specs" && codeBlocks.length > 0) {
      renderSpecResponse(container, file, response, codeBlocks, headers);
    } else {
      container.innerHTML = '<pre class="rubyn-tool-output"><code>' + escapeHtml(response) + '</code></pre>';
    }

    // Show credits used and feedback in a footer bar
    var footer = document.createElement("div");
    footer.className = "rubyn-tool-footer";

    if (creditsUsed != null) {
      var badge = document.createElement("span");
      badge.className = "rubyn-credits-badge";
      badge.textContent = creditsUsed + (creditsUsed === 1 ? " credit used" : " credits used");
      footer.appendChild(badge);
    }

    if (interactionId) {
      appendFeedbackButtons(footer, interactionId, headers);
    }

    if (footer.children.length > 0) {
      container.appendChild(footer);
    }
  }

  function appendFeedbackButtons(parent, interactionId, headers) {
    var wrapper = document.createElement("div");
    wrapper.className = "rubyn-feedback";
    wrapper.innerHTML =
      '<span class="rubyn-feedback-label">How did Rubyn do?</span>' +
      '<button class="rubyn-feedback-btn" data-rating="thumbs_up" title="Helpful">' +
        '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 9V5a3 3 0 0 0-3-3l-4 9v11h11.28a2 2 0 0 0 2-1.7l1.38-9a2 2 0 0 0-2-2.3H14zM7 22H4a2 2 0 0 1-2-2v-7a2 2 0 0 1 2-2h3"/></svg>' +
      '</button>' +
      '<button class="rubyn-feedback-btn" data-rating="thumbs_down" title="Not helpful">' +
        '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M10 15v4a3 3 0 0 0 3 3l4-9V2H5.72a2 2 0 0 0-2 1.7l-1.38 9a2 2 0 0 0 2 2.3H10zM17 2h2.4a2 2 0 0 1 2 2v7a2 2 0 0 1-2 2H17"/></svg>' +
      '</button>';

    wrapper.querySelectorAll(".rubyn-feedback-btn").forEach(function(btn) {
      btn.addEventListener("click", function() {
        var rating = btn.getAttribute("data-rating");
        submitFeedback(interactionId, rating, headers, wrapper);
      });
    });

    parent.appendChild(wrapper);
  }

  function submitFeedback(interactionId, rating, headers, wrapper) {
    wrapper.querySelectorAll(".rubyn-feedback-btn").forEach(function(b) { b.disabled = true; });

    fetch(rubynMountPath() + "/feedback", {
      method: "POST",
      headers: headers,
      body: JSON.stringify({ interaction_id: interactionId, rating: rating })
    })
    .then(function(res) { return res.json(); })
    .then(function(data) {
      if (data.success) {
        var label = rating === "thumbs_up" ? "Thanks for the feedback!" : "Sorry about that. We'll improve.";
        wrapper.innerHTML = '<span class="rubyn-feedback-label rubyn-feedback-thanks">' + label + '</span>';
      }
    })
    .catch(function() {
      wrapper.querySelectorAll(".rubyn-feedback-btn").forEach(function(b) { b.disabled = false; });
    });
  }

  function renderRefactorResponse(container, file, response, codeBlocks, headers, interactionId) {
    var html = '';
    var fileHeaders = extractFileHeaders(response);

    // Build the file-to-code mapping
    // Headers and code blocks are in the same order — zip them together
    // Determine NEW vs MODIFIED by comparing path against the original file
    var fileChanges = codeBlocks.map(function(code, i) {
      var header = fileHeaders[i];
      var path = header ? header.path : file;
      var isNew = path !== file && !path.endsWith("/" + file) && !file.endsWith("/" + path);
      return {
        path: path,
        isNew: isNew,
        code: code
      };
    });

    // Show each code block with its file path and NEW badge if applicable
    fileChanges.forEach(function(change, i) {
      html += '<div class="rubyn-code-block">';
      html += '<div class="rubyn-code-block-header">';
      if (change.isNew) {
        html += '<span class="rubyn-file-tag rubyn-tag-new">NEW</span>';
      }
      html += '<span class="rubyn-tool-filepath">' + escapeHtml(change.path) + '</span>';
      html += '<div class="rubyn-code-block-actions">';
      html += '<button class="rubyn-btn-sm rubyn-apply-one" data-index="' + i + '">Apply</button>';
      html += '<button class="rubyn-btn-sm rubyn-copy-btn" data-index="' + i + '">Copy</button>';
      html += '</div>';
      html += '</div>';
      html += '<pre class="rubyn-tool-output"><code>' + escapeHtml(change.code) + '</code></pre>';
      html += '</div>';
    });

    // Action bar
    html += '<div class="rubyn-tool-actions">';
    if (fileChanges.length > 1) {
      html += '<button class="rubyn-btn" id="apply-all-btn">Apply All (' + fileChanges.length + ' files)</button>';
    } else {
      html += '<button class="rubyn-btn" id="apply-all-btn">Apply Changes</button>';
    }
    html += '<button class="rubyn-btn rubyn-btn--ghost" id="clear-cache-btn">Discard</button>';
    html += '<button class="rubyn-btn rubyn-btn--ghost" id="toggle-explanation-btn">Show Explanation</button>';
    html += '</div>';

    // Collapsible explanation
    html += '<div class="rubyn-explanation rubyn-explanation--collapsed" id="explanation-section">';
    html += '<pre class="rubyn-tool-output"><code>' + escapeHtml(response) + '</code></pre>';
    html += '</div>';

    container.innerHTML = html;
    highlightCodeBlocks(container);

    // Wire up Apply All
    var applyAllBtn = document.getElementById("apply-all-btn");
    applyAllBtn.addEventListener("click", function() {
      applyAllBtn.disabled = true;
      applyAllBtn.textContent = "Applying...";
      applyAllFiles(fileChanges, headers, applyAllBtn, container, file);
    });

    // Wire up Discard (clears cache and reloads)
    document.getElementById("clear-cache-btn").addEventListener("click", function() {
      var cacheKey = "rubyn:refactor:" + file;
      sessionStorage.removeItem(cacheKey);
      window.location.reload();
    });

    // Wire up explanation toggle
    var toggleBtn = document.getElementById("toggle-explanation-btn");
    var explanationSection = document.getElementById("explanation-section");
    toggleBtn.addEventListener("click", function() {
      explanationSection.classList.toggle("rubyn-explanation--collapsed");
      toggleBtn.textContent = explanationSection.classList.contains("rubyn-explanation--collapsed")
        ? "Show Explanation" : "Hide Explanation";
    });

    // Wire up individual apply buttons
    container.querySelectorAll(".rubyn-apply-one").forEach(function(btn) {
      btn.addEventListener("click", function() {
        var idx = parseInt(btn.getAttribute("data-index"));
        var change = fileChanges[idx];
        applyRefactor(change.path, change.code, headers, btn);
      });
    });

    // Wire up copy buttons
    container.querySelectorAll(".rubyn-copy-btn").forEach(function(btn) {
      btn.addEventListener("click", function() {
        var idx = parseInt(btn.getAttribute("data-index"));
        navigator.clipboard.writeText(codeBlocks[idx]);
        btn.textContent = "Copied!";
        setTimeout(function() { btn.textContent = "Copy"; }, 2000);
      });
    });
  }

  function applyAllFiles(fileChanges, headers, button, container, sourceFile) {
    var applied = 0;
    var failed = 0;
    var total = fileChanges.length;

    fileChanges.forEach(function(change, i) {
      trackRequest(
        fetch(rubynMountPath() + "/refactor", {
          method: "PATCH",
          headers: headers,
          body: JSON.stringify({ file: change.path, code: change.code })
        })
        .then(function(res) { return res.json(); })
        .then(function(data) {
          if (data.success) {
            applied++;
            // Mark the individual block as applied
            var applyBtn = container.querySelector('.rubyn-apply-one[data-index="' + i + '"]');
            if (applyBtn) {
              applyBtn.textContent = "Applied";
              applyBtn.className = "rubyn-btn-sm rubyn-btn--success";
              applyBtn.disabled = true;
            }
          } else {
            failed++;
          }
        })
        .catch(function() { failed++; })
        .finally(function() {
          if (applied + failed === total) {
            if (failed === 0) {
              button.textContent = "All " + applied + " files applied";
              button.className = "rubyn-btn rubyn-btn--success";
              // Clear cached response — changes are on disk now
              sessionStorage.removeItem("rubyn:refactor:" + sourceFile);
            } else {
              button.textContent = applied + " applied, " + failed + " failed";
              button.disabled = false;
            }
          }
        })
      );
    });
  }

  function renderSpecResponse(container, file, response, codeBlocks, headers) {
    var specPath = deriveSpecPath(file);
    var html = '';

    html += '<div class="rubyn-code-block">';
    html += '<div class="rubyn-code-block-header">';
    html += '<span class="rubyn-tool-filepath">' + escapeHtml(specPath) + '</span>';
    html += '<button class="rubyn-btn-sm rubyn-copy-btn" id="copy-spec-btn">Copy</button>';
    html += '</div>';
    html += '<pre class="rubyn-tool-output"><code>' + escapeHtml(codeBlocks[0]) + '</code></pre>';
    html += '</div>';

    html += '<div class="rubyn-tool-actions">';
    html += '<button class="rubyn-btn" id="write-spec-btn">Write to ' + escapeHtml(specPath) + '</button>';
    html += '</div>';

    if (codeBlocks.length > 1 || response.length > codeBlocks[0].length + 50) {
      html += '<div class="rubyn-explanation rubyn-explanation--collapsed" id="explanation-section">';
      html += '<pre class="rubyn-tool-output"><code>' + escapeHtml(response) + '</code></pre>';
      html += '</div>';
      html += '<button class="rubyn-btn-sm" id="toggle-explanation-btn" style="margin-top:0.5rem">Show Full Response</button>';
    }

    container.innerHTML = html;
    highlightCodeBlocks(container);

    document.getElementById("write-spec-btn").addEventListener("click", function() {
      applyRefactor(specPath, codeBlocks[0], headers, this);
    });

    document.getElementById("copy-spec-btn").addEventListener("click", function() {
      navigator.clipboard.writeText(codeBlocks[0]);
      this.textContent = "Copied!";
      var btn = this;
      setTimeout(function() { btn.textContent = "Copy"; }, 2000);
    });

    var expToggle = document.getElementById("toggle-explanation-btn");
    if (expToggle) {
      expToggle.addEventListener("click", function() {
        var section = document.getElementById("explanation-section");
        section.classList.toggle("rubyn-explanation--collapsed");
        expToggle.textContent = section.classList.contains("rubyn-explanation--collapsed")
          ? "Show Full Response" : "Hide Full Response";
      });
    }
  }

  function extractFileHeaders(text) {
    var headers = [];
    var parts = text.split(/(```ruby\n[\s\S]*?```)/g);

    for (var i = 0; i < parts.length; i++) {
      if (parts[i].indexOf("```ruby\n") !== 0) continue;

      var code = parts[i].replace(/^```ruby\n/, "").replace(/```$/, "");
      var preceding = i > 0 ? parts[i - 1] : "";
      var path = null;

      // Strategy 1: Bold header above code block
      // **New file: path.rb** or **path.rb**
      var boldMatch = preceding.match(/\*\*(?:New file:\s*|Modified:\s*)?([a-zA-Z0-9_\/\.\-]+\.rb)\*\*/i);
      if (boldMatch) path = boldMatch[1];

      // Strategy 2: Backtick-wrapped path above code block
      if (!path) {
        var tickMatch = preceding.match(/`([a-zA-Z0-9_\/\.\-]+\.rb)`\s*$/);
        if (tickMatch) path = tickMatch[1];
      }

      // Strategy 3: Path as comment on first line inside code block
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

  function deriveSpecPath(filePath) {
    return filePath.replace(/^app\//, "spec/").replace(/\.rb$/, "_spec.rb");
  }

  function applyRefactor(file, code, headers, button) {
    button.disabled = true;
    button.textContent = "Applying...";

    trackRequest(
      fetch(rubynMountPath() + "/refactor", {
        method: "PATCH",
        headers: headers,
        body: JSON.stringify({ file: file, code: code })
      })
      .then(function(res) { return res.json(); })
      .then(function(data) {
        if (data.success) {
          button.textContent = data.message || "Applied";
          button.className = "rubyn-btn rubyn-btn--success";
          // Clear cache for this file
          sessionStorage.removeItem("rubyn:refactor:" + file);
          sessionStorage.removeItem("rubyn:specs:" + file);
        } else {
          button.textContent = "Failed: " + (data.error || "Unknown error");
          button.disabled = false;
        }
      })
      .catch(function(err) {
        button.textContent = "Error: " + err.message;
        button.disabled = false;
      })
    );
  }

  function escapeHtml(text) {
    var div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
  }

  // Convert markdown-style code blocks to <pre><code> and escape the rest
  function formatMessageWithCode(text) {
    var parts = text.split(/(```\w*\n[\s\S]*?```)/g);
    return parts.map(function(part) {
      var match = part.match(/^```(\w*)\n([\s\S]*?)```$/);
      if (match) {
        var lang = match[1] || "ruby";
        return '<pre class="rubyn-tool-output"><code class="language-' + lang + '">' + escapeHtml(match[2]) + '</code></pre>';
      }
      return '<p>' + escapeHtml(part).replace(/\n/g, '<br>') + '</p>';
    }).join('');
  }

  function highlightCodeBlocks(container) {
    if (typeof hljs === "undefined") return;
    container.querySelectorAll("pre code").forEach(function(block) {
      // Add language class for highlight.js
      if (!block.className) block.className = "language-ruby";
      hljs.highlightElement(block);
    });
  }

  function rubynMountPath() {
    var path = window.location.pathname;
    var segments = ["agent", "refactor", "specs", "reviews", "files", "settings"];
    for (var i = 0; i < segments.length; i++) {
      var idx = path.indexOf("/" + segments[i]);
      if (idx > 0) return path.substring(0, idx);
    }
    return "/rubyn";
  }

  function mountPath() {
    return rubynMountPath();
  }
})();
