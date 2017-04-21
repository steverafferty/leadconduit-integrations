_ = require('lodash')
dotaccess = require('dotaccess')
string = require('underscore.string')
path = require('path')
request = require('request')
fields = require('leadconduit-fields')

#
# Public
#
packages = {}
modules = {}
integrations = {}
ui = {}
maxTimeout = 360 # Same as the load balancer timeout
minTimeout = 1

#
# Private: Build the packages, modules, and integrations
#
init = ->
  #
  # Collect the names of the integration dependencies defined in package.json
  #
  packageNames = Object.keys(require(path.join(__dirname, '..', 'package.json')).dependencies).filter (name) ->
    name.match(/^leadconduit\-|^@activeprospect\/leadconduit\-/)  and name != 'leadconduit-fields'


  #
  # Build the package, module, and integration metadata
  #
  for name in packageNames
    initPackage(name)


#
# Private: initialize the named integration package
#
initPackage = (name) ->
  api = require(name)
  pkg = require(path.join(__dirname, '..', 'node_modules', name, 'package.json'))

  paths = findPaths(api)

  name = name.replace /^@activeprospect\//, ''
  module.exports[name] = api;

  hasUi = typeof api.ui == 'function'

  packages[name] =
    name: api.name ? _.capitalize(name.replace('leadconduit-', ''))
    version: pkg.version
    description: pkg.description
    repo_url: pkg.repository.url
    paths: paths
    ui: hasUi

  ui[name] = api.ui if hasUi

  ui[name] = api.ui if typeof api.ui == 'function'

  for modulePath in paths
    id = "#{name}.#{modulePath}"
    integration = dotaccess.get(api, modulePath) ? api[modulePath]
    register id, integration



#
# Public: Register an integration.
#
register = (id, integration) ->
  generateModule(id, integration)
  generateHandle(integration)
  generateTypes(id, integration)
  generateAppendPrefix(id, integration)
  integrations[id] = integration
  integration


#
# Public: De-register an integration.
#
deregister = (id) ->
  delete integrations[id]


#
# Public: Lookup the module by ID.
#
# Returned module is guaranteed to have a handle() function.
#
lookup = (moduleId) ->
  integrations[moduleId]


#
# Public: ensure that timeout is a primitive number somewhere between minTimeout and maxTimeout
#
ensureTimeout = (timeout) ->
  timeout = new Number(timeout).valueOf()

  # Return default maximum if the timeout isn't a finite number
  return maxTimeout unless _.isFinite(timeout)

  # Ensure that timeout is set somewhere between minTimeout and maxTimeout
  return maxTimeout if timeout > maxTimeout
  return minTimeout if timeout < minTimeout

  timeout



#
# Helpers ----------------------------------------------------------------
#


generateModule = (id, integration) ->
  parts = id.split(/\./)
  name = parts.shift()
  modulePath = parts.join('.')
  friendlyName = integration.name or generateName(modulePath)
  type =
    if (modulePath.match(/inbound/))
      'inbound';
    else if (modulePath.match(/outbound/))
      'outbound';

  requestVariables = integration?.requestVariables?() ? integration.request?.variables?() ? []
  responseVariables = integration?.responseVariables?() ? integration.response?.variables?() ? []

  # Add the timeout_seconds request variable
  if type == 'outbound' and !_.find(requestVariables, name: 'timeout_seconds')
    requestVariables.push(name: 'timeout_seconds', type: 'number', description: 'Produce an "error" outcome if the server fails to respond within this number of seconds (default: 360)', required: false)

  modules[id] =
    id: id
    type: type
    package: packages[name]
    path: modulePath
    name: friendlyName
    request_variables: requestVariables
    response_variables: responseVariables


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

    # remove Content-Length header and let the request library set it (correctly, on byte length, not character length)
    outboundReq.headers['Content-Length'] = undefined if outboundReq.headers?

    # Protect against the request module throwing an error when bad options are specified
    makeRequest = (options, cb) ->
      options.url = options.url?.valueOf()
      return cb(new Error('request missing URL')) unless options.url?.trim()
      return cb(new Error('request missing method')) unless options.method?.trim()

      # Ensure that timeout is set somewhere between minTimeout and maxTimeout and convert to milliseconds
      options.timeout = ensureTimeout(options.timeout ? vars.timeout_seconds) * 1000

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
# Private: Generate the requestTypes and responseTypes properties on the integration
#
generateTypes = (id, integration) ->
  module = modules[id]
  integration.requestTypes ?= getRequestTypes(module)
  integration.responseTypes ?= getResponseTypes(module)

getRequestTypes = (module) ->
  getTypes(module.request_variables)

getResponseTypes = (module) ->
  getTypes(module.response_variables)

getTypes = (variables) ->
  mapType = (types, v) ->
    types[v.name] = v.type ? getDefaultType(v.name)
    types

  (variables ? []).reduce(mapType, {})

getDefaultType = (varName) ->
  fields.getType(varName) ? 'string'



#
# Private: resolve the prefix where an integration's outcome key will live
#
generateAppendPrefix = (id, integration) ->
  outcomeRegex = /\.?outcome$/
  outcomeVar = _.find modules[id].response_variables, (v) ->
    v.name?.match(outcomeRegex)
  if outcomeVar?.name?
    integration.appendPrefix = outcomeVar.name.replace(outcomeRegex, '')


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
  if apiProperties.indexOf('request') != -1 or apiProperties.indexOf('handle') != -1
    paths.push(modulePath)
  else
    for key, mod of api
      # 'name' is a special property for defining a friendly name for the package
      # 'api' is a special property for defining API routes
      continue if key == 'name' or key == 'ui'
      paths = paths.concat(findPaths(mod, [modulePath, key].filter(empty).join('.')))

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
  ui: ui
  register: register
  deregister: deregister
  lookup: lookup
  maxTimeout: maxTimeout
  minTimeout: minTimeout
  ensureTimeout: ensureTimeout
  initPackage: initPackage
