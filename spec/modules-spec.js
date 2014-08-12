var assert = require('chai').assert,
    integrations = require('../index');

describe('Modules', function() {

  it('should have valid id', function() {
    for (var id in integrations.modules) {
      assert.equal(integrations.modules[id].id, id);
      assert.match(integrations.modules[id].id, /[-.]/);
    }
  });

  it('should lookup by module id', function() {
    assert(integrations.lookup('leadconduit-default.inbound'))
  });

});