# Custom Skirmish Trails
This extension enables custom skirmish trails, specified in .csv files.

## Possibilities
The zip file of this extension contains a template.csv file that describes what is possible to mod.

You can also download the first trail [here](https://raw.githubusercontent.com/gynt/ucp-extension-custom-skirmish-trails/refs/heads/main/template-First-Edition-Trail.csv), the warchest [here](https://raw.githubusercontent.com/gynt/ucp-extension-custom-skirmish-trails/refs/heads/main/template-Warchest-Trail.csv) and the extreme trail [here](https://raw.githubusercontent.com/gynt/ucp-extension-custom-skirmish-trails/refs/heads/main/template-Extreme-Trail.csv).

An easy online editor can be found here: https://edit-csv.net/

Here is a list:
- map_name
- fairness
- start_levels
- num_players
- player1
- player2
- player3
- player4
- player5
- player6
- player7
- player8
- start_position1
- start_position2
- start_position3
- start_position4
- start_position5
- start_position6
- start_position7
- start_position8
- team1
- team2
- team3
- team4
- team5
- team6
- team7
- team8
- aiv_type1
- aiv_type2
- aiv_type3
- aiv_type4
- aiv_type5
- aiv_type6
- aiv_type7
- aiv_type8
- mission_name
- gold
- producible_bows
- producible_crossbows
- producible_maces
- producible_pikes
- producible_spears
- producible_swords
- recruitable_archers
- recruitable_spearmen
- recruitable_macemen
- recruitable_crossbowmen
- recruitable_pikemen
- recruitable_swordsmen
- recruitable_knights
- recruitable_arabian_bows
- recruitable_slaves
- recruitable_slingers
- recruitable_assassins
- recruitable_horse_archers
- recruitable_arabian_swordsmen
- recruitable_fire_throwers
- resource_wood
- resource_hops
- resource_stone
- resource_iron
- resource_pitch
- resource_wheat
- resource_bread
- resource_cheese
- resource_meat
- resource_apple
- resource_ale
- resource_gold
- resource_flour
- resource_bow
- resource_crossbow
- resource_spear
- resource_pike
- resource_mace
- resource_sword
- resource_leatherarmor
- resource_ironarmor
- text_dexcription_line_01 - 08: Use "" to write text displayed in the skirmish misson start menu
- trade_: Use e.g. trade_spear (single!) to set trading of that good off or on

## New in 1.4 (fork by Monsterfish)

### Player names and the human player's lord
Optional csv columns, best placed at the end:
- `player1_name` to `player8_name`: the name a player has in this mission, in the briefing and in the game. Empty keeps the usual human or AI name.
- `player1_lord`: `Arab` or `Europ` gives the human player the Arabian or the European lord for this mission, and the starting troops of that lord. Empty keeps the player's own choice.
- `player1_skip_start_units`: `1` gives the human player no starting troops in this mission (the lord still comes). Empty or `0` keeps them.

### Trail settings file
Each trail can have a trail settings file (a .json file, set in the GUI) with everything about the trail. `resources/trail-settings.schema.json` describes it, and `resources/trails/template-*-settings.json` hold the game's own values. Every entry is optional:
- `trail_type`: `First`, `Warchest` or `Extreme`.
- `trail_missions`: the trail's mission data, see below.
- `trail_text_files`: the trail's language files, see below.
- `trail_title`, `trail_summary`: the texts under the trail's button in the skirmish menu. A summary wider than 540 pixels wraps into a second line; both texts then sit 10 pixels higher.
- `starting_year`: the year the first mission starts in.
- `trail_visuals`: `trail_button_idle` and `trail_button_highlighted` (pictures, for example .png, for the trail's button in the skirmish menu), and `trail_background` (the trail screen's background: a .tgx file, or a .png/.jpg/.bmp that the game turns into a .tgx once and keeps in `ucp/.cache`; use the size of the game's own file).
- `trail_mission_positions`: a list of `{ "x": .., "y": .. }` points on the 800 x 600 trail screen, one per mission. Their number is the trail's number of missions (at most 50 for the first trail, 30 for the Warchest and the Extreme trail).
- `ai_character_mapping`: your own names for the AI keys (`"SK_RICHARD": "Alfonso"`). Mission files use them, and the csv file may use them in player1 to player8.

Relative paths in the file are taken from the file's own folder.

### Mission data: csv file and mission files
`"trail_missions": { "base_name": "missions/reconquista", "data_mode": "csv" }` names both the csv file (`missions/reconquista.csv`) and a folder of mission files (`missions/reconquista/reconquista_mission_01.json`, ...). A mission file (format 1, `resources/mission.schema.json`) holds the same data as one csv line, laid out for reading and editing:
- `mission_name` and `text_description` (a list of the 8 lines) at the top;
- `advantage` (`human_large`, `human_small`, `neutral`, `ai_small`, `ai_large`; the csv's fairness 1-5) and `start_mode` (`normal`, `crusader`, `deathmatch`; the csv's start_levels 1-3). Numbers work too;
- `players`: one entry per player, so their number is the mission's number of players. `players[0]` is the human player: it may have `lord` and `skip_start_units`, never `ai`. The others always have `ai`, never `lord`. All have `name`, `start_position`, `team`, `aiv_type` and `gold` as needed;
- `producible`, `recruitable`, `resources`, `tradeable`: the csv's prefixed columns as objects;
- `extra`: any csv value that has no place above, so that nothing gets lost.

`data_mode` says which one is the ground truth. It is applied at every game start:
- `csv`: the game loads the csv file and writes the mission files from it.
- `json_folder`: the game writes the csv file from the mission files, then loads it.
- `automatic`: per mission, whichever was edited last wins: newer mission files go into the csv, newer csv lines into the mission files.

Before files are changed, the previous csv is kept as `<csv>.bak` and the previous mission files in `<folder>/.bak` (one previous version each). When no file changed since the last start, nothing is read or written. Without a trail settings file, the csv file set in the GUI is used as before.

### Language files
The mission data holds one set of texts, the default language. Each further language is one small JSON file with only its texts: `"trail_text_files": "texts/"` points to a folder with `english.json`, `german.json` and so on (or give an object of languages to files). A language file:

```json
{
  "trail_title": "Die Reconquista",
  "trail_summary": "...",
  "missions": {
    "1": { "mission_name": "Die Küste", "text_description_line_01": "...", "player2_name": "..." }
  }
}
```

Missions are found by their number. A text a language file does not have shows the mission data's text; strict mode lists those. With `trail_missions`, `texts/_template.json` is written with all texts of the mission data, as a starting point for translators.

### File paths
Each trail's "File paths" panel lists the files set for it and clears them (the GUI's own reset only works right after a path was set).

### Strict mode
Developer settings: logs every problem in the csv, mission, language and trail settings files, every trail setting that falls back to the game's own value, and every text a language file lacks. Without it, one warning per file with problems.

### Export and Import CSV Data
Each trail's "CSV data" panel in the GUI has an Export and an Import button, for converting by hand (`trail_missions` does it at every start on its own). Export writes every csv line into a mission file, Import puts the mission files back together into the csv file. The GUI cannot write files itself, so a button records the request and the game carries it out at its next start; the panel then shows what was done.

## Support
All support is welcome!

[!["Buy Me A Coffee"](https://raw.githubusercontent.com/gynt/ucp-extension-running-units/main/locale/orange_img.webp)](https://www.buymeacoffee.com/gynt)

If you have PayPal:
[!["Support me on Ko-Fi"](https://raw.githubusercontent.com/gynt/ucp-extension-running-units/main/locale/kofi_button_red.png)](https://ko-fi.com/kofigynt)
