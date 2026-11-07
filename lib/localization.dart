import 'package:flutter/material.dart' as m;

/// Lightweight UI translations. Metadata supplied by TMDB and user content
/// are deliberately left untouched.
class AppStrings {
  static String language = 'en';

  static final Map<String, String> _english = {
    'Aggiungi': 'Add',
    'Aggiungi titolo': 'Add title',
    'Segna come prestato': 'Mark as loaned',
    'Restituito': 'Returned',
    'Made With Love By': 'Made with love by',
    'Nuovo titolo': 'New title',
    'Archivio': 'Library',
    'Impostazioni': 'Settings',
    'Movie Night': 'Movie Night',
    'Movie Night!': 'Movie Night!',
    'Film': 'Movie',
    'Serie TV': 'TV series',
    'Annulla': 'Cancel',
    'Chiudi': 'Close',
    'Salva': 'Save',
    'Elimina': 'Delete',
    'Rimuovi': 'Remove',
    'Svuota': 'Clear',
    'Titolo': 'Title',
    'Titolo originale': 'Original title',
    'Anno': 'Year',
    'Anno sconosciuto': 'Unknown year',
    'Regia': 'Director',
    'Trama': 'Overview',
    'Locandina': 'Poster',
    'Supporto': 'Format',
    'Dettagli della tua copia': 'Your copy details',
    'Altro formato': 'Other format',
    'Scrivi un formato e premi +': 'Enter a format and press +',
    'Standard / regione': 'Standard / region',
    'Lingua del media': 'Media language',
    'Lingua dell’interfaccia': 'Interface language',
    'Prezzo pagato': 'Purchase price',
    'Codice a barre': 'Barcode',
    'Note': 'Notes',
    'Archiviato sul server': 'Archived on server',
    'Già visto': 'Watched',
    'Lost Media': 'Lost media',
    'Questo media è considerato perduto o irreperibile':
        'This title is considered lost or unavailable',
    'Hai già copiato questo media sul tuo archivio locale':
        'You have already copied this title to your local archive',
    'L’immagine viene letta dal percorso selezionato sul dispositivo.':
        'The image is loaded from the selected location on this device.',
    'Scegli immagine': 'Choose image',
    'Cerca su TMDB (film o serie TV)': 'Search TMDB (movies or TV series)',
    'Scansiona codice a barre': 'Scan barcode',
    'Inserisci a mano (senza TMDB)': 'Add manually (without TMDB)',
    'Cerca titolo, regista, attore, barcode…':
        'Search title, director, cast, barcode…',
    'Cerca titolo, regista, attore, formato…':
        'Search title, director, cast, format…',
    'Ordina': 'Sort',
    'Aggiunti di recente': 'Recently added',
    'Mio voto': 'My rating',
    'In prestito': 'On loan',
    'Non archiviati': 'Not archived',
    'La tua collezione è vuota.\nPremi + per aggiungere il primo titolo.':
        'Your collection is empty.\nPress + to add your first title.',
    'Nessun risultato con questi filtri.': 'No results match these filters.',
    'Inserisci un titolo': 'Enter a title',
    'Scansiona il codice a barre': 'Scan barcode',
    'OK': 'OK',
    'Impossibile usare fotocamera': 'Unable to use camera',
    'Segna questo titolo come perduto': 'Mark this title as lost',
    'Valuta la qualità della tua copia, a mezzi DVD.':
        'Rate the quality of your copy in half-DVD steps.',
    'Nessun risultato trovato': 'No results found',
    'Sostituisci': 'Replace',
    'Unisci': 'Merge',
    'Nessun titolo corrisponde alla ricerca.': 'No titles match your search.',
    'In casa. Nessun prestito attivo.': 'At home. No active loan.',
    'Crea un account gratuito su themoviedb.org → Impostazioni → API, '
            'poi incolla qui la "API Key" oppure il "Read Access Token".':
        'Create a free account at themoviedb.org → Settings → API, then paste '
            'your API key or Read Access Token here.',
    'Chiave TMDB': 'TMDB API key',
    'PAL, NTSC, Region 2…': 'PAL, NTSC, Region 2…',
    'Lingua dei dati TMDB': 'TMDB data language',
    'Lingua predefinita dei media': 'Default media language',
    'Precompilata nei nuovi titoli': 'Pre-filled for new titles',
    'Salva e verifica chiave': 'Save and verify key',
    'Tema scuro': 'Dark theme',
    'Tema scuro attivo (predefinito)': 'Dark theme is on (default)',
    'Tema chiaro attivo': 'Light theme is on',
    'Riduci risorse': 'Reduce resource use',
    'Disattiva le macchie animate e mantiene solo lo sfondo a gradiente.':
        'Turn off animated background effects and keep the gradient background.',
    'Aggiornamenti': 'Updates',
    'Controlla le release pubblicate su GitHub e installa la versione più recente disponibile per questo dispositivo.':
        'Check GitHub releases and install the latest version available for this device.',
    'Controlla aggiornamenti': 'Check for updates',
    'Backup e importazione': 'Backup and import',
    'Il backup JSON contiene tutto (titoli, recensioni, prestiti, formati). '
            'L’import accetta backup JSON, CSV e XML (anche da Filmotech).':
        'The JSON backup contains everything (titles, reviews, loans, formats). '
            'Import supports JSON, CSV and XML files, including Filmotech exports.',
    'Backup JSON': 'JSON backup',
    'Esporta CSV': 'Export CSV',
    'Importa file': 'Import file',
    'Formati dei media': 'Media formats',
    'Nuovo formato': 'New format',
    'Nuovo formato facoltativo': 'New format (optional)',
    'Importa così com’è': 'Import as-is',
    'es. DIVX': 'e.g. DIVX',
    'Titolo importato senza TMDB': 'Title imported without TMDB',
    'Questo titolo è già presente nella collezione.':
        'This title is already in your collection.',
    'Prestito e promemoria salvati': 'Loan and reminder saved',
    'es. CED, Video CD, UMD…': 'e.g. CED, Video CD, UMD…',
    'Ripristina formati predefiniti': 'Restore default formats',
    'Zona pericolosa': 'Danger zone',
    'Svuota archivio': 'Clear archive',
    'Collegare i titoli a TMDB?': 'Match titles with TMDB?',
    'Puoi cercare i corrispondenti su TMDB e importare i dati arricchiti, oppure importare direttamente i dati del file senza cercare corrispondenze.':
        'Search TMDB for matching titles and import enriched details, or import the file as-is without matching.',
    'Importa senza TMDB': 'Import without TMDB',
    'Cerca su TMDB': 'Search TMDB',
    'Configura prima la chiave TMDB oppure scegli l’import senza TMDB.':
        'Set up your TMDB key first, or choose to import without TMDB.',
    'Ricerca corrispondenze su TMDB…': 'Searching for TMDB matches…',
    'Non trovati su TMDB': 'Not found on TMDB',
    'Scarica CSV': 'Download CSV',
    'Cerca manualmente ciascun titolo e seleziona il risultato corretto.':
        'Search for each title manually and select the correct result.',
    'Sostituisci con un risultato TMDB': 'Replace with a TMDB result',
    'Sostituisci titolo da TMDB': 'Replace title from TMDB',
    'Titolo del film o della serie': 'Movie or series title',
    'Aggiorna da TMDB': 'Update from TMDB',
    'Titolo non trovato': 'Title not found',
    'Rimuovere dalla collezione?': 'Remove from collection?',
    'Trade — prestito': 'Loan',
    'Prestato a': 'Loaned to',
    'Promemoria prestiti': 'Loan reminders',
    'Dal': 'From',
    'Svuotare tutto l\'archivio?': 'Clear the entire archive?',
    'Da restituire entro (facoltativo)': 'Return by (optional)',
    'Nessuna scadenza': 'No due date',
    'La mia recensione': 'My review',
    'Salva recensione': 'Save review',
    'Nessuna immagine disponibile': 'No images available',
    'Foto precedente': 'Previous photo',
    'Foto successiva': 'Next photo',
    'Importa la collezione di un amico e scegli il film da vedere stasera. Il CSV sarà consultabile solo per questa sessione e non verrà aggiunto al tuo archivio.':
        'Import a friend’s collection and choose tonight’s movie. The CSV is available only for this session and will not be added to your archive.',
    'Importa collezione CSV': 'Import CSV collection',
    'Cambia CSV': 'Change CSV',
    'Collezione condivisa': 'Shared collection',
    'Rimuovi collezione temporanea': 'Remove temporary collection',
    'Biografia': 'Biography',
    'Filmografia': 'Filmography',
    'Nessuna opera trovata su TMDB.': 'No credits found on TMDB.',
    'Dati biografici e filmografia forniti da TMDB.':
        'Biography and filmography provided by TMDB.',
    'Riprova': 'Try again',
    'Digita il codice oppure usa un lettore USB: premi qui e scansiona.':
        'Type the code or use a USB scanner: focus here and scan.',
    'EAN / UPC': 'EAN / UPC',
    'Formato nell’app': 'App format',
    'Converti tipologia media': 'Convert media type',
    'Annulla import': 'Cancel import',
    'Applica a tutti': 'Apply to all',
    'Svuotare tutto l’archivio?': 'Clear the entire archive?',
    'Verranno eliminati tutti i titoli. Esporta prima un backup se non sei sicuro.':
        'All titles will be deleted. Export a backup first if you are unsure.',
    'Foto': 'Photos',
    'Errore': 'Error',
    'Modifica': 'Edit',
  };

  static String translate(String value) {
    if (language != 'en') return value;
    final direct = _english[value];
    if (direct != null) return direct;
    final count = RegExp(r'^(\d+) titoli in collezione$').firstMatch(value);
    if (count != null) return '${count.group(1)} titles in collection';
    final importCount = RegExp(r'^Importare (\d+) titoli\?$').firstMatch(value);
    if (importCount != null) return 'Import ${importCount.group(1)} titles?';
    final director = RegExp(r'^Regia: (.*)$').firstMatch(value);
    if (director != null) return 'Director: ${director.group(1)}';
    final notes = RegExp(r'^Note: (.*)$').firstMatch(value);
    if (notes != null) return 'Notes: ${notes.group(1)}';
    final loanReminder =
        RegExp(r'^Prestato a (.*) · Rientro il (.*)$').firstMatch(value);
    if (loanReminder != null) {
      return 'Loaned to ${loanReminder.group(1)} · Due on ${loanReminder.group(2)}';
    }
    final borrower = RegExp(r'^Prestato a (.*)$').firstMatch(value);
    if (borrower != null) return 'Loaned to ${borrower.group(1)}';
    final moreReminders =
        RegExp(r'^\+ (\d+) altri in scadenza$').firstMatch(value);
    if (moreReminders != null) {
      return '+ ${moreReminders.group(1)} more due soon';
    }
    final since = RegExp(r'^Dal (.*)$').firstMatch(value);
    if (since != null) return 'Since ${since.group(1)}';
    final returnBy = RegExp(r'^Da restituire entro il (.*)$').firstMatch(value);
    if (returnBy != null) return 'Return by ${returnBy.group(1)}';
    final confirmDelete = RegExp(r'^"(.*)" verrà eliminato dal tuo archivio\.$')
        .firstMatch(value);
    if (confirmDelete != null) {
      return '“${confirmDelete.group(1)}” will be removed from your archive.';
    }
    final budget = RegExp(r'^Budget: (.*)$').firstMatch(value);
    if (budget != null) return 'Budget: ${budget.group(1)}';
    final revenue = RegExp(r'^Incasso mondiale: (.*)$').firstMatch(value);
    if (revenue != null) return 'Worldwide gross: ${revenue.group(1)}';
    final profit = RegExp(r'^Utile lordo: (.*)$').firstMatch(value);
    if (profit != null) return 'Gross profit: ${profit.group(1)}';
    final addedOn = RegExp(r'^Aggiunto il (.*)$').firstMatch(value);
    if (addedOn != null) return 'Added on ${addedOn.group(1)}';
    final born = RegExp(r'^Nato/a il (.*)$').firstMatch(value);
    if (born != null) return 'Born ${born.group(1)}';
    final died = RegExp(r'^Deceduto/a il (.*)$').firstMatch(value);
    if (died != null) return 'Died ${died.group(1)}';
    final tmdbVote = RegExp(r'^([\d.]+) TMDB$').firstMatch(value);
    if (tmdbVote != null) return '${tmdbVote.group(1)} TMDB';
    final emptySearch =
        RegExp(r'^Nessun risultato per “(.*)”\.$').firstMatch(value);
    if (emptySearch != null) return 'No results for “${emptySearch.group(1)}”.';
    final importError =
        RegExp(r'^Import non riuscito: (.*)$').firstMatch(value);
    if (importError != null) return 'Import failed: ${importError.group(1)}';
    final newFormat =
        RegExp(r'^(.*) \(nuovo formato dal file\)$').firstMatch(value);
    if (newFormat != null) {
      return '${newFormat.group(1)} (new format from file)';
    }
    final movieNightCount =
        RegExp(r'^(\d+) di (\d+) titoli$').firstMatch(value);
    if (movieNightCount != null) {
      return '${movieNightCount.group(1)} of ${movieNightCount.group(2)} titles';
    }
    final castCount =
        RegExp(r'^(\d+) film · (\d+) serie TV$').firstMatch(value);
    if (castCount != null) {
      return '${castCount.group(1)} films · ${castCount.group(2)} TV shows';
    }
    final shown = RegExp(r'^• (\d+) mostrati$').firstMatch(value);
    if (shown != null) return '• ${shown.group(1)} shown';
    final unmatched =
        RegExp(r'^Non trovati su TMDB \((\d+)\)$').firstMatch(value);
    if (unmatched != null) return 'Not found on TMDB (${unmatched.group(1)})';
    final search = RegExp(r'^Cerca “(.+)” su TMDB$').firstMatch(value);
    if (search != null) return 'Search TMDB for “${search.group(1)}”';
    return value;
  }
}

/// Translates interface copy while leaving film titles and user content intact.
class Text extends m.StatelessWidget {
  const Text(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
    this.localize = true,
  });

  final String data;
  final m.TextStyle? style;
  final m.StrutStyle? strutStyle;
  final m.TextAlign? textAlign;
  final m.TextDirection? textDirection;
  final m.Locale? locale;
  final bool? softWrap;
  final m.TextOverflow? overflow;
  final m.TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final m.TextWidthBasis? textWidthBasis;
  final m.TextHeightBehavior? textHeightBehavior;
  final m.Color? selectionColor;
  final bool localize;

  @override
  m.Widget build(m.BuildContext context) => m.Text(
        localize ? AppStrings.translate(data) : data,
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
}
