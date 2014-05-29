module.exports = {};

Object.keys(require('./package.json').dependencies).forEach(function(name) {
  module.exports[name] = require(name)
});



