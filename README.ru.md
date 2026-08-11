<div align="center">

# ddlc-rofi-theme

**Тема rofi в цветах Doki Doki Literature Club, светлая и тёмная** （´ω｀♡%）

![rofi](https://img.shields.io/badge/rofi-theme-F4A100?style=flat)
![Nix](https://img.shields.io/badge/Nix-flake-7EBAE4?style=flat&logo=nixos&logoColor=white)
[![palette](https://img.shields.io/badge/colours-ddlc--palette-FF80C0?style=flat)](https://github.com/rokokol/ddlc-palette)
[![license](https://img.shields.io/badge/MIT-3DA639?style=flat)](LICENSE)
[![build](https://github.com/rokokol/ddlc-rofi-theme/actions/workflows/build.yml/badge.svg)](https://github.com/rokokol/ddlc-rofi-theme/actions/workflows/build.yml)

[English](README.md)

</div>

Скруглённые полупрозрачные строки на клубной бумаге в горошек, в светлом и тёмном варианте, и переключалка между ними одним словом

Все цвета — измеренные, из [ddlc-palette](https://github.com/rokokol/ddlc-palette), которая читает их с [ddlc.moe](https://ddlc.moe). Ничего не подобрано на глаз. У обоих вариантов одна вёрстка, различаются они только тем, какими ключами палитры она заполнена

Приехало из моего райса, **[rokokol/huix](https://github.com/rokokol/huix)**

```sh
# отрендерить и посмотреть на файлы, ничего не устанавливая
nix build github:rokokol/ddlc-rofi-theme && cat result/share/rofi/themes/ddlc-dark.rasi
```

![Светлый вариант](docs/screenshot-light.png)
![Тёмный вариант](docs/screenshot-dark.png)

## Установка

### Home Manager

```nix
{
  inputs.ddlc-rofi-theme.url = "github:rokokol/ddlc-rofi-theme";

  # в home-конфигурации
  imports = [ inputs.ddlc-rofi-theme.homeManagerModules.default ];

  ddlc.rofi.enable = true;
}
```

Это раскладывает оба варианта, называет тему в конфиге rofi и один раз выбирает вариант — ровно один, потому что дальше выбор рантаймовый:

| опция | | по умолчанию |
| --- | --- | --- |
| `name` | как называется тема; `<name>.rasi` — то, что резолвит rofi | `ddlc` |
| `default` | вариант, который ставит первая активация | `light` |
| `width` | ширина окна, в любых единицах rofi | `720px` |
| `font` | шрифт окна | `programs.rofi.font` |
| `promptFont` | шрифт одного только промпта, а он обычно эмодзи | `font` |
| `monoFont` | шрифт строк и сообщений | `monospace 12` |
| `placeholder` | что написано в пустой строке поиска | `Okay, everyone!` |

### Любой другой дистрибутив

```sh
git clone https://github.com/rokokol/ddlc-rofi-theme
cd ddlc-rofi-theme
sudo ./install.sh          # PREFIX=~/.local ./install.sh для пользовательской установки
```

Ничего не собирается: [`dist/`](dist) — отрендеренная тема, она закоммичена, так что это копирование в каталог, куда rofi и так смотрит. Дальше назвать её в `~/.config/rofi/config.rasi` и выбрать вариант:

```conf
rofi.theme: ddlc
```

```sh
ddlc-rofi-theme light
```

### Шрифтов здесь нет

На скриншотах — **Doki**, фанатский шрифт DDLC, а строки набраны [DepartureMono](https://departuremono.com). Ни того, ни другого в комплекте нет: тема не должна ставить шрифты. Из коробки берутся `sans-serif` и `monospace`, а `font` и `monoFont` наводятся на то, что есть у вас

## Переключалка

`ddlc-rofi-theme light | dark | toggle | status` — один симлинк, `~/.config/rofi/themes/<name>.rasi`, наведённый на один из двух вариантов. rofi читает тему на каждом запуске, так что перезагружать нечего: следующее окно уже в другом варианте. Поэтому это команда, а не демон

Прицепить её можно к чему угодно, что и так знает про светлое и тёмное, — к переключателю темы GTK, к таймеру рассвета, к клавише:

```conf
bind = SUPER, A, exec, ddlc-rofi-theme toggle
```

Где она ищет варианты, по порядку: рядом с симлинком, потом `DDLC_ROFI_THEME_DIR`, потом `share/rofi/themes` собственной установки. Рядом с симлинком — первым не просто так: под Nix упакованный вариант это стор-путь, симлинк в стор повисает после ближайшей сборки мусора, поэтому модуль Home Manager кладёт копии в `~/.config`, а переключалка предпочитает их

| | |
| --- | --- |
| `DDLC_ROFI_THEME_NAME` | имя темы, по умолчанию `ddlc` |
| `DDLC_ROFI_THEME_DIR` | где лежат варианты, если они не рядом с симлинком |

## Как rofi её находит

Два поиска, оба собственные rofi, и ни одному не нужен путь:

- `rofi.theme: ddlc` резолвится в том числе в `${XDG_CONFIG_HOME}/rofi/themes/` — там симлинк и лежит
- `background-image: url("ddlc-polka-light.svg")` ищется **в том же плоском каталоге**, а не рядом с темой, которая его назвала. Поэтому оба фона обязаны лежать рядом с вариантами и носят имя темы, чтобы не мешать чужой

## Тесты

```sh
tests/run.sh   # переключалка, на выброшенном дереве конфига
```

`nix flake check` прогоняет это плюс: `dist/` совпадает с тем, что сгенерировал бы пакет; оба варианта парсятся (`rofi -dump-theme` работает без дисплея, а поскольку rofi выходит с нулём даже на непонятой теме, критерий — предупреждение); модуль Home Manager вычисляется против заглушек опций

## Структура

```
nix/theme.nix        вёрстка и два набора цветов, одной чистой функцией
nix/                 package.nix, module.nix, module-test.nix
ddlc-rofi-theme.sh   переключалка light/dark
dist/                отрендеренная тема, закоммичена для тех, у кого нет Nix
tests/run.sh         набор проверок переключалки
install.sh           для систем без Nix
```

## Лицензия

MIT. Цвета — Team Salvato
