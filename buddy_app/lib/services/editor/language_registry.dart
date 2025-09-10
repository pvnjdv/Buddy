class LanguageDefinition {
  final String id;
  final List<String> keywords;
  final RegExp lineCommentPattern; // e.g. // or #
  const LanguageDefinition({
    required this.id,
    required this.keywords,
    required this.lineCommentPattern,
  });
}

class LanguageRegistry {
  static final LanguageRegistry I = LanguageRegistry._();
  LanguageRegistry._();
  final Map<String, LanguageDefinition> _languages = {};

  void register(LanguageDefinition def) {
    _languages[def.id] = def;
  }

  LanguageDefinition? get(String id) => _languages[id];
  List<LanguageDefinition> all() => _languages.values.toList();
}

void registerDefaultLanguages() {
  LanguageRegistry.I.register(
    LanguageDefinition(
      id: 'dart',
      keywords: [
        'class',
        'void',
        'int',
        'double',
        'String',
        'bool',
        'var',
        'final',
        'const',
        'if',
        'else',
        'for',
        'while',
        'return',
        'import',
        'extends',
        'with',
        'async',
        'await',
        'switch',
        'case',
      ],
      lineCommentPattern: RegExp(r'^\s*//'),
    ),
  );
  LanguageRegistry.I.register(
    LanguageDefinition(
      id: 'python',
      keywords: [
        'def',
        'class',
        'if',
        'else',
        'elif',
        'return',
        'import',
        'from',
        'as',
        'try',
        'except',
        'finally',
        'with',
        'lambda',
        'for',
        'while',
      ],
      lineCommentPattern: RegExp(r'^\s*#'),
    ),
  );
  LanguageRegistry.I.register(
    LanguageDefinition(
      id: 'javascript',
      keywords: [
        'function',
        'class',
        'if',
        'else',
        'return',
        'import',
        'export',
        'var',
        'let',
        'const',
        'for',
        'while',
        'async',
        'await',
      ],
      lineCommentPattern: RegExp(r'^\s*//'),
    ),
  );
}
