require "test_helper"

class ViewHistoryTest < ActiveSupport::TestCase
  # ===== Контекст 1: record! =====

  test "record! создаёт запись о просмотре" do
    user, bill = users(:two), bills(:under_review_bill)

    assert_difference "ViewHistory.count", 1 do
      ViewHistory.record!(user: user, bill: bill)
    end
  end

  test "повторный просмотр обновляет время, а не создаёт дубль" do
    user, bill = users(:one), bills(:under_review_bill)
    later = Time.zone.local(2026, 10, 8, 9, 0)

    assert_no_difference "ViewHistory.count" do
      ViewHistory.record!(user: user, bill: bill, at: later)
    end
    assert_equal later, view_histories(:old_view).reload.viewed_at
  end

  # ===== Контекст 2: User#recent_bills =====

  test "recent_bills отдаёт просмотренное, новые сверху" do
    assert_equal [ bills(:simplified_bill), bills(:under_review_bill) ],
                 users(:one).recent_bills.to_a
  end

  test "recent_bills не показывает чужую историю и уважает лимит" do
    assert_equal [ bills(:simplified_bill) ], users(:two).recent_bills.to_a
    assert_equal 1, users(:one).recent_bills(1).to_a.size
  end

  test "viewed_at проставляется автоматически, если не указан" do
    entry = ViewHistory.create!(user: users(:two), bill: bills(:adopted_bill))
    assert_not_nil entry.viewed_at
  end
end
