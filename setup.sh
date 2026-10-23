#!/usr/bin/env bash
# Genera le cartelle di piattaforma (android, ios, windows, linux, macos, web)
# senza toccare il codice in lib/ e scarica le dipendenze.
set -e
flutter create . --project-name media_archive --org com.mediaarchive \
  --platforms=android,ios,windows,linux,macos,web
rm -f test/widget_test.dart
flutter pub get
echo
echo "Fatto. Ora leggi README.md per permessi fotocamera e avvio."
