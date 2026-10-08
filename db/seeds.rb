# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Законопроекты, которые раньше были захардкожены в PagesController::BILLS.
[
  { number: "№ 4821-8", title: "О защите персональных данных", status: :under_review,
    description: "Законопроект уточняет правила хранения и передачи персональных данных гражданами и организациями, а также вводит штрафы за утечки." },
  { number: "№ 4790-8", title: "О цифровых услугах", status: :first_reading,
    description: "Определяет порядок работы онлайн-платформ с пользователями и требования к прозрачности рекомендательных алгоритмов." },
  { number: "№ 4755-8", title: "О местном самоуправлении", status: :adopted,
    description: "Меняет распределение полномочий между муниципалитетами и регионами в сфере транспорта и благоустройства." },
  { number: "№ 4702-8", title: "О налоге на недвижимость", status: :rejected,
    description: "Предлагает пересмотреть ставки налога на жилую и коммерческую недвижимость и ввести льготы для многодетных семей." },
  { number: "№ 4688-8", title: "Об образовании", status: :under_review,
    description: "Вводит новые требования к программам среднего образования и порядку аттестации учителей." }
].each do |attrs|
  Bill.find_or_create_by!(number: attrs[:number]) { |bill| bill.assign_attributes(attrs) }
end
