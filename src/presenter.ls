
i18n-helpers = (req) ->
  translate: (key) -> key

module.exports = presenter = (req) ->
  {route: req.router.reverse-route!} <<< I18n: i18n-helpers req
