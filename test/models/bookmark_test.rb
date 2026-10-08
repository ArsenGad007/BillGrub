require "test_helper"

class BookmarkTest < ActiveSupport::TestCase
  # ===== Контекст 1: toggle! =====

  test "toggle! ставит закладку, если её не было, и возвращает true" do
    user, bill = users(:two), bills(:under_review_bill)

    assert_difference "Bookmark.count", 1 do
      assert_equal true, Bookmark.toggle!(user: user, bill: bill)
    end
    assert user.bookmarked?(bill)
  end

  test "toggle! снимает закладку, если она была, и возвращает false" do
    user, bill = users(:one), bills(:under_review_bill)

    assert_difference "Bookmark.count", -1 do
      assert_equal false, Bookmark.toggle!(user: user, bill: bill)
    end
    assert_not user.bookmarked?(bill)
  end

  # ===== Контекст 2: уникальность и ассоциации =====

  test "нельзя добавить один законопроект в закладки дважды" do
    dup = Bookmark.new(user: users(:one), bill: bills(:under_review_bill))
    assert_not dup.valid?
  end

  test "закладки удаляются вместе с законопроектом" do
    assert_difference "Bookmark.count", -1 do
      bills(:under_review_bill).destroy
    end
  end
end
