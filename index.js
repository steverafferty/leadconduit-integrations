var dotaccess = require('dotaccess'),
    string = require('underscore.string'),
    path = require('path');


var empty = function(str) {
  return (str != null) && str !== '';
};

var findPaths = function(api, modulePath) {
  if (modulePath == null)
    modulePath = '';
  var paths = [];
  var apiProperties = Object.keys(api);
  if (apiProperties.indexOf("request") !== -1 || apiProperties.indexOf('handle') !== -1) {
    paths.push(modulePath);
  } else {
    var key, module;
    for (key in api) {
      module = api[key];
      paths = paths.concat(findPaths(module, [modulePath, key].filter(empty).join('.')));
    }
  }
  return paths;
};

var generateName = function(modulePath) {
  var name = modulePath.replace(/(inbound|outbound)\./, '').replace(/_/g, ' ').split(/\s|\./).map(function(part) {
    return string.capitalize(part);
  });
  return name.join(' ');
};

module.exports = {
  packages: {},
  modules: {},
  integrations: {},
  lookup: function(moduleId) {
    return module.exports.integrations[moduleId];
  }
};

var names = Object.keys(require(path.join(__dirname, 'package.json')).dependencies).filter(function(name) {
  return name.match(/^leadconduit\-/)
});

names.forEach(function(name) {
  var api = require(name);
  var package = require(path.join(__dirname, 'node_modules', name, 'package.json'));
  var paths = findPaths(api);

  module.exports[name] = api;

  module.exports.packages[name] = {
    name: name,
    version: package.version,
    description: package.description,
    repo_url: package.repository.url,
    paths: paths
  };

  paths.forEach(function(modulePath) {
    var integration = dotaccess.get(api, modulePath);
    var friendlyName = integration.name || generateName(modulePath);
    var id = "" + name + "." + modulePath;
    var type = null;

    if (modulePath.match(/inbound/))
      type = 'inbound';
    else if (modulePath.match(/outbound/))
      type = 'outbound';


    var requestVariables = integration.request ? integration.request.variables() : integration.requestVariables();
    var responseVariables = integration.response ? integration.response.variables() : integration.responseVariables();

    module.exports.modules[id] = {
      id: id,
      type: type,
      package: module.exports.packages[name],
      path: modulePath,
      name: friendlyName,
      request_variables: requestVariables,
      response_variables: responseVariables
    };

    module.exports.integrations[id] = integration;
  });
});



