// Qué aviso recibe el teléfono del niño según el cambio de estado. Prueba
// pura (no necesita emuladores):  node --test firebase/tests/child_status.test.mjs
import test from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { childStatusMessage } = require('../../functions/child_status.js');

const base = { message: 'Necesito agua', statusUpdatedByName: 'Ana López' };

test('en atención: "¡Ana va en camino!" con lo que comunicó', () => {
  assert.deepEqual(
    childStatusMessage({ ...base, status: 'seen' }, { ...base, status: 'attending' }),
    { title: '¡Ana va en camino!', body: 'Necesito agua' },
  );
});

test('vista y resuelta también avisan', () => {
  assert.equal(
    childStatusMessage({ ...base, status: 'new' }, { ...base, status: 'seen' }).title,
    'Ana vio tu mensaje',
  );
  assert.equal(
    childStatusMessage({ ...base, status: 'attending' }, { ...base, status: 'resolved' }).title,
    '¡Listo! Ya atendieron tu mensaje',
  );
});

test('sin nombre del adulto usa "Tu adulto"', () => {
  assert.equal(
    childStatusMessage({ status: 'new' }, { status: 'attending', message: 'x' }).title,
    '¡Tu adulto va en camino!',
  );
});

test('no avisa si el estado no avanza, si solo cambió la valoración o si es importada', () => {
  assert.equal(childStatusMessage({ ...base, status: 'resolved' }, { ...base, status: 'resolved', childFeedback: 'better' }), null);
  assert.equal(childStatusMessage({ ...base, status: 'attending' }, { ...base, status: 'seen' }), null);
  assert.equal(childStatusMessage({ ...base, status: 'new' }, { ...base, status: 'attending', imported: true }), null);
  assert.equal(childStatusMessage(undefined, { ...base, status: 'attending' }), null);
});
