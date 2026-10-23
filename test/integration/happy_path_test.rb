require "test_helper"

# Сквозной happy path пользователя:
# смотрим список -> открываем законопроект -> упрощаем -> сохраняем -> видим в закладках и истории.
class HappyPathTest < ActionDispatch::IntegrationTest
  test "гость видит список законопроектов и открывает карточку" do
    get root_path
    assert_response :success
    assert_select "a", text: "О защите персональных данных"

    get bill_path(bills(:under_review_bill))
    assert_response :success
    assert_select "h1", text: "О защите персональных данных"
  end

  test "поиск фильтрует законопроекты по запросу" do
    get root_path, params: { q: "образовании" }
    assert_response :success
    assert_select "h2", text: "Об образовании"
    assert_select "h2", text: "О цифровых услугах", count: 0
  end

  test "пользователь упрощает текст законопроекта" do
    sign_in users(:one)
    bill = bills(:under_review_bill)

    assert_difference -> { bill.simplifications.count }, 1 do
      post bill_simplification_path(bill)
    end
    assert_redirected_to bill_path(bill)

    follow_redirect!
    assert_response :success
    assert_select "section.simplified p", /Коротко:/
    assert_not_nil bill.reload.latest_simplification
  end

  test "пользователь ставит и снимает закладку" do
    sign_in users(:one)
    bill = bills(:adopted_bill) # у первого пользователя её ещё нет

    assert_difference -> { Bookmark.count }, 1 do
      post bill_bookmark_path(bill)
    end
    assert_redirected_to bill_path(bill)

    follow_redirect!
    assert_select "form[action=?]", bill_bookmark_path(bill)

    assert_difference -> { Bookmark.count }, -1 do
      delete bill_bookmark_path(bill)
    end
    assert_redirected_to bill_path(bill)
  end

  test "закладки пользователя видны на странице лайков" do
    sign_in users(:one)

    get likes_path
    assert_response :success
    assert_select "h2 a", text: "О защите персональных данных"
  end

  test "просмотренные законопроекты видны в истории" do
    sign_in users(:one)
    bill = bills(:adopted_bill)

    get bill_path(bill) # записываем просмотр
    assert_response :success

    get history_path
    assert_response :success
    assert_select "h2 a", text: "О местном самоуправлении"
  end

  test "неавторизованный пользователь отправляется на вход при действии" do
    bill = bills(:under_review_bill)

    post bill_bookmark_path(bill)
    assert_redirected_to new_user_session_path
  end
end
