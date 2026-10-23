import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'platform_update_stub.dart'
    if (dart.library.io) 'platform_update_io.dart' as platform_update;

class ReleaseAsset {
  final String name;
  final Uri url;
  const ReleaseAsset(this.name, this.url);
}

class AppRelease {
  final String tag;
  final String name;
  final String notes;
  final Uri pageUrl;
  final List<ReleaseAsset> assets;

  const AppRelease({
    required this.tag,
    required this.name,
    required this.notes,
    required this.pageUrl,
    required this.assets,
  });

  ReleaseAsset? get platformAsset {
    if (kIsWeb) return null;
    final wanted = switch (defaultTargetPlatform) {
      TargetPlatform.windows => 'media-archive-windows-setup.exe',
      TargetPlatform.linux => 'media-archive-linux-x64.tar.gz',
      TargetPlatform.macOS => 'media-archive-macos.zip',
      TargetPlatform.android => 'media-archive-android.apk',
      _ => null,
    };
    if (wanted == null) return null;
    for (final asset in assets) {
      if (asset.name.toLowerCase() == wanted) return asset;
    }
    return null;
  }
}

class UpdateService {
  static const _endpoint =
      'https://api.github.com/repos/Luke133yt/Media-Archive/releases/latest';
  static const _dismissedTagKey = 'dismissedReleaseTag';

  static Future<AppRelease?> latest() async {
    final response = await http.get(
      Uri.parse(_endpoint),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2026-03-10',
        'User-Agent': 'Media-Archive-Flutter',
      },
    ).timeout(const Duration(seconds: 12));
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception('GitHub ha risposto con HTTP ${response.statusCode}.');
    }
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    if (json is! Map<String, dynamic> || json['draft'] == true) return null;
    final tag = (json['tag_name'] ?? '').toString();
    final htmlUrl = Uri.tryParse((json['html_url'] ?? '').toString());
    if (tag.isEmpty || htmlUrl == null) return null;
    final assets = <ReleaseAsset>[];
    for (final raw in (json['assets'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final name = (raw['name'] ?? '').toString();
      final url = Uri.tryParse((raw['browser_download_url'] ?? '').toString());
      if (name.isNotEmpty && url != null && url.scheme == 'https') {
        assets.add(ReleaseAsset(name, url));
      }
    }
    return AppRelease(
      tag: tag,
      name: (json['name'] ?? tag).toString(),
      notes: (json['body'] ?? '').toString().trim(),
      pageUrl: htmlUrl,
      assets: assets,
    );
  }

  static List<int> _versionParts(String value) {
    final core =
        value.trim().replaceFirst(RegExp(r'^[vV]'), '').split('+').first;
    final numbers = core.split(RegExp(r'[-.]')).take(3);
    return numbers.map((part) => int.tryParse(part) ?? 0).toList();
  }

  static bool _isNewer(String latest, String current) {
    final a = _versionParts(latest);
    final b = _versionParts(current);
    for (var i = 0; i < 3; i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      if (av != bv) return av > bv;
    }
    return false;
  }

  static Future<void> checkAndPrompt(
    BuildContext context, {
    bool showUpToDate = false,
  }) async {
    try {
      final current = await PackageInfo.fromPlatform();
      final release = await latest();
      if (!context.mounted) return;
      if (release == null || !_isNewer(release.tag, current.version)) {
        if (showUpToDate) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hai già l’ultima versione.')),
          );
        }
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      if (!context.mounted ||
          (!showUpToDate && prefs.getString(_dismissedTagKey) == release.tag)) {
        return;
      }
      await _showReleaseDialog(context, release, current.version, prefs);
    } catch (error) {
      if (showUpToDate && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Controllo aggiornamenti non riuscito: $error')),
        );
      }
    }
  }

  static Future<void> _showReleaseDialog(
    BuildContext context,
    AppRelease release,
    String currentVersion,
    SharedPreferences prefs,
  ) async {
    var downloading = false;
    double? progress;
    String? downloadError;
    final asset = release.platformAsset;
    final windowsInstaller = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.windows &&
        asset?.name.toLowerCase().endsWith('.exe') == true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Media Archive ${release.tag} è disponibile'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Versione installata: $currentVersion'),
                  if (release.notes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(release.notes,
                        maxLines: 14, overflow: TextOverflow.ellipsis),
                  ],
                  if (downloading) ...[
                    const SizedBox(height: 18),
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 8),
                    Text(progress == null
                        ? 'Download in corso…'
                        : 'Download: ${(progress! * 100).round()}%'),
                  ],
                  if (downloadError != null) ...[
                    const SizedBox(height: 12),
                    Text(downloadError!,
                        style: TextStyle(
                            color: Theme.of(dialogContext).colorScheme.error)),
                  ],
                  if (asset == null) ...[
                    const SizedBox(height: 12),
                    const Text(
                        'Il pacchetto per questa piattaforma si trova nella pagina Release di GitHub.'),
                  ] else if (!windowsInstaller) ...[
                    const SizedBox(height: 12),
                    const Text(
                        'Il pacchetto verrà scaricato; l’installazione finale segue le conferme richieste dal sistema operativo.'),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: downloading
                  ? null
                  : () async {
                      await prefs.setString(_dismissedTagKey, release.tag);
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    },
              child: const Text('Ricordamelo più tardi'),
            ),
            FilledButton.icon(
              onPressed: downloading
                  ? null
                  : () async {
                      if (windowsInstaller) {
                        setDialogState(() {
                          downloading = true;
                          progress = null;
                          downloadError = null;
                        });
                        try {
                          await platform_update.installWindowsUpdate(
                            asset!.url,
                            asset.name,
                            (value) {
                              if (dialogContext.mounted) {
                                setDialogState(() => progress = value);
                              }
                            },
                          );
                          if (!dialogContext.mounted) return;
                        } catch (error) {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              downloading = false;
                              downloadError =
                                  'Download o avvio installazione non riuscito: $error';
                            });
                          }
                        }
                      } else {
                        final destination = asset?.url ?? release.pageUrl;
                        final opened = await launchUrl(
                          destination,
                          mode: LaunchMode.externalApplication,
                        );
                        if (!opened && dialogContext.mounted) {
                          setDialogState(() => downloadError =
                              'Impossibile aprire il download. Visita ${release.pageUrl}.');
                        }
                      }
                    },
              icon: Icon(
                  windowsInstaller ? Icons.system_update_alt : Icons.download),
              label: Text(windowsInstaller
                  ? 'Aggiorna ora'
                  : asset == null
                      ? 'Apri Release'
                      : 'Scarica aggiornamento'),
            ),
          ],
        ),
      ),
    );
  }
}
