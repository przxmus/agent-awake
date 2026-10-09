# agent-awake

Mac nie zasypia (także z zamkniętą klapą), dopóki **którykolwiek** agent AI pracuje.
Gdy skończą wszystkie, uśpienie wraca.

## Jak to działa

- Każda pracująca sesja trzyma plik blokady w `~/.agent-awake/locks/`.
- Jest co najmniej jedna blokada → `pmset disablesleep 1`. Zero blokad → `pmset disablesleep 0`.
- Hooki zakładają i zdejmują blokady automatycznie:

| Narzędzie | Blokada (heartbeat) | Zwolnienie |
|---|---|---|
| Claude Code (CLI i zakładka Code w Claude Desktop) | `UserPromptSubmit`, `PreToolUse` | `Stop`, `SessionEnd` |
| Codex (CLI i aplikacja) | `UserPromptSubmit`, `PreToolUse` | `Stop`, `Interrupt`, `SessionEnd` |

- launchd co minutę uruchamia `awake sweep`, który usuwa blokady:
  - procesów agenta, które już nie żyją (crash, zamknięte okno),
  - bez heartbeatu od `AWAKE_TTL_MIN` minut (domyślnie 45).

## Instalacja

```bash
./install.sh
```

Instalator jest idempotentny. Robi symlink `~/.local/bin/awake`, wpis sudoers dla
`pmset disablesleep` bez hasła (jeśli go jeszcze nie ma), usługę launchd i hooki
w `~/.claude/settings.json` oraz `~/.codex/hooks.json`.

Potem:
- uruchom ponownie otwarte sesje Claude Code i Codexa,
- w Codex CLI wpisz raz `/hooks` i zatwierdź nowe hooki (bez tego Codex ich nie uruchomi).

Odinstalowanie: `./uninstall.sh` (wpis sudoers zostaje).

## Użycie ręczne

```bash
awake status      # stan uśpienia i lista blokad
awake on          # ręczna blokada "manual", sweep jej nie usuwa
awake off         # zdjęcie ręcznej blokady
awake reset       # usuń wszystkie blokady i włącz uśpienie
```

Nie ustawiaj `sudo pmset disablesleep 1` ręcznie: sweep po minucie przywróci uśpienie,
jeśli nie ma blokad. Użyj zamiast tego `awake on`.

Log: `~/.agent-awake/awake.log`. Własne TTL: `echo AWAKE_TTL_MIN=90 > ~/.agent-awake/config`.

## Ograniczenia

- **Claude Desktop (zwykły czat)** nie ma hooków ani shella, więc nie jest objęty.
- **Przerwanie Esc w Claude Code** może nie wywołać `Stop`. Blokada zostaje wtedy do
  zamknięcia sesji albo do wygaśnięcia TTL.
- **Jedno polecenie dłuższe niż TTL** (np. build trwający godzinę, bez innych wywołań
  narzędzi) traci blokadę. Jeśli tak pracujesz, zwiększ `AWAKE_TTL_MIN`.
- **Zadania w tle po `Stop`**: gdy agent skończy turę, a w tle coś jeszcze działa,
  blokada jest zdejmowana. Wraca, gdy agent znów zacznie używać narzędzi.
