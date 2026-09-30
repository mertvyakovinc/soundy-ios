# Soundy для iPhone

Нативное приложение на SwiftUI. Сервер тот же, что у ПК и Android (`soundy.space`); YouTube для iOS
отдаётся в AAC (`?fmt=m4a`), потому что AVPlayer не играет WebM/Opus.

## Сборка
Собирается на GitHub Actions (macOS): каждый push в `main` → `Soundy.ipa` в релизе **latest**.
Подписи нет — её ставит AltStore / Sideloadly твоим обычным Apple ID.

## Установка без аккаунта разработчика (бесплатно)
1. На ПК поставь **iTunes** и **iCloud** с сайта Apple (не из Microsoft Store) и **AltServer** (altstore.io).
2. Подключи iPhone кабелем, в трее AltServer → *Install AltStore* → свой iPhone → войди своим Apple ID.
3. На iPhone: *Настройки → Основные → VPN и управление устройством* → доверься своему Apple ID;
   *Настройки → Конфиденциальность → Режим разработчика* → включить (iOS 16+).
4. Скачай `Soundy.ipa` из релиза **latest** на телефон, открой AltStore → *My Apps* → **+** → выбери файл.
5. Раз в 7 дней AltStore сам продлевает подпись, когда ПК с AltServer в той же Wi-Fi сети.

Ограничения бесплатного Apple ID: подпись на 7 дней, до 3 таких приложений.
