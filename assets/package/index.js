/**
 * LiveSvelteGettext - Runtime Translation Library
 *
 * Provides runtime translation functions for Svelte components and
 * Phoenix LiveView hook for automatic initialization.
 *
 * @module live-svelte-gettext
 */

/**
 * Internal translation state
 * @private
 */
const state = {
  translations: {},
  initialized: false
};

/**
 * Initialize the translation system with data from the server
 *
 * This function is called automatically by the LiveSvelteGettextInit hook
 * when the page loads. You typically don't need to call this manually.
 *
 * @param {Record<string, string>} data - Translation data as key-value pairs
 *
 * @example
 * initTranslations({
 *   "Hello": "Hej",
 *   "Welcome, %{name}": "Välkommen, %{name}"
 * });
 */
export function initTranslations(data) {
  state.translations = { ...data };
  state.initialized = true;
}

/**
 * Check if translations have been initialized
 *
 * @returns {boolean} true if initTranslations has been called
 */
export function isInitialized() {
  return state.initialized;
}

/**
 * Reset translations (useful for testing)
 *
 * @example
 * // In test teardown
 * resetTranslations();
 */
export function resetTranslations() {
  state.translations = {};
  state.initialized = false;
}

/**
 * Escape special regex characters in a string
 * Used to safely replace variable names in translation strings
 *
 * @private
 * @param {string} str - String to escape
 * @returns {string} Escaped string safe for use in RegExp
 */
function escapeRegExp(str) {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/**
 * Interpolate variables in a translation string
 * Replaces %{varname} with values from the vars object
 *
 * @private
 * @param {string} text - Translation string with %{var} placeholders
 * @param {Record<string, string | number>} [vars] - Variable values to interpolate
 * @returns {string} String with variables replaced
 */
function interpolate(text, vars) {
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
 * @param {string} key - The translation key (usually the English string)
 * @param {Record<string, string | number>} [vars] - Optional variables for interpolation
 * @returns {string} Translated string with variables interpolated, or the key if translation not found
 *
 * @example
 * gettext("Hello"); // Returns "Hej" (if Swedish translations loaded)
 * gettext("Welcome, %{name}", { name: "Anna" }); // Returns "Välkommen, Anna"
 * gettext("Missing key"); // Returns "Missing key" (fallback)
 */
export function gettext(key, vars) {
  const translated = state.translations[key] ?? key;
  return interpolate(translated, vars);
}

/**
 * Get a translated string with plural handling
 *
 * Uses simple English plural rules: count === 1 ? singular : plural
 * Future versions will support CLDR plural rules for other languages
 *
 * @param {string} singular - Singular form (e.g., "1 item")
 * @param {string} plural - Plural form (e.g., "%{count} items")
 * @param {number} count - Number to determine singular/plural
 * @param {Record<string, string | number>} [vars] - Optional additional variables for interpolation
 * @returns {string} Translated string with count and variables interpolated
 *
 * @example
 * ngettext("1 item", "%{count} items", 1); // Returns "1 objekt" (singular)
 * ngettext("1 item", "%{count} items", 5); // Returns "5 objekt" (plural)
 * ngettext("Welcome %{name}", "Welcome all %{count}", 1, { name: "Anna" });
 * // Returns "Välkommen Anna"
 */
export function ngettext(singular, plural, count, vars) {
  // Determine which form to use (simple English rules)
  const key = count === 1 ? singular : plural;

  // Always include count in variables for interpolation
  const allVars = {
    count,
    ...(vars || {})
  };

  return gettext(key, allVars);
}

/**
 * Phoenix LiveView Hook for automatic translation initialization
 *
 * This hook reads translation data from a JSON script tag and initializes
 * the translation system when the page loads.
 *
 * Register this hook in your assets/js/app.js:
 *
 * @example
 * import { LiveSvelteGettextInit } from "live-svelte-gettext";
 *
 * const liveSocket = new LiveSocket("/live", Socket, {
 *   hooks: {
 *     ...getHooks(Components),
 *     LiveSvelteGettextInit,  // Add this line
 *   }
 * });
 *
 * @type {{mounted: function(): void}}
 */
export const LiveSvelteGettextInit = {
  mounted() {
    const translationsId = this.el.dataset.translationsId || 'svelte-translations';
    const el = document.getElementById(translationsId);

    if (el) {
      try {
        const translations = JSON.parse(el.textContent || '{}');
        initTranslations(translations);
      } catch (error) {
        console.error('[LiveSvelteGettext] Failed to initialize translations:', error);
      }
    } else {
      console.warn(`[LiveSvelteGettext] Translation script tag not found: #${translationsId}`);
    }
  }
};
