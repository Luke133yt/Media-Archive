import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store.dart';

String _language(BuildContext context) =>
    context.read<AppState>().tmdbLang.split(RegExp(r'[-_]')).first;

String _translate(String code, String italian, {int? added, int? unmatched}) {
  final lang = code.toLowerCase();
  if (added != null && unmatched != null) {
    return switch (lang) {
      'en' => 'Imported $added titles. $unmatched not matched on TMDB.',
      'fr' => '$added titres importés. $unmatched sans correspondance TMDB.',
      'de' => '$added Titel importiert. $unmatched ohne TMDB-Treffer.',
      'es' => '$added títulos importados. $unmatched sin coincidencia en TMDB.',
      'pt' =>
        '$added títulos importados. $unmatched sem correspondência no TMDB.',
      'ja' => '$added 件をインポートしました。TMDB 未一致: $unmatched 件。',
      _ => 'Importati $added titoli. $unmatched senza corrispondenza TMDB.',
    };
  }
  if (added != null) {
    return switch (lang) {
      'en' => 'Imported $added titles without linking to TMDB.',
      'fr' => '$added titres importés sans association à TMDB.',
      'de' => '$added Titel ohne TMDB-Verknüpfung importiert.',
      'es' => '$added títulos importados sin vincular a TMDB.',
      'pt' => '$added títulos importados sem vínculo com o TMDB.',
      'ja' => 'TMDB に紐付けず $added 件をインポートしました。',
      _ => 'Importati $added titoli senza collegamento TMDB.',
    };
  }

  final messages = <String, Map<String, String>>{
    'Recensione salvata': {
      'it': 'Recensione salvata!',
      'en': 'Review saved!',
      'fr': 'Critique enregistrée !',
      'de': 'Rezension gespeichert!',
      'es': '¡Reseña guardada!',
      'pt': 'Avaliação salva!',
      'ja': 'レビューを保存しました！',
    },
    'Dati aggiornati da TMDB': {
      'it': 'Dati aggiornati da TMDB!',
      'en': 'TMDB details updated!',
      'fr': 'Données TMDB mises à jour !',
      'de': 'TMDB-Daten aktualisiert!',
      'es': '¡Datos de TMDB actualizados!',
      'pt': 'Dados do TMDB atualizados!',
      'ja': 'TMDB の情報を更新しました！',
    },
    'Titolo e dati TMDB sostituiti': {
      'it': 'Titolo e dati TMDB sostituiti!',
      'en': 'Title and TMDB details replaced!',
      'fr': 'Titre et données TMDB remplacés !',
      'de': 'Titel und TMDB-Daten ersetzt!',
      'es': '¡Título y datos de TMDB reemplazados!',
      'pt': 'Título e dados do TMDB substituídos!',
      'ja': 'タイトルと TMDB 情報を置き換えました！',
    },
    'Operazione completata': {
      'it': 'Operazione completata.',
      'en': 'Done.',
      'fr': 'Terminé.',
      'de': 'Erledigt.',
      'es': 'Listo.',
      'pt': 'Concluído.',
      'ja': '完了しました。',
    },
  };
  return messages[italian]?[lang] ?? italian;
}

void showAppSnack(BuildContext context, String message) {
  final trimmed = message.trim();
  var localized = trimmed.isEmpty
      ? _translate(_language(context), 'Operazione completata')
      : trimmed;
  final code = _language(context);
  final tmdbImport =
      RegExp(r'^Importati (\d+) titoli\. (\d+) senza corrispondenza TMDB\.$')
          .firstMatch(trimmed);
  final rawImport =
      RegExp(r'^Importati (\d+) titoli senza collegamento TMDB\.$')
          .firstMatch(trimmed);
  if (tmdbImport != null) {
    localized = _translate(code, '',
        added: int.parse(tmdbImport.group(1)!),
        unmatched: int.parse(tmdbImport.group(2)!));
  } else if (rawImport != null) {
    localized = _translate(code, '', added: int.parse(rawImport.group(1)!));
  } else if (trimmed.isNotEmpty) {
    localized = _translate(code, trimmed);
  }

  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.clearSnackBars();
  messenger.showSnackBar(SnackBar(
    content: Text(
      localized.isEmpty ? _translate(code, 'Operazione completata') : localized,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
    ),
    backgroundColor: const Color(0xFF273052),
    behavior: SnackBarBehavior.floating,
    duration: const Duration(seconds: 3),
  ));
}
