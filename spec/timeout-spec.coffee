assert = require('chai').assert
nock = require('nock')
types = require('leadconduit-types')
integrations = require('../src/index')

describe 'Timeout', ->

  before ->
    integrations.register 'test',
      request: ->
        url: 'http://externalservice'
        method: 'POST'
      response: (vars, req, res) ->
        JSON.parse(res.body)

  after ->
    integrations.deregister 'test'

  afterEach ->
    nock.cleanAll()

   it 'should return error on delay', (done) ->
    nock 'http://externalservice'
      .post '/'
      .socketDelay 400000
      .reply 200, outcome: 'success'

    integrations.lookup('test').handle {}, (err, event) ->
      assert err
      assert.equal err.code, 'ESOCKETTIMEDOUT'
      done()


  it 'should not return error when no delay', (done) ->
    nock 'http://externalservice'
    .post '/'
    .reply 200, outcome: 'success'

    integrations.lookup('test').handle {}, (err, event) ->
      assert.isNull err
      assert event
      done()

