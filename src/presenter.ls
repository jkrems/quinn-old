
i18n-helpers = (req) ->
  translate: (key) -> key

module.exports = presenter = (req) ->
  {} <<< I18n: i18n-helpers req
