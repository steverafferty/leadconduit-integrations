dotaccess = require('dotaccess')
string = require('underscore.string')
path = require('path')
request = require('request')

#
# Public
#
packages = {}
modules = {}
integrations = {}

#
# Private: Build the packages, modules, and integrations
#
init = ->
  #
  # Collect the names of the integration dependencies defined in package.json
  #
  packageNames = Object.keys(require(path.join(__dirname, '..', 'package.json')).dependencies).filter (name) ->
    name.match(/^leadconduit\-/)


  #
  # Build the package, module, and integration metadata
  #
  for name in packageNames
    api = require(name)
    pkg = require(path.join(__dirname, '..', 'node_modules', name, 'package.json'))
    paths = findPaths(api)

    module.exports[name] = api;

    packages[name] =
      name: name
      version: pkg.version
      description: pkg.description
      repo_url: pkg.repository.url
      paths: paths

    for modulePath in paths
      integration = dotaccess.get(api, modulePath)
      friendlyName = integration.name or generateName(modulePath)
      id = "#{name}.#{modulePath}"
      type =
        if (modulePath.match(/inbound/))
          'inbound';
        else if (modulePath.match(/outbound/))
          'outbound';

      requestVariables = integration?.requestVariables?() ? integration.request?.variables?()
      responseVariables = integration?.responseVariables?() ? integration.response?.variables?()

      modules[id] =
        id: id
        type: type
        package: packages[name]
        path: modulePath
        name: friendlyName
        request_variables: requestVariables
        response_variables: responseVariables

      register id, integration


#
# Public: Register an integration.
#
register = (id, integration) ->
  generateHandle(integration)
  integrations[id] = integration
  integration


#
# Public: De-register an integration.
#
deregister = (id) ->
  delete integrations.id


#
# Public: Lookup the module by ID.
#
# Returned module is guaranteed to have a handle() function.
#
lookup = (moduleId) ->
  integration = integrations[moduleId]

  # Wrap the request() and response() functions by implementing handle(), if necessary
  generateHandle(integration)

  integration


#
# Helpers ----------------------------------------------------------------
#


#
# Private: Generate the handle() function for an outbound integration if it supports the request()
# and response() functions and doesn't yet have a handle() function.
#
generateHandle = (outbound) ->
  # There is nothing to be done unless the integration has the request() and response() functions
  return unless typeof outbound?.request == 'function' and typeof outbound?.response == 'function'

  # Assign the handle() function, if it isn't already assigned
  outbound.handle ?= (vars, callback) ->

    # Build the request by delegating to the integration's request function
    try
      outboundReq = outbound.request(vars)
    catch err
      return callback(err)

    # Protect against the request module throwing an error when bad options are specified
    makeRequest = (options, cb) ->
      return cb(new Error('request missing URL')) unless options.url?.trim()
      return cb(new Error('request missing method')) unless options.method?.trim()
      try
        request options, cb
      catch err
        cb(err)

    # Make the HTTP request
    makeRequest outboundReq, (err, outboundRes, body) ->
      return callback(err) if err?

      # Normalize the response
      response =
        status: outboundRes.statusCode
        version: outboundRes.httpVersion ? '1.1'
        headers: normalizeHeaders(outboundRes.headers)
        body: body

      # Collect response variables by invoking the outbound integration's response function
      try
        event = outbound.response(vars, outboundReq, response)
      catch err
        return callback(err)

      callback(null, event)

#
# Private: Turn headers into Camel-Case
#
normalizeHeaders = (headers) ->
  normalHeaders = {}
  for field, value of headers
    normalizePart = (part) ->
      "#{part[0].toUpperCase()}#{part[1..-1].toLowerCase()}"
    normalField = field.split('-').map(normalizePart).join('-')
    normalHeaders[normalField] = value
  normalHeaders

#
# Private: Given a module path, generate a sensible name.
#
generateName = (modulePath) ->
  name = modulePath.replace(/(inbound|outbound)\./, '').replace(/_/g, ' ').split(/\s|\./).map (part) ->
    string.capitalize(part)
  name.join(' ')


#
# Private: Find all the integration paths in a module
#
findPaths = (api, modulePath='') ->
  paths = []

  apiProperties = Object.keys(api)
  if apiProperties.indexOf("request") != -1 or apiProperties.indexOf('handle') != -1
    paths.push(modulePath)
  else
    for key, module of api
      paths = paths.concat(findPaths(module, [modulePath, key].filter(empty).join('.')))

  paths


#
# Private: For filtering empty values.
#
empty = (str) ->
  !!str?.trim()


#
# Module -----------------------------------------------------------------
#

# Build the packages, modules, integrations
init()

module.exports =
  packages: packages
  modules: modules
  integrations: integrations
  register: register
  deregister: deregister
  lookup: lookup