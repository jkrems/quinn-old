
i18n-helpers = (req) ->
  _t: (key, ...opts) -> key

url-helpers = (req) ->
  route: req.quinn-ctx.router.reverse-route!
  asset-url: (filename) -> filename

module.exports = page-model = (req) ->
  page = {}
  page <<< url-helpers req
  page <<< i18n-helpers req

page-model <<< { i18n-helpers, url-helpers }
