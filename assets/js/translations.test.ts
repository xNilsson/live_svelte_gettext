import { describe, it, expect, beforeEach } from 'vitest';
import {
  initTranslations,
  isInitialized,
  resetTranslations,
  gettext,
  ngettext,
  type TranslationVars
} from './translations';

describe('Translation System', () => {
  beforeEach(() => {
    // Reset state before each test
    resetTranslations();
  });

  describe('initTranslations', () => {
    it('should initialize with empty object', () => {
      initTranslations({});
      expect(isInitialized()).toBe(true);
    });

    it('should store translation data', () => {
      initTranslations({
        'Hello': 'Hej',
        'Goodbye': 'Hejdå'
      });

      expect(gettext('Hello')).toBe('Hej');
      expect(gettext('Goodbye')).toBe('Hejdå');
    });

    it('should handle Swedish characters (åäö)', () => {
      initTranslations({
        'Apple': 'Äpple',
        'Island': 'Ö',
        'Stream': 'Å'
      });

      expect(gettext('Apple')).toBe('Äpple');
      expect(gettext('Island')).toBe('Ö');
      expect(gettext('Stream')).toBe('Å');
    });

    it('should overwrite previous translations', () => {
      initTranslations({ 'Hello': 'Hej' });
      expect(gettext('Hello')).toBe('Hej');

      initTranslations({ 'Hello': 'Hallå' });
      expect(gettext('Hello')).toBe('Hallå');
    });
  });

  describe('isInitialized', () => {
    it('should return false before initialization', () => {
      expect(isInitialized()).toBe(false);
    });

    it('should return true after initialization', () => {
      initTranslations({});
      expect(isInitialized()).toBe(true);
    });

    it('should return false after reset', () => {
      initTranslations({});
      expect(isInitialized()).toBe(true);

      resetTranslations();
      expect(isInitialized()).toBe(false);
    });
  });

  describe('resetTranslations', () => {
    it('should clear all translations', () => {
      initTranslations({ 'Hello': 'Hej' });
      expect(gettext('Hello')).toBe('Hej');

      resetTranslations();
      expect(gettext('Hello')).toBe('Hello'); // Falls back to key
    });

    it('should reset initialized flag', () => {
      initTranslations({});
      resetTranslations();
      expect(isInitialized()).toBe(false);
    });
  });

  describe('gettext', () => {
    describe('simple translations', () => {
      beforeEach(() => {
        initTranslations({
          'Hello': 'Hej',
          'Goodbye': 'Hejdå',
          'Thank you': 'Tack'
        });
      });

      it('should return translated string', () => {
        expect(gettext('Hello')).toBe('Hej');
        expect(gettext('Goodbye')).toBe('Hejdå');
      });

      it('should return key if translation not found', () => {
        expect(gettext('Missing key')).toBe('Missing key');
      });

      it('should handle empty string key', () => {
        initTranslations({ '': 'Empty translation' });
        expect(gettext('')).toBe('Empty translation');
      });
    });

    describe('interpolation', () => {
      beforeEach(() => {
        initTranslations({
          'Welcome, %{name}': 'Välkommen, %{name}',
          'You have %{count} messages': 'Du har %{count} meddelanden',
          'Hello %{first} %{last}': 'Hej %{first} %{last}',
          'Price: %{amount}': 'Pris: %{amount}'
        });
      });

      it('should interpolate single variable', () => {
        expect(gettext('Welcome, %{name}', { name: 'Anna' }))
          .toBe('Välkommen, Anna');
      });

      it('should interpolate multiple variables', () => {
        expect(gettext('Hello %{first} %{last}', { first: 'Anna', last: 'Andersson' }))
          .toBe('Hej Anna Andersson');
      });

      it('should interpolate number values', () => {
        expect(gettext('You have %{count} messages', { count: 5 }))
          .toBe('Du har 5 meddelanden');
      });

      it('should handle missing variables gracefully', () => {
        expect(gettext('Welcome, %{name}'))
          .toBe('Välkommen, %{name}'); // Variable not replaced
      });

      it('should handle extra variables (ignore them)', () => {
        expect(gettext('Welcome, %{name}', { name: 'Anna', extra: 'ignored' }))
          .toBe('Välkommen, Anna');
      });

      it('should handle empty vars object', () => {
        expect(gettext('Welcome, %{name}', {}))
          .toBe('Välkommen, %{name}');
      });

      it('should interpolate with zero value', () => {
        expect(gettext('You have %{count} messages', { count: 0 }))
          .toBe('Du har 0 meddelanden');
      });

      it('should handle decimal numbers', () => {
        expect(gettext('Price: %{amount}', { amount: 19.99 }))
          .toBe('Pris: 19.99');
      });
    });

    describe('missing translations', () => {
      it('should fallback to key when not initialized', () => {
        expect(gettext('Hello')).toBe('Hello');
      });

      it('should fallback to key with interpolation', () => {
        expect(gettext('Hello %{name}', { name: 'Anna' }))
          .toBe('Hello Anna');
      });
    });

    describe('edge cases', () => {
      it('should handle special characters in translation', () => {
        initTranslations({
          'Special': 'Characters: !@#$%^&*()_+-=[]{}|;:",.<>?/\\'
        });
        expect(gettext('Special')).toBe('Characters: !@#$%^&*()_+-=[]{}|;:",.<>?/\\');
      });

      it('should handle quotes in translation', () => {
        initTranslations({
          'Quote': 'She said "Hello"',
          'SingleQuote': "It's working"
        });
        expect(gettext('Quote')).toBe('She said "Hello"');
        expect(gettext('SingleQuote')).toBe("It's working");
      });

      it('should handle newlines in translation', () => {
        initTranslations({
          'Multiline': 'Line 1\nLine 2\nLine 3'
        });
        expect(gettext('Multiline')).toBe('Line 1\nLine 2\nLine 3');
      });

      it('should handle empty translation value', () => {
        initTranslations({
          'Empty': ''
        });
        expect(gettext('Empty')).toBe('');
      });

      it('should escape regex special characters in variable names', () => {
        initTranslations({
          'Test %{var.name}': 'Result %{var.name}',
          'Test %{var$name}': 'Result %{var$name}',
          'Test %{var[0]}': 'Result %{var[0]}'
        });

        // Variable names with regex special chars should work
        expect(gettext('Test %{var.name}', { 'var.name': 'value' }))
          .toBe('Result value');
        expect(gettext('Test %{var$name}', { 'var$name': 'value' }))
          .toBe('Result value');
        expect(gettext('Test %{var[0]}', { 'var[0]': 'value' }))
          .toBe('Result value');
      });

      it('should handle multiple occurrences of same variable', () => {
        initTranslations({
          'Hello %{name}, welcome %{name}': 'Hej %{name}, välkommen %{name}'
        });

        expect(gettext('Hello %{name}, welcome %{name}', { name: 'Anna' }))
          .toBe('Hej Anna, välkommen Anna');
      });

      it('should not break on malformed placeholders', () => {
        initTranslations({
          'Bad placeholder %{': 'Dålig placeholder %{'
        });

        // Should return translation as-is
        expect(gettext('Bad placeholder %{')).toBe('Dålig placeholder %{');
      });
    });
  });

  describe('ngettext', () => {
    describe('plural rules', () => {
      beforeEach(() => {
        initTranslations({
          '1 item': '1 objekt',
          '%{count} items': '%{count} objekt',
          '1 message': '1 meddelande',
          '%{count} messages': '%{count} meddelanden'
        });
      });

      it('should use singular form for count = 1', () => {
        expect(ngettext('1 item', '%{count} items', 1))
          .toBe('1 objekt');
      });

      it('should use plural form for count = 0', () => {
        expect(ngettext('1 item', '%{count} items', 0))
          .toBe('0 objekt');
      });

      it('should use plural form for count = 2', () => {
        expect(ngettext('1 item', '%{count} items', 2))
          .toBe('2 objekt');
      });

      it('should use plural form for large numbers', () => {
        expect(ngettext('1 message', '%{count} messages', 1000))
          .toBe('1000 meddelanden');
      });

      it('should use plural form for negative numbers', () => {
        expect(ngettext('1 item', '%{count} items', -5))
          .toBe('-5 objekt');
      });

      it('should use plural form for decimal numbers', () => {
        expect(ngettext('1 item', '%{count} items', 1.5))
          .toBe('1.5 objekt');
      });
    });

    describe('with additional variables', () => {
      beforeEach(() => {
        initTranslations({
          'Welcome %{name}': 'Välkommen %{name}',
          'Welcome all %{count}': 'Välkomna alla %{count}',
          '%{user} has 1 item': '%{user} har 1 objekt',
          '%{user} has %{count} items': '%{user} har %{count} objekt'
        });
      });

      it('should interpolate additional variables with singular', () => {
        expect(ngettext('Welcome %{name}', 'Welcome all %{count}', 1, { name: 'Anna' }))
          .toBe('Välkommen Anna');
      });

      it('should interpolate additional variables with plural', () => {
        expect(ngettext('Welcome %{name}', 'Welcome all %{count}', 5, { name: 'Anna' }))
          .toBe('Välkomna alla 5');
      });

      it('should combine count and other variables', () => {
        expect(ngettext('%{user} has 1 item', '%{user} has %{count} items', 3, { user: 'Anna' }))
          .toBe('Anna har 3 objekt');
      });

      it('should handle when count is explicitly in vars (vars override parameter)', () => {
        expect(ngettext('1 item', '%{count} items', 5, { count: 999 }))
          .toBe('999 items'); // vars override count parameter in interpolation, but plural selection uses parameter
      });
    });

    describe('missing translations', () => {
      it('should fallback to singular key with interpolation', () => {
        expect(ngettext('1 item', '%{count} items', 1))
          .toBe('1 item');
      });

      it('should fallback to plural key with interpolation', () => {
        expect(ngettext('1 item', '%{count} items', 5))
          .toBe('5 items');
      });

      it('should fallback with additional vars', () => {
        expect(ngettext('Welcome %{name}', 'Welcome all %{count}', 1, { name: 'Anna' }))
          .toBe('Welcome Anna');
      });
    });

    describe('edge cases', () => {
      it('should handle no additional vars (undefined)', () => {
        initTranslations({
          '1 item': '1 objekt',
          '%{count} items': '%{count} objekt'
        });

        expect(ngettext('1 item', '%{count} items', 1))
          .toBe('1 objekt');
        expect(ngettext('1 item', '%{count} items', 5))
          .toBe('5 objekt');
      });

      it('should handle empty vars object', () => {
        initTranslations({
          '1 item': '1 objekt',
          '%{count} items': '%{count} objekt'
        });

        expect(ngettext('1 item', '%{count} items', 5, {}))
          .toBe('5 objekt');
      });

      it('should handle special characters in plural forms', () => {
        initTranslations({
          '1 "item"': '1 "objekt"',
          '%{count} "items"': '%{count} "objekt"'
        });

        expect(ngettext('1 "item"', '%{count} "items"', 1))
          .toBe('1 "objekt"');
        expect(ngettext('1 "item"', '%{count} "items"', 5))
          .toBe('5 "objekt"');
      });
    });
  });

  describe('TypeScript types', () => {
    it('should accept TranslationVars with string values', () => {
      const vars: TranslationVars = { name: 'Anna', city: 'Stockholm' };
      initTranslations({ 'Hello %{name} from %{city}': 'Hej %{name} från %{city}' });
      expect(gettext('Hello %{name} from %{city}', vars))
        .toBe('Hej Anna från Stockholm');
    });

    it('should accept TranslationVars with number values', () => {
      const vars: TranslationVars = { count: 42, price: 99.99 };
      initTranslations({ 'Count: %{count}, Price: %{price}': 'Antal: %{count}, Pris: %{price}' });
      expect(gettext('Count: %{count}, Price: %{price}', vars))
        .toBe('Antal: 42, Pris: 99.99');
    });

    it('should accept TranslationVars with mixed values', () => {
      const vars: TranslationVars = { name: 'Anna', count: 5 };
      initTranslations({ 'Hello %{name}, you have %{count}': 'Hej %{name}, du har %{count}' });
      expect(gettext('Hello %{name}, you have %{count}', vars))
        .toBe('Hej Anna, du har 5');
    });
  });
});
