assert = require('chai').assert
nock = require('nock')
types = require('leadconduit-types')
integrations = require('../src/index')

describe 'Timeout', ->

  before ->
    integrations.register 'test',
      request: (vars) ->
        url: 'http://externalservice'
        method: 'POST'
        timeout: vars.timeout_seconds
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

    integrations.lookup('test').handle {}, (err) ->
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


  it 'should not allow timeout greater than max', (done) ->
    nock 'http://externalservice'
      .post '/'
      .socketDelay 400000
      .reply 200, outcome: 'success'

    integrations.lookup('test').handle timeout_seconds: 450, (err) ->
      # expect a timeout because the handle function limited the timeout to 360 seconds, but the delay was 400 seconds
      assert err
      assert.equal err.code, 'ESOCKETTIMEDOUT'
      done()


  it 'should not allow timeout less than min', (done) ->
    nock 'http://externalservice'
      .post '/'
      .socketDelay 500
      .reply 200, outcome: 'success'

    integrations.lookup('test').handle timeout_seconds: 0.1, (err, event) ->
      # expect no timeout because the handle function set the timeout to 1s, but the delay was only a 0.5s
      assert.isNull err
      assert event
      done()


  it 'should default timeout to timeout_seconds', (done) ->
    nock 'http://externalservice'
      .post '/'
      .socketDelay 10000
      .reply 200, outcome: 'success'

    integrations.lookup('test').handle timeout_seconds: 5, (err) ->
      # expect a timeout because timeout_seconds specifies 5 seconds, but the delay was 10 seconds
      assert err
      assert.equal err.code, 'ESOCKETTIMEDOUT'
      done()


  it 'should return error when request function returns non-number', (done) ->
    nock 'http://externalservice'
      .post '/'
      .socketDelay 10000
      .reply 200, outcome: 'success'

    integrations.lookup('test').handle timeout_seconds: 'donkey', (err) ->
      assert.equal err.message, 'request timeout must be a number'
      done()

