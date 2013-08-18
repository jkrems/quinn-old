
var toString$ = Object.prototype.toString;

module.exports = {
  isGenerator: function isGenerator(obj) {
    return toString$.call(obj).slice(8, -1) === 'Generator';
  }
};
