import 'package:flutter/material.dart' hide Text;
import '../localization.dart' show Text;
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import 'glass.dart';

class PersonPage extends StatefulWidget {
  final CastMember person;
  const PersonPage({super.key, required this.person});

  @override
  State<PersonPage> createState() => _PersonPageState();
}

class _PersonPageState extends State<PersonPage> {
  late Future<PersonDetails> _details;

  @override
  void initState() {
    super.initState();
    _details = _load();
  }

  Future<PersonDetails> _load() async {
    final tmdb = context.read<AppState>().tmdb;
    if (tmdb == null) {
      throw StateError('Per aprire la scheda del membro del cast serve TMDB.');
    }
    final id =
        widget.person.id ?? await tmdb.searchPersonId(widget.person.name);
    if (id == null) throw StateError('Persona non trovata su TMDB.');
    return tmdb.personDetails(id);
  }

  int? _age(PersonDetails person) {
    final birth = DateTime.tryParse(person.birthday ?? '');
    if (birth == null) return null;
    final end = DateTime.tryParse(person.deathday ?? '') ?? DateTime.now();
    var age = end.year - birth.year;
    if (end.month < birth.month ||
        (end.month == birth.month && end.day < birth.day)) {
      age--;
    }
    return age >= 0 ? age : null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.person.name)),
        body: FutureBuilder<PersonDetails>(
          future: _details,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.person_off_outlined, size: 42),
                    const SizedBox(height: 12),
                    Text(snapshot.error.toString(),
                        localize: false,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () => setState(() => _details = _load()),
                      child: const Text('Riprova'),
                    ),
                  ]),
                ),
              );
            }
            final person = snapshot.data!;
            final movies =
                person.credits.where((e) => e.type == 'movie').length;
            final shows = person.credits.where((e) => e.type == 'tv').length;
            final age = _age(person);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                GlassCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          width: 128,
                          height: 184,
                          child: Poster(
                            path: person.profilePath,
                            width: 128,
                            height: 184,
                            radius: 0,
                            size: 'w342',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(person.name,
                                localize: false,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                            if (person.knownForDepartment.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(person.knownForDepartment,
                                    localize: false,
                                    style: TextStyle(
                                        color: adaptiveTextColor(context,
                                            opacity: .7))),
                              ),
                            if (person.birthday != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  'Nato/a il ${person.birthday!}'
                                  '${age == null ? '' : ' · $age anni'}',
                                ),
                              ),
                            if (person.deathday != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text('Deceduto/a il ${person.deathday}'),
                              ),
                            if (person.placeOfBirth?.isNotEmpty == true)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(person.placeOfBirth!,
                                    localize: false),
                              ),
                            const SizedBox(height: 12),
                            Text('$movies film · $shows serie TV',
                                style: TextStyle(
                                    color:
                                        adaptiveTextColor(context, opacity: .7),
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (person.biography.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle('Biografia'),
                        SelectableText(person.biography),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionTitle('Filmografia (${person.credits.length})'),
                      if (person.credits.isEmpty)
                        const Text('Nessuna opera trovata su TMDB.'),
                      for (final credit in person.credits)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Poster(
                            path: credit.posterPath,
                            width: 44,
                            height: 66,
                            radius: 5,
                            size: 'w154',
                          ),
                          title: Text(credit.title, localize: false),
                          subtitle: Text([
                            if (credit.date?.isNotEmpty == true)
                              credit.date!.length >= 4
                                  ? credit.date!.substring(0, 4)
                                  : credit.date!,
                            credit.type == 'movie' ? 'Film' : 'Serie TV',
                            if (credit.role.isNotEmpty) credit.role,
                          ].join(' · ')),
                          trailing: credit.voteAverage == null ||
                                  credit.voteAverage == 0
                              ? null
                              : Text(
                                  '★ ${credit.voteAverage!.toStringAsFixed(1)}'),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text(
                    'Dati biografici e filmografia forniti da TMDB.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: adaptiveTextColor(context, opacity: .38),
                        fontSize: 11),
                  ),
                ),
              ],
            );
          },
        ),
      );
}
