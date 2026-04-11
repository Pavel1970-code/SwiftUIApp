# Экспорт проекта на другой Mac (сборка Xcode 16+ / App Store)

Кратко: **лучше не слать «папку с рабочего стола»**, а передать **Git-репозиторий** или **ZIP из `git archive`** — так на другой машине не уезжают кэши, `DerivedData` и случайные дубликаты файлов.

---

## Вариант 1 — предпочтительно: Git

1. Закоммитьте и запушьте все нужные изменения в **GitHub** (ветка `main` или релизная ветка).
2. На другом Mac:
   ```bash
   git clone https://github.com/Pavel1970-code/SwiftUIApp.git
   cd SwiftUIApp
   ```
3. Откройте **`SwiftUI App.xcodeproj`**, дождитесь **Resolve Package Versions** (пакет `swift-algorithms`).
4. Дальше — подпись и **Archive** по [HANDOFF_APP_STORE_BUILD.md](./HANDOFF_APP_STORE_BUILD.md).

---

## Вариант 2: один ZIP без мусора (`git archive`)

На **вашем** Mac, в **корне репозитория**:

```bash
chmod +x scripts/make-export-archive.sh
./scripts/make-export-archive.sh
```

Скрипт создаст архив во временной папке (путь выведет в консоль). Внутри будет каталог **`SwiftUIApp/`** с тем же содержимым, что в **последнем коммите** — **без** неотслеживаемых файлов.

**Важно:** всё, что вы не закоммитили, **не попадёт** в архив. Сначала `git add` + `git commit`.

Альтернатива одной командой:

```bash
git archive --format=zip --prefix=SwiftUIApp/ -o ~/Desktop/SwiftUIApp-export.zip HEAD
```

---

## Что не нужно переносить (и не попадёт в `git archive`)

| Папка / файл | Зачем исключать |
|----------------|-----------------|
| `.DerivedData/`, `.build_sim/`, `DerivedData/` | Кэш сборки, гигабайты |
| `xcuserdata/` | Личные настройки Xcode окон |
| `GoogleService-Info (1).plist` | Дубликат, не в Git |
| `BLEGiftSessionManager.swift` в корне `SwiftUI App/` | Дубликат BLE (логика в `Models.swift`), в `.gitignore` |

Сертификаты и профили подписи **не** кладите в ZIP — на другом Mac используют **свой** Apple ID / Team в **Signing & Capabilities**.

---

## Что должен сделать получатель на своём Mac

1. **macOS Sonoma 14.5+** (или новее), **Xcode 16+**.
2. Распаковать ZIP **или** `git clone`.
3. Открыть **`SwiftUI App.xcodeproj`**.
4. **File → Packages → Resolve Package Versions** (при необходимости).
5. **Signing & Capabilities** — своя **Team**, **Automatically manage signing**, Bundle ID **`toprete.com.kindeks`** (или согласованный с App Store Connect).
6. **Product → Archive** → загрузка в App Store Connect.

Полный чеклист: [HANDOFF_APP_STORE_BUILD.md](./HANDOFF_APP_STORE_BUILD.md).

---

## См. также

- [CLIENT_SETUP.md](./CLIENT_SETUP.md) — первый запуск проекта локально.
- [TESTFLIGHT_APPSTORE.md](./TESTFLIGHT_APPSTORE.md) — метаданные и TestFlight.
