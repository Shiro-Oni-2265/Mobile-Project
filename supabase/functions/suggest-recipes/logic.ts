export interface Recipe {
  id: string;
  name: string;
  minutes: number;
  vegetarian: boolean;
  items: { ingredientId: string }[];
}
export interface Preferences {
  vegetarian?: boolean;
  maxMinutes?: number;
  servings?: number;
  avoided?: string[];
}
export function eligible(recipe: Recipe, preferences: Preferences): boolean {
  return typeof recipe.name === 'string' && recipe.name.length <= 100 &&
    Number.isFinite(recipe.minutes) && recipe.minutes > 0 && recipe.minutes <= (preferences.maxMinutes ?? 45) &&
    (!preferences.vegetarian || recipe.vegetarian) && Array.isArray(recipe.items) &&
    !recipe.items.some((i) => (preferences.avoided ?? []).includes(i.ingredientId));
}
export function validateSuggestions(raw: unknown, allowed: Set<string>): { id: string; reason: string }[] {
  if (!Array.isArray(raw) || raw.length < 1 || raw.length > 5) throw new Error('INVALID_OUTPUT');
  const seen = new Set<string>();
  return raw.map((item) => {
    if (!item || typeof item.id !== 'string' || !allowed.has(item.id) || seen.has(item.id) ||
      typeof item.reason !== 'string' || !item.reason.trim() || item.reason.length > 300) throw new Error('INVALID_OUTPUT');
    seen.add(item.id);
    return { id: item.id, reason: item.reason.trim() };
  });
}
