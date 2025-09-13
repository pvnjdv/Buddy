import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/vs.dart';
import 'package:flutter_highlight/themes/vs2015.dart';
import 'package:flutter_highlight/themes/monokai.dart';
import '../models/editor_theme.dart';

class SyntaxHighlightService {
  static Map<String, TextStyle> getHighlightTheme(EditorTheme theme) {
    switch (theme.name) {
      case 'Buddy Light':
        return {
          ...vsTheme,
          'root': TextStyle(
            backgroundColor: theme.backgroundColor,
            color: theme.textColor,
          ),
        };
      case 'Monokai':
        return {
          ...monokaiTheme,
          'root': TextStyle(
            backgroundColor: theme.backgroundColor,
            color: theme.textColor,
          ),
        };
      default: // Buddy Dark
        return {
          ...vs2015Theme,
          'root': TextStyle(
            backgroundColor: theme.backgroundColor,
            color: theme.textColor,
          ),
        };
    }
  }

  static List<String> getSupportedLanguages() {
    return [
      'dart',
      'javascript',
      'typescript',
      'python',
      'java',
      'cpp',
      'c',
      'csharp',
      'php',
      'ruby',
      'go',
      'rust',
      'kotlin',
      'swift',
      'html',
      'css',
      'scss',
      'json',
      'xml',
      'yaml',
      'markdown',
      'sql',
      'bash',
      'plaintext',
    ];
  }

  static String normalizeLanguage(String language) {
    switch (language.toLowerCase()) {
      case 'js':
        return 'javascript';
      case 'ts':
        return 'typescript';
      case 'py':
        return 'python';
      case 'rb':
        return 'ruby';
      case 'kt':
        return 'kotlin';
      case 'cs':
        return 'csharp';
      case 'cpp':
      case 'cc':
      case 'cxx':
        return 'cpp';
      case 'rs':
        return 'rust';
      case 'sh':
        return 'bash';
      case 'yml':
        return 'yaml';
      case 'md':
        return 'markdown';
      default:
        return language.toLowerCase();
    }
  }

  static bool isLanguageSupported(String language) {
    final normalizedLanguage = normalizeLanguage(language);
    return getSupportedLanguages().contains(normalizedLanguage);
  }

  static List<String> getKeywordsForLanguage(String language) {
    switch (normalizeLanguage(language)) {
      case 'dart':
        return [
          'abstract',
          'as',
          'assert',
          'async',
          'await',
          'break',
          'case',
          'catch',
          'class',
          'const',
          'continue',
          'default',
          'do',
          'else',
          'enum',
          'extends',
          'final',
          'finally',
          'for',
          'if',
          'implements',
          'import',
          'in',
          'is',
          'library',
          'new',
          'null',
          'return',
          'super',
          'switch',
          'this',
          'throw',
          'try',
          'var',
          'void',
          'while',
          'with',
          'yield',
        ];
      case 'javascript':
        return [
          'abstract',
          'arguments',
          'await',
          'boolean',
          'break',
          'byte',
          'case',
          'catch',
          'char',
          'class',
          'const',
          'continue',
          'debugger',
          'default',
          'delete',
          'do',
          'double',
          'else',
          'enum',
          'eval',
          'export',
          'extends',
          'false',
          'final',
          'finally',
          'float',
          'for',
          'function',
          'goto',
          'if',
          'implements',
          'import',
          'in',
          'instanceof',
          'int',
          'interface',
          'let',
          'long',
          'native',
          'new',
          'null',
          'package',
          'private',
          'protected',
          'public',
          'return',
          'short',
          'static',
          'super',
          'switch',
          'synchronized',
          'this',
          'throw',
          'throws',
          'transient',
          'true',
          'try',
          'typeof',
          'var',
          'void',
          'volatile',
          'while',
          'with',
          'yield',
        ];
      case 'python':
        return [
          'and',
          'as',
          'assert',
          'break',
          'class',
          'continue',
          'def',
          'del',
          'elif',
          'else',
          'except',
          'exec',
          'finally',
          'for',
          'from',
          'global',
          'if',
          'import',
          'in',
          'is',
          'lambda',
          'not',
          'or',
          'pass',
          'print',
          'raise',
          'return',
          'try',
          'while',
          'with',
          'yield',
        ];
      default:
        return [];
    }
  }
}
