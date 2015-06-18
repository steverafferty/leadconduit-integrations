assert = require('chai').assert
integrations = require('../src/index')

describe 'Types', ->

  after ->
    integrations.deregister 'test'


  it 'should use requestVariables', ->
    integrations.register 'test',
      requestVariables: ->
        [
          { name: 'foo', type: 'boolean' }
          { name: 'bar', type: 'number'}
        ]

    assert.deepEqual integrations.lookup('test').requestTypes, foo: 'boolean', bar: 'number'

  it 'should use responseVariables', ->
    integrations.register 'test',
      responseVariables: ->
        [
          { name: 'foo', type: 'boolean' }
          { name: 'bar', type: 'number'}
        ]

    assert.deepEqual integrations.lookup('test').responseTypes, foo: 'boolean', bar: 'number'

  it 'should use request.variables', ->
    request = ->
    request.variables = ->
      [
        { name: 'foo', type: 'boolean' }
        { name: 'bar', type: 'number'}
      ]
    integrations.register 'test', request: request
    assert.deepEqual integrations.lookup('test').requestTypes, foo: 'boolean', bar: 'number'


  it 'should use response.variables', ->
    response = ->
    response.variables = ->
      [
        { name: 'foo', type: 'boolean' }
        { name: 'bar', type: 'number'}
      ]
    integrations.register 'test', response: response
    assert.deepEqual integrations.lookup('test').responseTypes, foo: 'boolean', bar: 'number'



  it 'should use string as default type', ->

    integrations.register 'test',
      requestVariables: ->
        [ name: 'foo']
      responseVariables: ->
        [ name: 'bar']

    assert.deepEqual integrations.lookup('test').requestTypes, foo: 'string'
    assert.deepEqual integrations.lookup('test').responseTypes, bar: 'string'


  it 'should use standard field type as default type', ->

    integrations.register 'test',
      requestVariables: ->
        [ name: 'postal_code']
      responseVariables: ->
        [ name: 'phone_1']

    assert.deepEqual integrations.lookup('test').requestTypes, postal_code: 'postal_code'
    assert.deepEqual integrations.lookup('test').responseTypes, phone_1: 'phone'