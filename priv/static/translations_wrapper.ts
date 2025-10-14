/**
 * LiveSvelteGettext - Translation Wrapper (Optional)
 *
 * This file is a convenience wrapper that re-exports from live-svelte-gettext.
 * Copy this file to your project if you want to keep existing relative imports.
 *
 * ## Usage
 *
 * Copy this file to your project:
 * ```bash
 * cp deps/live_svelte_gettext/priv/static/translations_wrapper.ts assets/svelte/lib/translations.ts
 * ```
 *
 * Then your existing imports will work without modification:
 * ```svelte
 * <script>
 *   import { gettext } from '../lib/translations';
 * </script>
 * ```
 */

// Re-export everything from the npm package
export {
  gettext,
  ngettext,
  initTranslations,
  isInitialized,
  resetTranslations,
  type TranslationVars
} from 'live-svelte-gettext';
