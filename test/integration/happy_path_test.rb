require "test_helper"

# Подробный happy path пользователя (задание 7: интеграционное тестирование).
#
# Сценарий: гость изучает список -> находит законопроект поиском -> открывает
# карточку -> регистрируется -> упрощает текст нейросетью -> ставит лайк ->
# проверяет страницу лайков и историю -> выходит из аккаунта.
class HappyPathTest < ActionDispatch::IntegrationTest
  # ===== Контекст 1: гость без аккаунта =====

  test "гость видит список законопроектов со счётчиками лайков" do
    get root_path
    assert_response :success

    assert_select "h2 a", text: "О защите персональных данных"
    assert_select "h2 a", text: "Об образовании"

    # Счётчики лайков на карточках совпадают с данными фикстур
    assert_select "#likes_bill_#{bills(:under_review_bill).id} .likes-count",
                  text: bills(:under_review_bill).bookmarks_count.to_s
    assert_select "#likes_bill_#{bills(:adopted_bill).id} .likes-count", text: "0"
  end

  test "поиск фильтрует законопроекты по запросу" do
    get root_path, params: { q: "образовании" }
    assert_response :success
    assert_select "h2", text: "Об образовании"
    assert_select "h2", text: "О цифровых услугах", count: 0
  end

  test "гость открывает карточку и видит оба текста, но без кнопки упрощения" do
    bill = bills(:in_progress_bill)

    get bill_path(bill)
    assert_response :success
    assert_select "h1", text: "Об образовании"
    assert_select "section.bill-text > p", text: bill.original_text
    assert_select "section.simplified .empty", text: "Пока нет упрощённой версии."
    # Упрощение доступно только авторизованным
    assert_select "form[action=?]", bill_simplification_path(bill), count: 0
    # Карточка подписана на поток лайков (real-time)
    assert_select "turbo-cable-stream-source[channel='Turbo::StreamsChannel']"
  end

  # ===== Контекст 2: регистрация =====

  test "новый пользователь регистрируется и сразу попадает в приложение" do
    email = "newcomer@example.com"

    assert_difference -> { User.count }, 1 do
      post user_registration_path,
           params: { user: { email: email, password: "qwerty123", password_confirmation: "qwerty123" } }
    end

    assert_redirected_to root_path
    follow_redirect!
    assert_select ".account-email", text: email
    assert_match(/Выйти/, response.body)
  end

  # ===== Контекст 3: упрощение текста нейросетью =====

  test "пользователь упрощает текст и получает короткую версию" do
    sign_in users(:one)
    bill = bills(:under_review_bill) # есть исходный текст, прошлые попытки неудачные

    assert_difference -> { bill.simplifications.count }, 1 do
      post bill_simplification_path(bill)
    end

    assert_redirected_to bill_path(bill)
    follow_redirect!
    assert_response :success
    assert_select ".flash-notice", text: "Готово! Мы упростили текст законопроекта."

    # Запись упрощения заполнена корректно
    simplification = bill.simplifications.completed.sole
    assert_equal NeuralSimplifier::MODEL_NAME, simplification.model_name_used
    assert_equal bill.original_text.length, simplification.input_chars
    assert_equal simplification.content.length, simplification.output_chars
    assert_not_nil simplification.completed_at
    assert_not simplification.suspicious?

    # На карточке показана упрощённая версия и модель
    assert_includes bill.reload.display_text, "Коротко:"
    assert_select "section.simplified p", text: simplification.content
    assert_select "section.simplified .hint", text: "Модель: #{NeuralSimplifier::MODEL_NAME}"
    # Кнопка сменила подпись: можно упростить заново
    assert_match(/Упростить заново/, response.body)
  end

  # ===== Контекст 4: лайки =====

  test "пользователь ставит лайк, снимает его и ставит снова" do
    sign_in users(:one)
    bill = bills(:adopted_bill)
    assert bill.bookmarks_count.zero?

    assert_difference -> { Bookmark.count }, 1 do
      post bill_bookmark_path(bill)
    end
    assert_redirected_to bill_path(bill)

    follow_redirect!
    assert_response :success
    assert_select ".flash-notice", text: "Законопроект добавлен в лайки."
    assert_select "#likes_bill_#{bill.id} .likes-count", text: "1"
    assert_match(/Убрать из лайков/, response.body)

    assert_difference -> { Bookmark.count }, -1 do
      delete bill_bookmark_path(bill)
    end
    follow_redirect!
    assert_select ".flash-notice", text: "Законопроект убран из лайков."
    assert_select "#likes_bill_#{bill.id} .likes-count", text: "0"
    assert_match(/В лайки/, response.body)
  end

  test "лайки пользователя видны на странице лайков, чужие не видны" do
    sign_in users(:one)

    get likes_path
    assert_response :success
    assert_select "h2 a", text: "О защите персональных данных"   # своя закладка
    assert_select "h2 a", text: "О местном самоуправлении", count: 0
    assert_select "h2 a", text: "О цифровых услугах", count: 0   # чужая (пользователь two)
  end

  # ===== Контекст 5: история просмотров =====

  test "просмотренные законопроекты видны в истории без дублей" do
    sign_in users(:one)
    bill = bills(:adopted_bill) # этот пользователь её ещё не смотрел

    assert_difference -> { ViewHistory.count }, 1 do
      get bill_path(bill)
    end
    assert_response :success

    # Повторный просмотр обновляет время, а не создаёт новую запись
    assert_no_difference -> { ViewHistory.count } do
      get bill_path(bill)
    end

    get history_path
    assert_response :success
    assert_select "h2 a", text: "О местном самоуправлении"
    assert_select "h2 a", text: "О цифровых услугах" # просмотр из фикстуры
  end

  # ===== Контекст 6: выход =====

  test "выход завершает сессию и закрывает личные страницы" do
    sign_in users(:one)

    get likes_path
    assert_response :success

    delete destroy_user_session_path
    assert_redirected_to root_path

    get likes_path
    assert_redirected_to new_user_session_path
  end
end
