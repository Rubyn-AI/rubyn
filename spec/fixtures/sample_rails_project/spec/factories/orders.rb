FactoryBot.define do
  factory :order do
    user
    total { 29.99 }
  end
end
