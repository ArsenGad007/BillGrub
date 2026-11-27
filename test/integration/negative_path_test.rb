require "test_helper"

# Негативные кейсы (задание 7: интеграционное тестирование).
#
# Каждая проверка убеждается, что запрещённое действие НЕ выполняется
# и пользователь получает понятную ошибку/перенаправление.
class NegativePathTest < ActionDispatch::IntegrationTest
  # Негативный кейс 1: пользователь без прав (гость) пытается выполнить
  # действия — вместо результата его отправляют на страницу входа.
  test "гость без прав получает страницу входа вместо выполнения действий" do
    bill = bills(:under_review_bill)

    # попытка упростить текст
    assert_no_difference -> { Simplification.count } do
      post bill_simplification_path(bill)
    end
    assert_redirected_to new_user_session_path

    # попытка поставить и снять лайк
    assert_no_difference -> { Bookmark.count } do
      post bill_bookmark_path(bill)
      delete bill_bookmark_path(bill)
    end
    assert_redirected_to new_user_session_path

    # личные страницы недоступны
    get likes_path
    assert_redirected_to new_user_session_path

    get history_path
    assert_redirected_to new_user_session_path
  end

  # Негативный кейс 2: пользователь пытается упростить законопроект
  # без исходного текста — получает ошибку, запись не создаётся.
  test "упрощение законопроекта без исходного текста возвращает ошибку" do
    sign_in users(:one)
    bill = bills(:adopted_bill)
    assert bill.original_text.blank?

    assert_no_difference -> { Simplification.count } do
      post bill_simplification_path(bill)
    end

    assert_redirected_to bill_path(bill)
    follow_redirect!
    assert_response :success
    assert_select ".flash-alert",
                  text: "Не удалось упростить текст: У законопроекта нет исходного текста"
  end

  # Негативный кейс 3: повторный лайк того же законопроекта не создаёт дубль.
  test "повторный лайк не создаёт дубликат и сообщает об этом" do
    sign_in users(:one)
    bill = bills(:under_review_bill) # уже в лайках у первого пользователя
    assert users(:one).bookmarked?(bill)

    assert_no_difference -> { Bookmark.count } do
      post bill_bookmark_path(bill)
    end
    # счётчик не «разгоняется»
    assert_equal 1, bill.reload.bookmarks_count

    assert_redirected_to bill_path(bill)
    follow_redirect!
    assert_response :success
    assert_select ".flash-notice", text: "Законопроект уже в лайках."
    assert_select "#likes_bill_#{bill.id} .likes-count", text: "1"
  end

  # Негативный кейс 4: обращение к несуществующему законопроекту — 404,
  # и для карточки, и для действий над ней.
  test "несуществующий законопроект отвечает ошибкой 404" do
    sign_in users(:one)
    # Сначала успешный запрос: он фиксирует сессию в cookie. Запросы, упавшие
    # с необработанным исключением (404), сессию не записывают, поэтому без
    # этого шага warden-сессия не попадёт в cookie jar теста.
    get root_path
    assert_response :success

    missing_id = Bill.maximum(:id) + 1

    get bill_path(missing_id)
    assert_response :not_found

    post bill_bookmark_path(missing_id)
    assert_response :not_found

    post bill_simplification_path(missing_id)
    assert_response :not_found
  end

  # Негативный кейс 5: чужие данные изолированы — пользователь видит
  # только свои лайки и свою историю.
  test "чужие лайки и чужая история не попадают в личные списки" do
    sign_in users(:one)

    get likes_path
    assert_response :success
    assert_select "h2 a", text: "О цифровых услугах", count: 0 # лайк пользователя two

    get history_path
    assert_response :success
    assert_select "h2 a", text: "О местном самоуправлении", count: 0 # просмотр пользователя two
  end
end
