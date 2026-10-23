import 'package:uuid/uuid.dart';

const _uuid = Uuid();

double? _readLegacyMyRating(Map<String, dynamic> json) {
  final rating = (json['myRating'] as num?)?.toDouble();
  return rating == null ? null : rating / 2;
}

class CastMember {
  final int? id;
  final String name;
  final String character;
  final String? profilePath;
  CastMember(
      {this.id, required this.name, this.character = '', this.profilePath});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'character': character,
        'profilePath': profilePath
      };

  factory CastMember.fromJson(Map<String, dynamic> j) => CastMember(
        id: (j['id'] as num?)?.toInt(),
        name: (j['name'] ?? '').toString(),
        character: (j['character'] ?? '').toString(),
        profilePath: j['profilePath'] as String?,
      );
}

class PersonCredit {
  final int id;
  final String type;
  final String title;
  final String? date;
  final String? posterPath;
  final String role;
  final double? voteAverage;

  const PersonCredit({
    required this.id,
    required this.type,
    required this.title,
    this.date,
    this.posterPath,
    this.role = '',
    this.voteAverage,
  });
}

class PersonDetails {
  final int id;
  final String name;
  final String biography;
  final String? birthday;
  final String? deathday;
  final String? placeOfBirth;
  final String? profilePath;
  final String knownForDepartment;
  final List<PersonCredit> credits;

  const PersonDetails({
    required this.id,
    required this.name,
    this.biography = '',
    this.birthday,
    this.deathday,
    this.placeOfBirth,
    this.profilePath,
    this.knownForDepartment = '',
    this.credits = const [],
  });
}

class TmdbReview {
  final String author;
  final String content;
  final double? rating;
  TmdbReview({required this.author, required this.content, this.rating});

  Map<String, dynamic> toJson() =>
      {'author': author, 'content': content, 'rating': rating};

  factory TmdbReview.fromJson(Map<String, dynamic> j) => TmdbReview(
        author: (j['author'] ?? '').toString(),
        content: (j['content'] ?? '').toString(),
        rating: (j['rating'] as num?)?.toDouble(),
      );
}

/// Prestito ("Trade"): a chi, da quando, fino a quando.
class LoanInfo {
  String borrower;
  DateTime since;
  DateTime? dueDate;
  String notes;
  LoanInfo({
    required this.borrower,
    required this.since,
    this.dueDate,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'borrower': borrower,
        'since': since.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'notes': notes,
      };

  factory LoanInfo.fromJson(Map<String, dynamic> j) => LoanInfo(
        borrower: (j['borrower'] ?? '').toString(),
        since:
            DateTime.tryParse((j['since'] ?? '').toString()) ?? DateTime.now(),
        dueDate: DateTime.tryParse((j['dueDate'] ?? '').toString()),
        notes: (j['notes'] ?? '').toString(),
      );
}

class MediaItem {
  String id;
  int? tmdbId;
  String type; // 'movie' | 'tv'
  String title;
  String originalTitle;
  int? year;
  String overview;
  String tagline;
  String? posterPath;
  String? localPosterPath;
  String? backdropPath;
  List<String> genres;
  int? runtime;
  double? voteAverage;
  int? budget;
  int? revenue;
  int? seasons;
  String? director;
  List<CastMember> cast;
  List<TmdbReview> reviews;

  // Dati della tua copia fisica
  String format;
  String region;
  String mediaLanguage;
  double? price;
  String barcode;
  bool archived;
  bool lostMedia;
  bool watched;
  String notes;

  // Tuoi giudizi
  double? myRating; // 0-5, step 0.5
  double? qualityRating; // qualità del supporto, 0-5, step 0.5
  String myReview;

  // Prestito
  LoanInfo? loan;

  DateTime addedAt;

  MediaItem({
    String? id,
    this.tmdbId,
    this.type = 'movie',
    this.title = '',
    this.originalTitle = '',
    this.year,
    this.overview = '',
    this.tagline = '',
    this.posterPath,
    this.localPosterPath,
    this.backdropPath,
    List<String>? genres,
    this.runtime,
    this.voteAverage,
    this.budget,
    this.revenue,
    this.seasons,
    this.director,
    List<CastMember>? cast,
    List<TmdbReview>? reviews,
    this.format = 'Non Specificato',
    this.region = '',
    this.mediaLanguage = '',
    this.price,
    this.barcode = '',
    this.archived = false,
    this.lostMedia = false,
    this.watched = false,
    this.notes = '',
    this.myRating,
    this.qualityRating,
    this.myReview = '',
    this.loan,
    DateTime? addedAt,
  })  : id = id ?? _uuid.v4(),
        genres = genres ?? [],
        cast = cast ?? [],
        reviews = reviews ?? [],
        addedAt = addedAt ?? DateTime.now();

  bool get isTv => type == 'tv';

  Map<String, dynamic> toJson() => {
        'id': id,
        'tmdbId': tmdbId,
        'type': type,
        'title': title,
        'originalTitle': originalTitle,
        'year': year,
        'overview': overview,
        'tagline': tagline,
        'posterPath': posterPath,
        'localPosterPath': localPosterPath,
        'backdropPath': backdropPath,
        'genres': genres,
        'runtime': runtime,
        'voteAverage': voteAverage,
        'budget': budget,
        'revenue': revenue,
        'seasons': seasons,
        'director': director,
        'cast': cast.map((e) => e.toJson()).toList(),
        'reviews': reviews.map((e) => e.toJson()).toList(),
        'format': format,
        'region': region,
        'mediaLanguage': mediaLanguage,
        'price': price,
        'barcode': barcode,
        'archived': archived,
        'lostMedia': lostMedia,
        'watched': watched,
        'notes': notes,
        // Mantiene compatibilità con le versioni precedenti (scala 0-10).
        'myRating': myRating == null ? null : myRating! * 2,
        'myRating5': myRating,
        'qualityRating': qualityRating,
        'myReview': myReview,
        'loan': loan?.toJson(),
        'addedAt': addedAt.toIso8601String(),
      };

  factory MediaItem.fromJson(Map<String, dynamic> j) => MediaItem(
        id: j['id'] as String?,
        tmdbId: (j['tmdbId'] as num?)?.toInt(),
        type: (j['type'] ?? 'movie').toString(),
        title: (j['title'] ?? '').toString(),
        originalTitle: (j['originalTitle'] ?? '').toString(),
        year: (j['year'] as num?)?.toInt(),
        overview: (j['overview'] ?? '').toString(),
        tagline: (j['tagline'] ?? '').toString(),
        posterPath: j['posterPath'] as String?,
        localPosterPath: j['localPosterPath'] as String?,
        backdropPath: j['backdropPath'] as String?,
        genres: ((j['genres'] ?? []) as List).map((e) => e.toString()).toList(),
        runtime: (j['runtime'] as num?)?.toInt(),
        voteAverage: (j['voteAverage'] as num?)?.toDouble(),
        budget: (j['budget'] as num?)?.toInt(),
        revenue: (j['revenue'] as num?)?.toInt(),
        seasons: (j['seasons'] as num?)?.toInt(),
        director: j['director'] as String?,
        cast: ((j['cast'] ?? []) as List)
            .map((e) => CastMember.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        reviews: ((j['reviews'] ?? []) as List)
            .map((e) => TmdbReview.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        format: (j['format'] ?? 'Non Specificato').toString(),
        region: (j['region'] ?? '').toString(),
        mediaLanguage: (j['mediaLanguage'] ?? '').toString(),
        price: (j['price'] as num?)?.toDouble(),
        barcode: (j['barcode'] ?? '').toString(),
        archived: j['archived'] == true,
        lostMedia: j['lostMedia'] == true,
        watched: j['watched'] == true,
        notes: (j['notes'] ?? '').toString(),
        myRating: j.containsKey('myRating5')
            ? (j['myRating5'] as num?)?.toDouble()
            : _readLegacyMyRating(j),
        qualityRating: (j['qualityRating'] as num?)?.toDouble(),
        myReview: (j['myReview'] ?? '').toString(),
        loan: j['loan'] == null
            ? null
            : LoanInfo.fromJson(Map<String, dynamic>.from(j['loan'])),
        addedAt: DateTime.tryParse((j['addedAt'] ?? '').toString()),
      );

  MediaItem clone() => MediaItem.fromJson(toJson());
}

class TmdbResult {
  final int id;
  final String type;
  final String title;
  final String originalTitle;
  final int? year;
  final String? posterPath;
  final String overview;
  TmdbResult({
    required this.id,
    required this.type,
    required this.title,
    this.originalTitle = '',
    this.year,
    this.posterPath,
    this.overview = '',
  });
}
