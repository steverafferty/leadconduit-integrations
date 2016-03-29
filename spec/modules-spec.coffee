_ = require('lodash')
assert = require('chai').assert
integrations = require('../src/index')

describe 'Modules', ->

  it 'should have valid id', ->
    for id in integrations.modules
      assert.equal integrations.modules[id].id, id
      assert.match integrations.modules[id].id, /[-.]/

  it 'should lookup by module id', ->
    assert integrations.lookup('leadconduit-default.inbound')

  it 'should find private @activeprospect module by id', ->
    assert integrations.lookup('leadconduit-360.outbound.vendor_lookup')

  it 'should provide timeout seconds', ->
    requestVars = integrations.modules['leadconduit-default.outbound'].request_variables
    assert.deepEqual _.find(requestVars, name: 'timeout_seconds'),
      name: 'timeout_seconds'
      type: 'number'
      description: 'Produce an "error" outcome if the server fails to respond within this number of seconds (default: 360)'
      required: false

  it 'should use derived package name', ->
    module = integrations.modules['leadconduit-default.inbound']
    assert.equal module.package.name, 'LeadConduit'

  it 'should use specified package name', ->
    integration = require('leadconduit-default')
    original = integration.name
    integration.name = 'Foo'
    integrations.initPackage('leadconduit-default')
    try
      module = integrations.modules['leadconduit-default.inbound']
      assert.equal module.package.name, 'Foo'
    finally
      integration.name = original

