# Custom Skirmish Trails: data structure and localization (answer to 4.8)

Status of the module this refers to: 1.3.7. Nothing described under "Proposal" is built yet.

## Short answer

1. **One internal model, several views.** Internally the module already turns every csv line
   into one flat table of keys (`map_name`, `player2`, `text_description_line_01`, ...). Keep that
   flat key set as the single definition of what a mission is. CSV columns are those keys 1:1; a
   mission JSON file is a *nested view* of the same keys, translated by one fixed mapping table.
   Then every new feature is "one new key", and CSV and JSON get it at the same time without
   anyone maintaining two code paths.
2. **Restructure the mission JSON files, yes** (players as nested objects), because the mapping
   above makes it cheap and lossless. Keep the CSV flat: it is the overview table and what
   existing trails use.
3. **Let the game read the mission JSON files directly**, as an equal input next to the CSV, not
   with CSV as a "legacy" format. Both feed the same internal model, so there is nothing that one
   could do and the other could not.
4. **Localization: one language-independent data set per trail, plus one text file per language
   whose keys are derived automatically** (mission number + column name). No hand-made keys, no
   redundant language CSVs, texts in the CSV still work as the default. Details below.

## Why not keep things as they are

What is error-prone today is not the CSV format but the duplication: every language CSV repeats
all gameplay columns. The 1.3.7 strict-mode comparison (4.5.3) can *detect* drift between them,
but it cannot prevent it. The fix is to have the gameplay data exist exactly once.

## 1. Restructuring the mission JSON files

Proposed shape of `<trail>_mission_NN.json` (version 2):

```json
{
  "format": 2,
  "map_name": "Reconquista_Trail_1",
  "fairness": 4,
  "start_levels": 2,
  "mission_name": "The Coast",
  "text_description": ["line 1", "line 2", "", "", "", "", "", ""],
  "players": [
    { "ai": "human", "name": "", "lord": "Arab", "skip_start_units": 0,
      "start_position": 1, "team": 1, "gold": 2000 },
    { "ai": "Alfonso", "name": "Alfonso of Castile", "start_position": 2, "team": 2,
      "aiv_type": 3, "gold": 1000 }
  ],
  "producible": { "bows": 1, "crossbows": 0 },
  "recruitable": { "archers": 1, "knights": 0 },
  "resources": { "wood": 100, "stone": 50 },
  "tradeable": { "wood": 1, "iron": 0 }
}
```

- `num_players` disappears: it is the length of `players`.
- `players[0]` is player 1. Empty slots are simply not listed.
- Prefix groups (`producible_*`, `recruitable_*`, `resource_*`, `tradeable_*`) become objects.

**The mapping is a table, not code.** Each CSV column maps to one JSON path:

| CSV column | JSON path |
| --- | --- |
| `player3` | `players[2].ai` |
| `player3_name` | `players[2].name` |
| `start_position3` | `players[2].start_position` |
| `team3` | `players[2].team` |
| `aiv_type3` | `players[2].aiv_type` |
| `gold_player_3` | `players[2].gold` |
| `player1_lord` | `players[0].lord` |
| `resource_wood` | `resources.wood` |
| `text_description_line_04` | `text_description[3]` |

Export walks the CSV columns and writes each value at its path; Import walks the paths and
fills the columns. Unknown columns (columns a newer or a modded version added) go to a flat
`"extra": { "column": "value" }` object so nothing is ever lost. With that, the only edge
cases are the ones the table names, and Export followed by Import stays byte-identical, as it
is today. The `"format": 2` key lets Import still read today's flat files.

**Cost:** one mapping table, one Export/Import change, the schema file, and a migration that
is just "Import with format 1, Export with format 2". Moderate, and it pays off with every
feature added later.

## 2. JSON as an input the game reads

Recommendation: **support both fully**, through the internal model.

- Trail settings file gets `"trail_mission_files": "missions/"` (a folder) as an alternative to
  `trail_csv_files`. The game reads the folder's mission files instead of a CSV.
- Both readers produce the same flat key table, so all existing code (`commitEntry`, start
  goods, names, lord, ...) stays as it is.
- CSV stays the quickest way to see and edit all missions at once (spreadsheet), and older
  trails keep working unchanged. Export/Import remain the bridge between the two.

Calling CSV "legacy, may lack new features" would only save work if a feature could not be
expressed as a column. With the flat key model every feature is a column, so there is no saving
and only a loss for the people who prefer the table.

Where JSON is genuinely better (lists of unknown length, per-player objects, comments via
`"_note"` keys), the nested JSON view already gives that to anyone who wants it.

## 3. Centralizing localization

### Options

| Option | For | Against |
| --- | --- | --- |
| A. Language CSVs (today) | Nothing new to learn | Gameplay data duplicated per language; drift |
| B. Nested per-language values in the JSON (`"mission_name": { "default": ..., "german": ... }`) | Texts stay next to their mission | Not possible in a CSV; mission files grow with every language; translators must touch gameplay files |
| C. Classic key-value language files, keys written into the data (`"mission_name": "@m01_name"`) | Standard approach, translator-friendly | Someone has to invent and maintain keys; data files become unreadable without the language file |
| **D. Language files with automatic keys** | No duplication, no hand-made keys, CSV/JSON stay readable, backwards compatible | One more file type |

### Recommended: option D

- The CSV / mission JSON files hold **one** set of texts: the default language. They read
  exactly as today, and old trails are unchanged.
- Each further language is one file, `texts/<language>.json`, keyed by *mission number and
  column name*, which already identify every text uniquely:

```json
{
  "trail_title": "Die Reconquista",
  "trail_summary": "Einundzwanzig Schlachten im Süden ...",
  "missions": {
    "1": {
      "mission_name": "Die Küste",
      "text_description_line_01": "...",
      "player2_name": "Alfons von Kastilien"
    },
    "2": { "mission_name": "..." }
  }
}
```

- At game start: load the data once, then overlay the texts of the game's language. Any text a
  language file does not have falls back to the default text in the data. Missing translations
  therefore never break a trail; strict mode can list them at INFO level (the same mechanism as
  in 4.5.3).
- `trail_title` / `trail_summary` can live there as well; the nested objects added in 4.6.2 stay
  supported, the language file wins.
- The trail settings file points to the folder: `"trail_text_files": "texts/"`.
- Export can write a language file "template" with all text keys and the default texts, so a
  translator gets one complete file to fill in and never touches gameplay data.

**Stable keys.** Keying by mission number breaks when a mission is inserted in the middle. Add an
optional `mission_id` column (any text, e.g. `coast`); when present it is the key instead of the
number. Trails that never reorder missions do not need it.

**Migration from language CSVs:** for each language CSV, run the 4.5.3 comparison against the
default CSV. If only text columns differ, write those texts into `texts/<language>.json` and drop
the language CSV. If gameplay columns differ, report them and stop: that is exactly the drift
the new structure removes, and a human has to decide which value is right.

## Suggested order

1. Language text files with automatic keys and the migration (removes the duplication: the
   biggest practical problem).
2. Mission JSON format 2 with the mapping table (Export/Import).
3. Reading mission JSON folders in the game.

Each step is useful on its own and none breaks existing trails.

## 4.7, for reference: more than 20 Extreme missions

Answered and fixed in 1.3.7. The data in `skmastersEx.dat` (the Skirmish Masters leaderboard) is
not involved. Besides the 39 count checks the module already changed, three more places in the
game had the vanilla mission count (20 Extreme / 30 Warchest / 50 first trail) built in: the
briefing's Start button greys itself out and refuses to start from that mission on, and
restarting a mission from the game's menu refuses the same way. They now use the trail's own
count. The win check already used it, so winning the last mission opens the end-of-trail screen
(`gfx/sktrail_win.tgx`). The upper limit stays 30 for the Warchest and the Extreme trail, because
the game's config file saves progress for 30 missions of those trails; a 31st would lose its
progress on restart. Going beyond that would mean saving the extra progress in a file of the
module's own.
