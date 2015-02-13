assert = require('chai').assert
integrations = require('../src/index')

describe 'Prefix', ->

  after ->
    integrations.deregister 'test'


  it 'should be null when outcome is at the root', ->
    integrations.register 'test',
      responseVariables: ->
        [
          { name: 'outcome', type: 'string' }
        ]
    assert.isNull integrations.lookup('test').appendPrefix


  it 'should be undefined when outcome variable is not defined', ->
    integrations.register 'test',
      responseVariables: ->
        [
          { name: 'foo', type: 'string' }
        ]
    assert.isUndefined integrations.lookup('test').appendPrefix


  it 'should be shallow path', ->
    integrations.register 'test',
      responseVariables: ->
        [
          { name: 'foo.outcome', type: 'string' }
        ]
    assert.equal integrations.lookup('test').appendPrefix, 'foo'


  it 'should be deeply nested path', ->
    integrations.register 'test',
      responseVariables: ->
        [
          { name: 'foo.bar.baz.outcome', type: 'string' }
        ]
    assert.equal integrations.lookup('test').appendPrefix, 'foo.bar.baz'