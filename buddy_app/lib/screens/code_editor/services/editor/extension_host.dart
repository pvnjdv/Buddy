import 'dart:async';
import 'command_registry.dart';

// Deprecated duplicate. Forwarding to canonical implementation.
export '../../../../services/editor/extension_host.dart';

class BuddyExtensionManifest {
  final String name;
  final String publisher;
  final String version;
  final List<String>
  activationEvents; // e.g. onLanguage:dart, onCommand:file.save
  final List<String> contributesCommands;
  final List<String> contributesLanguages;

  BuddyExtensionManifest({
    required this.name,
    required this.publisher,
    required this.version,
    required this.activationEvents,
    required this.contributesCommands,
    required this.contributesLanguages,
  });

  factory BuddyExtensionManifest.fromJson(Map<String, dynamic> j) {
    return BuddyExtensionManifest(
      name: j['name'] ?? 'unknown',
      publisher: j['publisher'] ?? 'unknown',
      version: j['version'] ?? '0.0.0',
      activationEvents: List<String>.from(j['activationEvents'] ?? []),
      contributesCommands: List<String>.from(
        j['contributes']?['commands'] ?? [],
      ),
      contributesLanguages: List<String>.from(
        j['contributes']?['languages'] ?? [],
      ),
    );
  }
}

abstract class BuddyExtension {
  final BuddyExtensionManifest manifest;
  bool _activated = false;
  BuddyExtension(this.manifest);
  Future<void> activate();
  Future<void> dispose() async {}
  bool get isActivated => _activated;
  Future<void> $internalActivate() async {
    if (_activated) return;
    await activate();
    _activated = true;
  }
}

class ExtensionHost {
  static final ExtensionHost I = ExtensionHost._();
  ExtensionHost._();

  final List<BuddyExtension> _extensions = [];
  final StreamController<BuddyExtension> _activatedController =
      StreamController.broadcast();

  Stream<BuddyExtension> get onActivated => _activatedController.stream;

  Future<void> load(BuddyExtension ext) async {
    _extensions.add(ext);
  }

  Future<void> activateWhere(String event) async {
    for (final ext in _extensions) {
      if (ext.isActivated) continue;
      if (ext.manifest.activationEvents.any((e) => e == event)) {
        await ext.$internalActivate();
        _activatedController.add(ext);
      }
    }
  }

  List<BuddyExtension> get loaded => List.unmodifiable(_extensions);
}

class CoreBasicsExtension extends BuddyExtension {
  CoreBasicsExtension()
    : super(
        BuddyExtensionManifest(
          name: 'core-basics',
          publisher: 'buddy',
          version: '1.0.0',
          activationEvents: ['onStartup'],
          contributesCommands: ['file.save', 'view.toggleSidebar'],
          contributesLanguages: ['dart', 'python'],
        ),
      );
  @override
  Future<void> activate() async {
    CommandRegistry.I.register(
      CommandEntry(
        id: 'core.hello',
        title: 'Core Hello',
        handler: (ctx) async {},
      ),
    );
  }
}
