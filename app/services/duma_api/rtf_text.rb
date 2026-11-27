# Чистый Ruby: превращает RTF-разметку в читаемый текст.
#
# Русские буквы в RTF закодированы как \'hh (байты CP1251), Unicode —
# как \uN. Управляющие слова (\par, \b) вырезаются, служебные секции
# (шрифтовые и цветовые таблицы) отбрасываются целиком.
module DumaApi
  module RtfText
    TABLE_DESTINATIONS = %w[fonttbl colortbl stylesheet info pict header footer listtable].freeze
    MAX_SIZE = 8.megabytes

    module_function

    def extract(rtf)
      source = rtf.to_s.b.byteslice(0, MAX_SIZE)
      return "" if source.blank?

      source = to_utf8(source)
      # не RTF (например, HTML-страница ошибки) — извлекать нечего
      return "" unless source.lstrip.start_with?("{\\rtf")

      source = decode_hex_escapes(source)
      source = decode_unicode_escapes(source)
      source = strip_service_groups(source)
      cleanup(to_plain_text(source))
    end

    # Кодировка + нормальные пробелы и переводы строк.
    def cleanup(text)
      text = fix_encoding(text.to_s)
      text
        .gsub(/\r\n?/, "\n")
        .gsub(/[ \t]+/, " ")
        .gsub(/\n{3,}/, "\n\n")
        .strip
    end

    def decode_hex_escapes(source)
      # \'hh — байт CP1251; сразу превращаем его в UTF-8-символ
      source.gsub(/\\'([0-9a-fA-F]{2})/) do
        [ Regexp.last_match(1).to_i(16) ].pack("C").force_encoding(Encoding::CP1251).encode(Encoding::UTF_8)
      end
    end

    def decode_unicode_escapes(source)
      # \uN — Unicode-кодовая точка; сразу после неё RTF-писатель кладёт
      # fallback-символ (обычно «?»), который выкидываем. pack("U") даёт UTF-8.
      source.gsub(/\\u(-?\d+)\s?\??/) { [ Regexp.last_match(1).to_i.abs ].pack("U") }
    end

    def strip_service_groups(source)
      TABLE_DESTINATIONS.each do |destination|
        marker = "\\#{destination}"
        source = remove_group(source, marker) while source.include?(marker)
      end
      source
    end

    # Вырезает группу {...}, начинающуюся с управляющего слова marker
    # (например, {\fonttbl ...}) вместе со всеми вложенными скобками.
    def remove_group(source, marker)
      marker_index = source.index(marker)
      return source if marker_index.nil?

      open_index = source.rindex("{", marker_index)
      return source if open_index.nil?

      depth = 0
      source[open_index..].each_char.with_index do |char, offset|
        position = open_index + offset
        case char
        when "{" then depth += 1
        when "}"
          depth -= 1
          if depth.zero?
            return source[0...open_index] + source[(position + 1)..].to_s
          end
        end
      end
      source
    end

    def to_plain_text(source)
      source
        .gsub(/\\par[d]?\b/, "\n")
        .gsub(/\\line\b/, "\n")
        .gsub(/\\[a-zA-Z]+-?\d*\s?/, "")
        .gsub(/[{}]/, "")
    end

    # RTF-разметка сама по себе ASCII; не-ASCII байты вне escape-ов (редкий
    # сбой) считаем CP1251 и перекодируем, чтобы весь буфер был валидным UTF-8.
    def to_utf8(source)
      source = source.force_encoding(Encoding::UTF_8)
      return source if source.valid_encoding?

      source.force_encoding(Encoding::CP1251)
            .encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
    end

    # Документы Госдумы обычно в CP1251: если строка не валидный UTF-8 —
    # считаем её CP1251 и перекодируем.
    def fix_encoding(text)
      text = text.dup.force_encoding(Encoding::UTF_8)
      return text if text.valid_encoding?

      text.force_encoding(Encoding::CP1251)
          .encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
    end
  end
end
