import 'models.dart';

/// Stub per piattaforme senza `dart:io` (web).
class NuvioAddonServer {
  NuvioAddonServer._();
  static final NuvioAddonServer instance = NuvioAddonServer._();

  bool get isRunning => false;
  String? get manifestUrl => null;
  int get port => 0;

  Future<String> start(List<MediaItem> Function() items) async {
    throw UnsupportedError(
        'Il server addon Nuvio/Stremio non è disponibile su questa piattaforma. '
        'Usa l’addon Node in stremio_addon/ oppure carica il backup JSON da URL.');
  }

  Future<void> stop() async {}

  void refresh() {}
}
