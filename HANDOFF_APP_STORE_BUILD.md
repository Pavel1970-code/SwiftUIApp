# Передача сборки в App Store — для второго Mac (Xcode 16+)

Эта инструкция для **человека, у которого есть Mac с macOS Sonoma 14.5+ или новее** и **Xcode 16+** (в комплекте **iOS 18 SDK**). На старых Mac (например, MacBook 12" 2017 с Ventura) Xcode 16 **официально не ставится** — архив для загрузки в App Store Connect нужно собрать **на такой машине**.

Общая картина: **разработчик** готовит код и пушит в Git; **собиратель** клонирует репозиторий, открывает проект, подписывает **своей** или **общей** командой Apple Developer, делает **Archive** и загружает в **App Store Connect**.

---

## Часть A. Что заранее согласовать

### 1. Доступ к коду

- Репозиторий: [https://github.com/Pavel1970-code/SwiftUIApp](https://github.com/Pavel1970-code/SwiftUIApp) (или актуальный URL / приватный репозиторий с приглашением).
- Собиратель делает `git clone` и перед сборкой — `git pull` на нужную ветку (обычно `main`).

### 2. Apple Developer и подпись

Возможны два сценария.

**Вариант 1 — одна команда (заказчик / компания)**  
- В **App Store Connect** и на [developer.apple.com](https://developer.apple.com) уже создано приложение с **Bundle ID**, совпадающим с Xcode (**сейчас в проекте: `toprete.com.kindeks`**).  
- Собиратель добавляет свой Apple ID в **Users and Access** в App Store Connect (роль **Developer** или выше — по политике компании).  
- В **Xcode → Settings → Accounts** собиратель входит под **тем же Apple ID**, который входит в **Team** с активной подпиской **Apple Developer Program**.  
- В таргете **SwiftUI App → Signing & Capabilities**: **Team** = эта команда, **Automatically manage signing** включено.  
- Если Xcode ругается на Bundle ID — в **Identifiers** на developer.apple.com должен быть App ID **`toprete.com.kindeks`**, либо в проекте временно меняют ID на зарегистрированный (тогда же нужно создать приложение в Connect с тем же ID).

**Вариант 2 — сборка под вашу личную команду**  
- У собирателя своя платная программа Developer; тогда **Bundle ID** в Xcode должен быть **уникальным** в его аккаунте (не пересекаться с чужими), и в **App Store Connect** создаётся **новое** приложение с этим ID.  
- Имеет смысл только если вы **переносите** приложение на аккаунт заказчика позже; для одного релиза проще вариант 1.

### 3. Секреты и пароли

- **Не** пересылайте пароль Apple ID в мессенджере. Лучше: собиратель сам входит в Xcode и Connect под **своим** приглашённым аккаунтом, или используется **общий** корпоративный процесс (1Password, менеджер секретов).  
- **Не** коммитьте в Git сертификаты `.p12`, пароли, ключи API.

---

## Часть B. Подготовка машины собирателя

1. **macOS**: Sonoma **14.5+** или Sequoia (или новее по [таблице Xcode](https://developer.apple.com/support/xcode/)).  
2. **Xcode 16+**: App Store или [developer.apple.com/download](https://developer.apple.com/download/all/). После установки открыть Xcode один раз, принять лицензию, дождаться установки компонентов.  
3. **Git**: `xcode-select --install` при необходимости; либо Xcode Command Line Tools.  
4. **Место на диске**: желательно **40+ ГБ** свободно под Xcode и DerivedData.

---

## Часть C. Клонирование и открытие проекта

```bash
git clone https://github.com/Pavel1970-code/SwiftUIApp.git
cd SwiftUIApp
git checkout main
git pull
```

Открыть **`SwiftUI App.xcodeproj`** (двойной клик или **File → Open** в Xcode).

Дождаться разрешения зависимостей (если Xcode предложит — **Resolve Package Versions**).

---

## Часть D. Подпись в Xcode

1. В навигаторе выбрать проект **SwiftUI App** → таргет **SwiftUI App**.  
2. **Signing & Capabilities**:  
   - **Team** — команда с **Apple Developer Program**.  
   - **Automatically manage signing** — включено.  
   - **Bundle Identifier** — `toprete.com.kindeks` (или согласованный с Connect).  
3. Если ошибка «нет устройств» / профиля — на аккаунте Developer в **Devices** должна быть зарегистрирована хотя бы одна реальная приставка (UDID); см. [CLIENT_SETUP.md](./CLIENT_SETUP.md).  
4. **General**: проверить **Version** (например `1.0`) и **Build** — **каждая новая загрузка в Connect должна иметь Build больше предыдущей** (1 → 2 → 3 …).

---

## Часть E. Иконки и настройки приложения

- **Assets → AppIcon**: все слоты для **iPhone** заполнены; таргет в проекте — **только iPhone** (`TARGETED_DEVICE_FAMILY = 1`), отдельные иконки для iPad не требуются.  
- При ошибке про **alpha** у иконки 1024×1024 — экспорт без прозрачности из дизайна и замена в ассетах.

---

## Часть F. Архив и загрузка

1. Вверху Xcode выбрать **Any iOS Device (arm64)** или **Generic iOS Device** (не симулятор).  
2. **Product → Clean Build Folder** (по желанию, при странных ошибках — с зажатым Option).  
3. **Product → Archive**.  
4. Откроется **Organizer** → выбрать архив → **Distribute App** → **App Store Connect** → **Upload** → пройти шаги мастера.  
5. Дождаться успешной загрузки; в [App Store Connect](https://appstoreconnect.apple.com) → приложение → **TestFlight** — сборка в статусе **Processing**, затем готова к тестам.

Подробнее про метаданные магазина и внешний TestFlight: [TESTFLIGHT_APPSTORE.md](./TESTFLIGHT_APPSTORE.md).

---

## Часть G. Что передать собирателю «пакетом»

Чеклист для разработчика:

| Передать / указать | Зачем |
|--------------------|--------|
| Ссылка на репо + ветка | Клон и актуальный код |
| Bundle ID | Совпадение с Connect и Identifiers |
| Какая **Team** в Apple Developer | Выбор Team в Xcode |
| Текущие **Version** / **Build** | Не уменьшать Build при повторной загрузке |
| Есть ли уже приложение в App Store Connect | Имя записи, SKU, язык |
| Нужен ли только TestFlight или сразу ревью App Store | Заполнение вкладки App Store |

---

## Часть H. Облачный Mac (кратко)

Если второго физического Mac нет:

1. Аренда **Mac в облаке** (провайдеры с легальным **dedicated Mac** по часам/месяцам).  
2. На нём — **тот же сценарий**: Xcode 16+, clone, Signing с **экспортом сертификатов** или входом Apple ID (политика безопасности у компании).  
3. Сложнее всего обычно **перенос signing**: проще, если на облаке входят под **тем же** Apple ID, что уже в Team (не всегда допустимо по ИБ).

Для MVP чаще дешевле попросить **заказчика** или **коллегу с M1/M2 Mac** выполнить **части C–F** один раз.

---

## См. также

- [CLIENT_SETUP.md](./CLIENT_SETUP.md) — локальный запуск на симуляторе и телефоне.  
- [TESTFLIGHT_APPSTORE.md](./TESTFLIGHT_APPSTORE.md) — Connect, TestFlight, публикация.
