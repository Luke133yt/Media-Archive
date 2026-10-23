import 'package:flutter/material.dart';
import 'app_snack.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import 'edit_page.dart';
import 'format_icon.dart';
import 'glass.dart';
import 'image_gallery.dart';
import 'person_page.dart';

String _ago(DateTime d) {
  final days = DateTime.now().difference(d).inDays;
  if (days <= 0) return 'oggi';
  if (days == 1) return 'ieri';
  if (days < 30) return '$days giorni fa';
  if (days < 365) {
    final m = days ~/ 30;
    return m == 1 ? '1 mese fa' : '$m mesi fa';
  }
  final y = days ~/ 365;
  final m = (days % 365) ~/ 30;
  return '${y == 1 ? '1 anno' : '$y anni'}${m > 0 ? ' e ${m == 1 ? '1 mese' : '$m mesi'}' : ''} fa';
}

String _ratingLabel(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);

class DetailPage extends StatefulWidget {
  final String itemId;
  const DetailPage({super.key, required this.itemId});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  final _review = TextEditingController();
  bool _reviewLoaded = false;
  bool _refreshing = false;

  @override
  void dispose() {
    _review.dispose();
    super.dispose();
  }

  Future<void> _delete(MediaItem m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rimuovere dalla collezione?'),
        content: Text('"${m.title}" verrà eliminato dal tuo archivio.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Elimina')),
        ],
      ),
    );
    if (ok == true) {
      context.read<AppState>().remove(m.id);
      Navigator.of(context).pop();
    }
  }

  Future<void> _refresh(MediaItem m) async {
    final state = context.read<AppState>();
    final tmdb = state.tmdb;
    if (tmdb == null || m.tmdbId == null) return;
    setState(() => _refreshing = true);
    try {
      final fresh = await tmdb.details(m.tmdbId!, m.type);
      final n = m.clone()
        ..title = fresh.title
        ..originalTitle = fresh.originalTitle
        ..year = fresh.year
        ..overview = fresh.overview
        ..tagline = fresh.tagline
        ..posterPath = fresh.posterPath
        ..backdropPath = fresh.backdropPath
        ..genres = fresh.genres
        ..runtime = fresh.runtime
        ..voteAverage = fresh.voteAverage
        ..budget = fresh.budget
        ..revenue = fresh.revenue
        ..seasons = fresh.seasons
        ..director = fresh.director
        ..cast = fresh.cast
        ..reviews = fresh.reviews;
      state.upsert(n);
      _snack('Dati aggiornati da TMDB');
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _swapTmdb(MediaItem current) async {
    final tmdb = context.read<AppState>().tmdb;
    if (tmdb == null) {
      _snack('Configura prima la chiave TMDB');
      return;
    }
    final query = TextEditingController(text: current.title);
    var results = <TmdbResult>[];
    var searching = false;
    try {
      final selected = await showDialog<TmdbResult>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDlg) {
            Future<void> runSearch() async {
              if (query.text.trim().isEmpty) return;
              setDlg(() => searching = true);
              try {
                final found = await tmdb.search(query.text.trim());
                if (ctx.mounted) setDlg(() => results = found);
              } catch (e) {
                if (mounted) _snack('Ricerca TMDB non riuscita: $e');
              } finally {
                if (ctx.mounted) setDlg(() => searching = false);
              }
            }

            return AlertDialog(
              title: const Text('Sostituisci con un risultato TMDB'),
              content: SizedBox(
                width: 520,
                height: 440,
                child: Column(children: [
                  TextField(
                    controller: query,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => runSearch(),
                    decoration: InputDecoration(
                      labelText: 'Titolo del film o della serie',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: runSearch,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: searching
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            itemCount: results.length,
                            itemBuilder: (_, index) {
                              final r = results[index];
                              return ListTile(
                                leading: Poster(
                                    path: r.posterPath,
                                    width: 42,
                                    height: 62,
                                    radius: 4),
                                title: Text(r.title),
                                subtitle: Text(
                                    '${r.year ?? 'Anno sconosciuto'} · ${r.type == 'tv' ? 'Serie TV' : 'Film'}'),
                                onTap: () => Navigator.pop(ctx, r),
                              );
                            },
                          ),
                  ),
                ]),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Annulla'))
              ],
            );
          },
        ),
      );
      if (selected == null || !mounted) return;
      final fresh = await tmdb.details(selected.id, selected.type);
      final replacement = fresh
        ..id = current.id
        ..addedAt = current.addedAt
        ..format = current.format
        ..region = current.region
        ..mediaLanguage = current.mediaLanguage
        ..price = current.price
        ..barcode = current.barcode
        ..archived = current.archived
        ..lostMedia = current.lostMedia
        ..watched = current.watched
        ..notes = current.notes
        ..myRating = current.myRating
        ..qualityRating = current.qualityRating
        ..myReview = current.myReview
        ..loan = current.loan
        ..localPosterPath = null;
      context.read<AppState>().upsert(replacement);
      _snack('Titolo e dati TMDB sostituiti');
    } catch (e) {
      if (mounted) _snack('Ricerca/sostituzione non riuscita: $e');
    } finally {
      query.dispose();
    }
  }

  void _snack(String t) => showAppSnack(context, t);

  Future<void> _loanDialog(MediaItem m) async {
    final who = TextEditingController(text: m.loan?.borrower ?? '');
    final notes = TextEditingController(text: m.loan?.notes ?? '');
    var since = m.loan?.since ?? DateTime.now();
    DateTime? due = m.loan?.dueDate;
    final fmt = DateFormat('d MMM yyyy', 'it_IT');

    final res = await showDialog<LoanInfo>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Trade — prestito'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: who,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Prestato a'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: const Text('Dal'),
                subtitle: Text(fmt.format(since)),
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: since,
                    firstDate: DateTime(1990),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setD(() => since = d);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_available),
                title: const Text('Da restituire entro (facoltativo)'),
                subtitle:
                    Text(due == null ? 'Nessuna scadenza' : fmt.format(due!)),
                trailing: due == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setD(() => due = null),
                      ),
                onTap: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate:
                        due ?? DateTime.now().add(const Duration(days: 14)),
                    firstDate: DateTime(1990),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setD(() => due = d);
                },
              ),
              TextField(
                controller: notes,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annulla')),
            FilledButton(
              onPressed: () {
                if (who.text.trim().isEmpty) return;
                Navigator.pop(
                  ctx,
                  LoanInfo(
                    borrower: who.text.trim(),
                    since: since,
                    dueDate: due,
                    notes: notes.text.trim(),
                  ),
                );
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
    if (res != null) {
      context.read<AppState>().upsert(m.clone()..loan = res);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final m = state.byId(widget.itemId);
    if (m == null) {
      return const Scaffold(body: Center(child: Text('Titolo non trovato')));
    }
    if (!_reviewLoaded) {
      _review.text = m.myReview;
      _reviewLoaded = true;
    }
    final money =
        NumberFormat.currency(locale: 'it_IT', symbol: '\$', decimalDigits: 0);
    final euro = NumberFormat.currency(locale: 'it_IT', symbol: '€');
    final dateFmt = DateFormat('d MMM yyyy', 'it_IT');

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Sostituisci titolo da TMDB',
            onPressed: () => _swapTmdb(m),
            icon: const Icon(Icons.swap_horiz),
          ),
          if (m.tmdbId != null)
            IconButton(
              tooltip: 'Aggiorna da TMDB',
              onPressed: _refreshing ? null : () => _refresh(m),
              icon: _refreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync),
            ),
          IconButton(
            tooltip: 'Modifica',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => EditPage(item: m))),
          ),
          IconButton(
            tooltip: 'Elimina',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(m),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Testata con backdrop
          SizedBox(
            height: 320,
            child: Stack(fit: StackFit.expand, children: [
              if (m.backdropPath != null ||
                  m.localPosterPath != null ||
                  m.posterPath != null)
                Poster(
                  path: m.backdropPath ?? m.localPosterPath ?? m.posterPath,
                  fallbackPath:
                      m.backdropPath == null && m.localPosterPath != null
                          ? m.posterPath
                          : null,
                  radius: 0,
                  size: 'w780',
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.35),
                      const Color(0xFF0A0D22),
                    ],
                  ),
                ),
              ),
            ]),
          ),
          Transform.translate(
            offset: const Offset(0, -150),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => openMediaGallery(
                          context,
                          title: m.title,
                          type: m.type,
                          tmdbId: m.tmdbId,
                          localPosterPath: m.localPosterPath,
                          posterPath: m.posterPath,
                          backdropPath: m.backdropPath,
                          tmdb: state.tmdb,
                        ),
                        child: Poster(
                            path: m.localPosterPath ??
                                m.posterPath ??
                                m.backdropPath,
                            fallbackPath: m.localPosterPath != null
                                ? m.posterPath ?? m.backdropPath
                                : (m.posterPath != null
                                    ? m.backdropPath
                                    : null),
                            width: 130,
                            height: 195),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                            if (m.originalTitle.isNotEmpty &&
                                m.originalTitle != m.title)
                              Text(m.originalTitle,
                                  style: TextStyle(
                                      color: adaptiveTextColor(context,
                                          opacity: .6))),
                            const SizedBox(height: 6),
                            Text(
                              [
                                if (m.year != null) '${m.year}',
                                m.isTv ? 'Serie TV' : 'Film',
                                if (m.runtime != null) '${m.runtime} min',
                                if (m.seasons != null) '${m.seasons} stagioni',
                              ].join(' • '),
                              style: TextStyle(
                                  color:
                                      adaptiveTextColor(context, opacity: .7)),
                            ),
                            if (m.voteAverage != null && m.voteAverage! > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Row(children: [
                                  const Icon(Icons.star,
                                      color: Colors.amber, size: 18),
                                  const SizedBox(width: 4),
                                  Text(
                                      '${m.voteAverage!.toStringAsFixed(1)} TMDB'),
                                ]),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // La mia copia
                  GlassCard(
                    child: Row(children: [
                      FormatIcon(
                          format: m.format, size: 64, posterPath: m.posterPath),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.format,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Wrap(spacing: 8, runSpacing: 4, children: [
                              if (m.region.isNotEmpty)
                                _pill(Icons.public, m.region),
                              if (m.mediaLanguage.isNotEmpty)
                                _pill(Icons.translate, m.mediaLanguage),
                              if (m.price != null)
                                _pill(Icons.euro, euro.format(m.price)),
                              if (m.barcode.isNotEmpty)
                                _pill(Icons.qr_code, m.barcode),
                            ]),
                          ],
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: SwitchListTile(
                      secondary: const Icon(Icons.dns_outlined),
                      title: const Text('Archiviato sul server'),
                      value: m.archived,
                      onChanged: (v) => state.upsert(m.clone()..archived = v),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GlassCard(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: SwitchListTile(
                      secondary: const Icon(Icons.search_off_outlined),
                      title: const Text('Lost Media'),
                      subtitle: const Text('Segna questo titolo come perduto'),
                      value: m.lostMedia,
                      onChanged: (v) => state.upsert(m.clone()..lostMedia = v),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GlassCard(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: SwitchListTile(
                      secondary: const Icon(Icons.visibility_outlined),
                      title: const Text('Già visto'),
                      value: m.watched,
                      onChanged: (v) => state.upsert(m.clone()..watched = v),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle('Qualità del supporto'),
                        Row(children: [
                          DiscRating(
                            value: m.qualityRating,
                            onChanged: (v) =>
                                state.upsert(m.clone()..qualityRating = v),
                          ),
                          const SizedBox(width: 8),
                          Text(m.qualityRating == null
                              ? 'Non valutata'
                              : '${_ratingLabel(m.qualityRating!)}/5'),
                        ]),
                        const SizedBox(height: 4),
                        Text('Valuta la qualità della tua copia, a mezzi DVD.',
                            style: TextStyle(
                                color: adaptiveTextColor(context, opacity: .6),
                                fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Trade
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionTitle('Trade'),
                        if (m.loan == null) ...[
                          Text('In casa. Nessun prestito attivo.',
                              style: TextStyle(
                                  color:
                                      adaptiveTextColor(context, opacity: .7))),
                          const SizedBox(height: 10),
                          FilledButton.tonalIcon(
                            onPressed: () => _loanDialog(m),
                            icon: const Icon(Icons.swap_horiz),
                            label: const Text('Segna come prestato'),
                          ),
                        ] else ...[
                          Text('Prestato a ${m.loan!.borrower}',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(
                            'Dal ${dateFmt.format(m.loan!.since)} (${_ago(m.loan!.since)})',
                            style: TextStyle(
                                color: adaptiveTextColor(context, opacity: .7)),
                          ),
                          if (m.loan!.dueDate != null)
                            Text(
                              'Da restituire entro il ${dateFmt.format(m.loan!.dueDate!)}'
                              '${m.loan!.dueDate!.isBefore(DateTime.now()) ? ' — in ritardo' : ''}',
                              style: TextStyle(
                                color: m.loan!.dueDate!.isBefore(DateTime.now())
                                    ? Colors.orangeAccent
                                    : adaptiveTextColor(context, opacity: .7),
                              ),
                            ),
                          if (m.loan!.notes.isNotEmpty)
                            Text(m.loan!.notes,
                                style: TextStyle(
                                    color: adaptiveTextColor(context,
                                        opacity: .6))),
                          const SizedBox(height: 10),
                          Wrap(spacing: 8, children: [
                            FilledButton.icon(
                              onPressed: () =>
                                  state.upsert(m.clone()..loan = null),
                              icon: const Icon(Icons.assignment_return),
                              label: const Text('Restituito'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _loanDialog(m),
                              icon: const Icon(Icons.edit),
                              label: const Text('Modifica'),
                            ),
                          ]),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Mia recensione
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle('La mia recensione'),
                        Row(children: [
                          for (var i = 1; i <= 5; i++)
                            SizedBox(
                              width: 40,
                              height: 40,
                              child:
                                  Stack(alignment: Alignment.center, children: [
                                Icon(
                                  (m.myRating ?? 0) >= i
                                      ? Icons.star
                                      : (m.myRating ?? 0) >= i - 0.5
                                          ? Icons.star_half
                                          : Icons.star_border,
                                  color: Colors.amber,
                                ),
                                Positioned.fill(
                                  child: Row(children: [
                                    for (final half in [
                                      i.toDouble() - 0.5,
                                      i.toDouble()
                                    ])
                                      Expanded(
                                        child: Semantics(
                                          button: true,
                                          label:
                                              'Voto ${_ratingLabel(half)} su 5 stelle',
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () => state.upsert(m.clone()
                                              ..myRating = m.myRating == half
                                                  ? null
                                                  : half),
                                          ),
                                        ),
                                      ),
                                  ]),
                                ),
                              ]),
                            ),
                          if (m.myRating != null)
                            Text('${_ratingLabel(m.myRating!)}/5'),
                        ]),
                        TextField(
                          controller: _review,
                          maxLines: 4,
                          decoration: const InputDecoration(
                              hintText: 'Scrivi cosa ne pensi…'),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.tonal(
                            onPressed: () {
                              state.upsert(
                                  m.clone()..myReview = _review.text.trim());
                              _snack('Recensione salvata');
                            },
                            child: const Text('Salva recensione'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (m.tagline.isNotEmpty || m.overview.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionTitle('Trama'),
                          if (m.tagline.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text('“${m.tagline}”',
                                  style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: adaptiveTextColor(context,
                                          opacity: .7))),
                            ),
                          Text(m.overview),
                          if (m.genres.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(spacing: 6, runSpacing: 6, children: [
                              for (final g in m.genres)
                                Chip(
                                    label: Text(g),
                                    visualDensity: VisualDensity.compact),
                            ]),
                          ],
                          if (m.director != null && m.director!.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              '${m.isTv ? 'Creato da' : 'Regia'}: ${m.director}',
                              style: TextStyle(
                                  color:
                                      adaptiveTextColor(context, opacity: .7)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (m.budget != null || m.revenue != null) ...[
                    const SizedBox(height: 12),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionTitle('Botteghino'),
                          if (m.budget != null)
                            Text('Budget: ${money.format(m.budget)}'),
                          if (m.revenue != null)
                            Text(
                                'Incasso mondiale: ${money.format(m.revenue)}'),
                          if (m.budget != null && m.revenue != null)
                            Text(
                              'Utile lordo: ${money.format(m.revenue! - m.budget!)}',
                              style: TextStyle(
                                  color:
                                      adaptiveTextColor(context, opacity: .7)),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (m.cast.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionTitle('Cast'),
                          SizedBox(
                            height: 150,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: m.cast.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (_, i) {
                                final c = m.cast[i];
                                return InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                PersonPage(person: c)));
                                  },
                                  child: SizedBox(
                                    width: 84,
                                    child: Column(children: [
                                      ClipOval(
                                        child: SizedBox(
                                          width: 72,
                                          height: 72,
                                          child: c.profilePath == null
                                              ? Container(
                                                  color: Colors.white10,
                                                  child:
                                                      const Icon(Icons.person))
                                              : Poster(
                                                  path: c.profilePath,
                                                  width: 72,
                                                  height: 72,
                                                  radius: 0,
                                                  size: 'w185'),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(c.name,
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600)),
                                      Text(c.character,
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: adaptiveTextColor(context,
                                                  opacity: .54))),
                                    ]),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (m.reviews.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionTitle('Recensioni (TMDB)'),
                          for (final r in m.reviews)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${r.author}${r.rating != null ? '  •  ★ ${r.rating!.toStringAsFixed(0)}/10' : ''}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(r.content,
                                      style: TextStyle(
                                          color: adaptiveTextColor(context,
                                              opacity: .7))),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (m.notes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionTitle('Note'),
                          Text(m.notes),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Aggiunto il ${dateFmt.format(m.addedAt)}'
                    '${m.tmdbId != null ? '  •  Dati e immagini: TMDB' : ''}',
                    style: TextStyle(
                        color: adaptiveTextColor(context, opacity: .38),
                        fontSize: 11),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: adaptiveTextColor(context, opacity: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: adaptiveTextColor(context, opacity: .7)),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12)),
        ]),
      );
}
