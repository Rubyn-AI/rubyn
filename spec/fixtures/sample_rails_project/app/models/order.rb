class Order < ApplicationRecord
  belongs_to :user
  has_many :line_items

  validates :total, presence: true, numericality: { greater_than: 0 }

  scope :recent, -> { where("created_at > ?", 30.days.ago) }
end
