
i18n-helpers = (req) ->
  _t: (key, ...opts) -> key

url-helpers = (req) ->
  {route: req.router.reverse-route!}

module.exports = page-model = (req) ->
  page = {}
  page <<< url-helpers req
  page <<< i18n-helpers req

page-model <<< { i18n-helpers, url-helpers }
