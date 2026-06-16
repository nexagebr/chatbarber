FactoryBot.define do
  factory :appointment do
    account { nil }
    user { nil }
    contact { nil }
    start_at { "2026-02-14 23:58:51" }
    end_at { "2026-02-14 23:58:51" }
    status { 1 }
    notes { "MyText" }
  end
end
