assert = require('chai').assert
nock = require('nock')
integrations = require('../src/index')

describe 'Handle', ->


  beforeEach ->
    @service = nock 'http://externalservice'
      .post '/'
      .reply 200, outcome: 'success'


  it 'should make request', (done) ->
    integrations.integrations.test =
      request: ->
        url: 'http://externalservice'
        method: 'POST'
      response: (vars, req, res) ->
        JSON.parse(res.body)

    integrations.lookup('test').handle {}, (err, event) ->
      return done(err) if err?
      assert.equal event.outcome, 'success'
      done()


  it 'should return error when an error is thrown during request', (done) ->
    integrations.integrations.test =
      request: ->
        throw new Error('no way, bub')
      response: (vars, req, res) ->
        JSON.parse(res.body)

    integrations.lookup('test').handle {}, (err, event) ->
      assert.isUndefined event
      assert.equal err.message, 'no way, bub'
      done()


  it 'should return error when an error is thrown during response', (done) ->
    integrations.integrations.test =
      request: ->
        url: 'http://externalservice'
        method: 'POST'
      response: (vars, req, res) ->
        throw new Error('no way, bub')

    integrations.lookup('test').handle {}, (err, event) ->
      assert.isUndefined event
      assert.equal err.message, 'no way, bub'
      done()






