/**
 * LiveSvelteGettext - TypeScript Client Library
 *
 * Provides runtime translation functions for Svelte components.
 * Receives translations from the Phoenix server and handles interpolation and pluralization.
 *
 * @module translations
 */

/**
 * Translation data storage
 * Keys are translation keys, values are translated strings
 */
let translations: Record<string, string> = {};

/**
 * Flag to track if translations have been initialized
 */
let initialized = false;

/**
 * Type definition for variable substitution values
 */
export type TranslationVars = Record<string, string | number>;

/**
 * Initialize the translation system with data from the server
 *
 * @param data - Translation data as key-value pairs
 *
 * @example
 * ```typescript
 * initTranslations({
 *   "Hello": "Hej",
 *   "Welcome, %{name}": "Välkommen, %{name}"
 * });
 * ```
 */
export function initTranslations(data: Record<string, string>): void {
  translations = { ...data };
  initialized = true;
}

/**
 * Check if translations have been initialized
 *
 * @returns true if initTranslations has been called
 */
export function isInitialized(): boolean {
  return initialized;
}

/**
 * Reset translations (useful for testing)
 */
export function resetTranslations(): void {
  translations = {};
  initialized = false;
}

/**
 * Escape special regex characters in a string
 * Used to safely replace variable names in translation strings
 *
 * @param str - String to escape
 * @returns Escaped string safe for use in RegExp
 */
function escapeRegExp(str: string): string {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/**
 * Interpolate variables in a translation string
 * Replaces %{varname} with values from the vars object
 *
 * @param text - Translation string with %{var} placeholders
 * @param vars - Variable values to interpolate
 * @returns String with variables replaced
 */
function interpolate(text: string, vars?: TranslationVars): string {
  if (!vars) {
    return text;
  }

  let result = text;

  for (const [key, value] of Object.entries(vars)) {
    const escapedKey = escapeRegExp(key);
    const pattern = new RegExp(`%\\{${escapedKey}\\}`, 'g');
    result = result.replace(pattern, String(value));
  }

  return result;
}

/**
 * Get a translated string
 *
 * @param key - The translation key (usually the English string)
 * @param vars - Optional variables for interpolation
 * @returns Translated string with variables interpolated, or the key if translation not found
 *
 * @example
 * ```typescript
 * gettext("Hello"); // Returns "Hej" (if Swedish translations loaded)
 * gettext("Welcome, %{name}", { name: "Anna" }); // Returns "Välkommen, Anna"
 * gettext("Missing key"); // Returns "Missing key" (fallback)
 * ```
 */
export function gettext(key: string, vars?: TranslationVars): string {
  const translated = translations[key] ?? key;
  return interpolate(translated, vars);
}

/**
 * Get a translated string with plural handling
 *
 * Uses simple English plural rules: count === 1 ? singular : plural
 * Future versions will support CLDR plural rules for other languages
 *
 * @param singular - Singular form (e.g., "1 item")
 * @param plural - Plural form (e.g., "%{count} items")
 * @param count - Number to determine singular/plural
 * @param vars - Optional additional variables for interpolation
 * @returns Translated string with count and variables interpolated
 *
 * @example
 * ```typescript
 * ngettext("1 item", "%{count} items", 1); // Returns "1 objekt" (singular)
 * ngettext("1 item", "%{count} items", 5); // Returns "5 objekt" (plural)
 * ngettext("Welcome %{name}", "Welcome all %{count}", 1, { name: "Anna" });
 * // Returns "Välkommen Anna"
 * ```
 */
export function ngettext(
  singular: string,
  plural: string,
  count: number,
  vars?: TranslationVars
): string {
  // Determine which form to use (simple English rules)
  const key = count === 1 ? singular : plural;

  // Always include count in variables for interpolation
  const allVars: TranslationVars = {
    count,
    ...(vars || {})
  };

  return gettext(key, allVars);
}
