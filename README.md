# Usage bars

An Omarchy bar widget that shows how much of your AI agent limits you have left, as two small bars per provider:

- the top bar is the 5-hour session window
- the bottom bar is the weekly window

A full bar means the whole window is still available. An empty bar means you are about to hit the limit. Each provider has its own color: Claude is orange, Codex is white, Gemini (Antigravity, `agy`) is blue.

![Usage bars in the Omarchy bar](preview.png)

## Requirements

- Omarchy Quattro with the built-in Agents plugin (`omarchy.agents`). This widget reads the usage records the Agents plugin already writes to `~/.local/state/omarchy/agents/usage/`. It makes no network requests and starts no processes of its own.
- No other dependencies.

A provider only shows up once its record has a session or weekly limit. Codex currently reports only a weekly limit, so it shows one bar.

## Install

```bash
omarchy plugin add https://github.com/T3rr0or/omarchy-usage-bars --enable
```

To put it right before the Agents icon:

```bash
omarchy bar move io.github.t3rr0or.usage-bars --before omarchy.agents
```

If the widget does not appear right away, restart the shell with `omarchy restart shell`.

## Use

- Hover: a tooltip with the remaining percentage per window, such as `Claude  5h 36% left  week 87% left`.
- Left click: opens the Agents panel.
- Middle click: asks the Agents plugin to refresh.

A provider whose limits could not be refreshed is dimmed until fresh data arrives. A window whose reset time has passed shows as full.

## Settings

Set these on the widget's entry in `~/.config/omarchy/shell.json`:

```json
{
  "id": "io.github.t3rr0or.usage-bars",
  "providers": ["claude", "codex", "agy"],
  "colors": { "codex": "#CCCCCC" },
  "barLength": 16
}
```

| Key | Default | Meaning |
| --- | --- | --- |
| `providers` | `["claude", "codex", "agy"]` | Agents plugin record ids to show, in order. Any provider the Agents plugin tracks works. |
| `colors` | `{}` | Per-provider color as `#RRGGBB` or `#RRGGBBAA`. Overrides the defaults. A provider without a color uses the bar's foreground color. |
| `barLength` | `16` | Bar length in pixels, from 8 to 23. |

On a light theme, give Codex a darker color, since white will not show.

## Remove

```bash
omarchy plugin remove io.github.t3rr0or.usage-bars
```

This removes the widget from the bar and deletes the plugin folder. Nothing else on the system is changed.

## Development

`Model.js` holds the logic that picks the windows and builds the tooltip. Its tests run with Node:

```bash
node tests/model.test.mjs
```

## License

MIT, see [LICENSE](LICENSE).
