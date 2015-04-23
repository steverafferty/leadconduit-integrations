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
