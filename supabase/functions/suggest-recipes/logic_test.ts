import { eligible, validateSuggestions, type Recipe } from './logic.ts';
const recipe: Recipe = { id: 'r', name: 'Đậu', minutes: 15, vegetarian: true, items: [{ ingredientId: 'tofu' }] };
function assert(condition: boolean) { if (!condition) throw new Error('Assertion failed'); }
Deno.test('server filters dietary, excluded and duration preferences', () => {
  assert(eligible(recipe, { vegetarian: true, maxMinutes: 20 }));
  assert(!eligible(recipe, { avoided: ['tofu'] })); assert(!eligible(recipe, { maxMinutes: 10 }));
  assert(!eligible({ ...recipe, vegetarian: false }, { vegetarian: true }));
});
Deno.test('AI rejects unknown IDs, duplicates, empty output and overlong reasons', () => {
  for (const value of [[], [{ id: 'wrong', reason: 'x' }], [{ id: 'r', reason: '' }],
    [{ id: 'r', reason: 'x'.repeat(301) }], [{ id: 'r', reason: 'x' }, { id: 'r', reason: 'y' }]]) {
    let rejected = false;
    try { validateSuggestions(value, new Set(['r'])); } catch { rejected = true; }
    assert(rejected);
  }
  assert(validateSuggestions([{ id: 'r', reason: ' Hợp nguyên liệu ' }], new Set(['r']))[0].reason === 'Hợp nguyên liệu');
});
