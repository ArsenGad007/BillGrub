require "test_helper"

# Real-time обновление счётчика лайков (задание 8: страница с частичным
# обновлением данных по websocket, Action Cable + Turbo Streams/Turbo Frames).
#
# Проверяем три уровня:
#   1. страницы подписаны на поток лайков (turbo-cable-stream-source);
#   2. транзакция лайка транслирует turbo-stream в поток законопроекта
#      (capture_turbo_stream_broadcasts — официальный хелпер turbo-rails);
#   3. ответ контроллера автору действия обновляет счётчик и Turbo Frame
#      (assert_turbo_stream / assert_turbo_frame).
class LikesBroadcastTest < ActionDispatch::IntegrationTest
  test "страница законопроекта показывает счётчик и подписана на поток лайков" do
    bill = bills(:under_review_bill)

    get bill_path(bill)
    assert_response :success

    assert_select "#likes_bill_#{bill.id} .likes-count", text: bill.bookmarks_count.to_s
    assert_select "turbo-cable-stream-source[channel='Turbo::StreamsChannel'][signed-stream-name]"
  end

  test "карточки на главной подписаны на свои потоки лайков" do
    get root_path
    assert_response :success

    assert_select "article.bill turbo-cable-stream-source[channel='Turbo::StreamsChannel']",
                  minimum: Bill.count
  end

  test "новый лайк транслирует обновлённый счётчик всем подписчикам" do
    sign_in users(:one)
    bill = bills(:adopted_bill) # лайков пока нет

    streams = capture_turbo_stream_broadcasts([ bill, :likes ]) do
      post bill_bookmark_path(bill)
    end

    assert_equal 1, streams.size
    stream = streams.first
    assert_equal "replace", stream["action"]
    assert_equal "likes_bill_#{bill.id}", stream["target"]
    assert_equal "1", stream.at("template .likes-count").text.strip
    assert_equal "лайк", stream.at("template .likes-label").text.strip

    # Снятие лайка тоже транслируется
    streams = capture_turbo_stream_broadcasts([ bill, :likes ]) do
      delete bill_bookmark_path(bill)
    end

    assert_equal 1, streams.size
    assert_equal "0", streams.first.at("template .likes-count").text.strip
    assert_equal "лайков", streams.first.at("template .likes-label").text.strip
  end

  test "у каждого законопроекта свой поток — чужие трансляции не пересекаются" do
    bill = bills(:simplified_bill)
    another = bills(:adopted_bill)

    streams = capture_turbo_stream_broadcasts([ bill, :likes ]) do
      assert_no_turbo_stream_broadcasts([ another, :likes ]) do
        Bookmark.create!(user: users(:one), bill: bill)
      end
    end

    assert_equal 1, streams.size
    assert_equal "likes_bill_#{bill.id}", streams.first["target"]
  end

  test "лайк через Turbo обновляет счётчик и кнопку без перезагрузки страницы" do
    sign_in users(:one)
    bill = bills(:adopted_bill)

    post bill_bookmark_path(bill), headers: { "ACCEPT" => Mime[:turbo_stream].to_s }

    assert_turbo_stream action: "replace", target: "likes_bill_#{bill.id}" do
      assert_select "template .likes-count", text: "1"
    end

    assert_turbo_frame "like_button_bill_#{bill.id}" do
      assert_select "form[action=?]", bill_bookmark_path(bill)
      assert_select "button", text: "Убрать из лайков"
    end
  end

  test "снятие лайка через Turbo возвращает кнопку «В лайки»" do
    sign_in users(:two) # у two уже стоит лайк на simplified_bill
    bill = bills(:simplified_bill)

    delete bill_bookmark_path(bill), headers: { "ACCEPT" => Mime[:turbo_stream].to_s }

    assert_turbo_stream action: "replace", target: "likes_bill_#{bill.id}" do
      assert_select "template .likes-count", text: "0"
    end

    assert_turbo_frame "like_button_bill_#{bill.id}" do
      assert_select "button", text: "В лайки"
      assert_select "button", text: "Убрать из лайков", count: 0
    end
  end
end
