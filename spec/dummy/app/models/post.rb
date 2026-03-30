# frozen_string_literal: true

class Post < ApplicationRecord
  scope :published, -> { where(status: "published") }
end
