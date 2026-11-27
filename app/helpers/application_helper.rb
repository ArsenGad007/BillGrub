module ApplicationHelper
  # Русские формы множественного числа:
  #   ru_pluralize(1, one: "лайк", few: "лайка", many: "лайков") # => "лайк"
  #   ru_pluralize(3, one: "лайк", few: "лайка", many: "лайков") # => "лайка"
  #   ru_pluralize(7, one: "лайк", few: "лайка", many: "лайков") # => "лайков"
  def ru_pluralize(count, one:, few:, many:)
    remainder_of_hundred = count.to_i.abs % 100
    return many if remainder_of_hundred.between?(11, 14)

    case remainder_of_hundred % 10
    when 1 then one
    when 2..4 then few
    else many
    end
  end
end
