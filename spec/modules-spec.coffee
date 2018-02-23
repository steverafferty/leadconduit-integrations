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


  describe 'Metadata', ->

    before ->
      @module = integrations.modules['leadconduit-briteverify.outbound.email']

    it 'should have top-level module name', ->
      assert.equal @module.package.name, 'BriteVerify'

    it 'should have top-level module provider', ->
      assert.equal @module.package.provider, 'BriteVerify'

    it 'should have top-level module link', ->
      assert.equal @module.package.link, 'http://www.briteverify.com/'

    it 'should have top-level module description', ->
      assert.equal @module.package.description, '<p>Email verification platform to ensure addresses exist before sending emails.</p>\n'

    it 'should have integration name', ->
      assert.equal @module.name, 'Email Validation'

    it 'should have integration tag', ->
      assert.equal @module.tag, 'Email'

    it 'should have integration type', ->
      assert.equal @module.integration_type, 'Enhancement'

    it 'should have integration link', ->
      assert.equal @module.link, 'http://www.briteverify.com/'

    it 'should have integration description', ->
      assert.equal @module.description, '<p>Verify email before you send. BriteVerify can reduce your bounce rate by 98% and help your messages get delivered.</p>\n'
