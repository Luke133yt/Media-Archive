@echo off
REM Genera le cartelle di piattaforma senza toccare lib/ e scarica le dipendenze.
call flutter create . --project-name media_archive --org com.mediaarchive --platforms=android,ios,windows,linux,macos,web
if exist test\widget_test.dart del test\widget_test.dart
call flutter pub get
echo.
echo Fatto. Ora leggi README.md per permessi fotocamera e avvio.
