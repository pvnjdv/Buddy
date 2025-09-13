import 'package:flutter/material.dart';

class EditorTheme {
  final String name;
  final Color backgroundColor;
  final Color surfaceColor;
  final Color primaryColor;
  final Color accentColor;
  final Color textColor;
  final Color commentColor;
  final Color keywordColor;
  final Color stringColor;
  final Color numberColor;
  final Color operatorColor;
  final Color functionColor;
  final Color variableColor;
  final Color errorColor;
  final Color warningColor;
  final Color lineNumberColor;
  final Color selectionColor;
  final Color cursorColor;
  final Color gutterColor;

  const EditorTheme({
    required this.name,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.primaryColor,
    required this.accentColor,
    required this.textColor,
    required this.commentColor,
    required this.keywordColor,
    required this.stringColor,
    required this.numberColor,
    required this.operatorColor,
    required this.functionColor,
    required this.variableColor,
    required this.errorColor,
    required this.warningColor,
    required this.lineNumberColor,
    required this.selectionColor,
    required this.cursorColor,
    required this.gutterColor,
  });

  static const EditorTheme buddyDark = EditorTheme(
    name: 'Buddy Dark',
    backgroundColor: Color(0xFF1a1a1a),
    surfaceColor: Color(0xFF2d2d2d),
    primaryColor: Color(0xFF007acc),
    accentColor: Color(0xFF00d4ff),
    textColor: Color(0xFFd4d4d4),
    commentColor: Color(0xFF6a9955),
    keywordColor: Color(0xFF569cd6),
    stringColor: Color(0xFFce9178),
    numberColor: Color(0xFFb5cea8),
    operatorColor: Color(0xFFd4d4d4),
    functionColor: Color(0xFFdcdcaa),
    variableColor: Color(0xFF9cdcfe),
    errorColor: Color(0xFFf44747),
    warningColor: Color(0xFFffcc02),
    lineNumberColor: Color(0xFF858585),
    selectionColor: Color(0xFF264f78),
    cursorColor: Color(0xFFd4d4d4),
    gutterColor: Color(0xFF1e1e1e),
  );

  static const EditorTheme buddyLight = EditorTheme(
    name: 'Buddy Light',
    backgroundColor: Color(0xFFffffff),
    surfaceColor: Color(0xFFf3f3f3),
    primaryColor: Color(0xFF0078d4),
    accentColor: Color(0xFF005a9e),
    textColor: Color(0xFF000000),
    commentColor: Color(0xFF008000),
    keywordColor: Color(0xFF0000ff),
    stringColor: Color(0xFFa31515),
    numberColor: Color(0xFF098658),
    operatorColor: Color(0xFF000000),
    functionColor: Color(0xFF795e26),
    variableColor: Color(0xFF001080),
    errorColor: Color(0xFFcd3131),
    warningColor: Color(0xFFb8860b),
    lineNumberColor: Color(0xFF237893),
    selectionColor: Color(0xFFadd6ff),
    cursorColor: Color(0xFF000000),
    gutterColor: Color(0xFFf5f5f5),
  );

  static const EditorTheme monokai = EditorTheme(
    name: 'Monokai',
    backgroundColor: Color(0xFF272822),
    surfaceColor: Color(0xFF3e3d32),
    primaryColor: Color(0xFFf92672),
    accentColor: Color(0xFFa6e22e),
    textColor: Color(0xFFf8f8f2),
    commentColor: Color(0xFF75715e),
    keywordColor: Color(0xFFf92672),
    stringColor: Color(0xFFe6db74),
    numberColor: Color(0xFFae81ff),
    operatorColor: Color(0xFFf92672),
    functionColor: Color(0xFFa6e22e),
    variableColor: Color(0xFF66d9ef),
    errorColor: Color(0xFFf92672),
    warningColor: Color(0xFFfd971f),
    lineNumberColor: Color(0xFF90908a),
    selectionColor: Color(0xFF49483e),
    cursorColor: Color(0xFFf8f8f0),
    gutterColor: Color(0xFF2f3129),
  );

  static const List<EditorTheme> availableThemes = [
    buddyDark,
    buddyLight,
    monokai,
  ];
}
