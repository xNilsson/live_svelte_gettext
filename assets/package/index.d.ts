/**
 * LiveSvelte Gettext - TypeScript Type Definitions
 */

/**
 * Type definition for variable substitution values
 */
export type TranslationVars = Record<string, string | number>;

/**
 * Initialize the translation system with data from the server
 *
 * This function is called automatically by the LiveSvelteGettextInit hook
 * when the page loads. You typically don't need to call this manually.
 */
export function initTranslations(data: Record<string, string>): void;

/**
 * Check if translations have been initialized
 *
 * @returns true if initTranslations has been called
 */
export function isInitialized(): boolean;

/**
 * Reset translations (useful for testing)
 */
export function resetTranslations(): void;

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
export function gettext(key: string, vars?: TranslationVars): string;

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
 * ```
 */
export function ngettext(
  singular: string,
  plural: string,
  count: number,
  vars?: TranslationVars
): string;

/**
 * Phoenix LiveView Hook for automatic translation initialization
 *
 * Register this hook in your assets/js/app.js
 */
export const LiveSvelteGettextInit: {
  mounted(): void;
};
