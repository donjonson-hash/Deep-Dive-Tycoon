# Deep Dive Tycoon

Roblox-игра про океан: прокачивай кислород, ныряй глубже за редкой рыбой,
продавай её на живом рынке и выращивай рыб из яиц в аквариуме.

- Продукт и механики: [docs/PROJECT.md](docs/PROJECT.md)
- Что делаем сейчас: [docs/ROADMAP.md](docs/ROADMAP.md)

## Разработка (Linux и Windows)

Нужен [Rokit](https://github.com/rojo-rbx/rokit); он ставит остальные инструменты
версий из `rokit.toml`. На Windows ещё нужен Git (`winget install Git.Git`).

```bash
rokit install
lune run tests/run
stylua . && selene src tests
rojo build -o build/DeepDiveTycoon.rbxl
```

В PowerShell вместо `&&` используй `;`. Переносы строк зафиксированы в
`.gitattributes` (LF), `core.autocrlf` включать нельзя.

## Тест в Roblox Studio на Windows-ноутбуке (основной путь)

Studio и Rojo на одной машине, сеть не нужна.

1. В терминале в папке проекта: `rojo serve` (порт 34872).
2. В Studio: Plugins → Rojo → Connect (адрес `localhost`, порт `34872`).
3. Нажми Play. В Output должно быть `[DeepDive] Server started, map built`.

Плагин Rojo ставится из Creator Store (Rojo 7), его версия должна совпадать с
`rojo` в `rokit.toml`.

## Тест в Studio с кодом на Linux (запасной путь)

Код синхронизируется в Studio по локальной сети через Rojo.

**Один раз:**

1. Установи Roblox Studio, войди в аккаунт.
2. Создай место из шаблона **Baseplate**, удали в Explorer `Baseplate` и
   `SpawnLocation` (карту строит код). Опубликуй: File → Publish to Roblox,
   доступ — приватный.
3. Game Settings → Security → включи **Enable Studio Access to API Services**
   (нужно для сохранений).
4. Скачай плагин `Rojo.rbxm` версии **7.7.1** из
   [релиза Rojo](https://github.com/rojo-rbx/rojo/releases/tag/v7.7.1) и положи
   в папку плагинов: в Studio вкладка Plugins → Plugins Folder. Перезапусти Studio.
   Версия плагина должна совпадать с `rojo` из `rokit.toml`.

**Каждая сессия:**

1. На Linux: `rojo serve --address 0.0.0.0` (порт 34872).
2. В Studio: Plugins → Rojo → в поле адреса IP Linux-машины, порт `34872` →
   Connect. Оба компьютера должны быть в одной Wi-Fi сети.
3. Нажми Play. В Output должно быть `[DeepDive] Server started, map built`.

Если не подключается — проверь, что на Linux открыт порт 34872 в брандмауэре.

## Лицензия

MIT — см. [LICENSE](LICENSE).
