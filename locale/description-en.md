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

## New in 1.3 (fork by Monsterfish)

### Player names and the human player's lord
Ten optional csv columns, best placed at the end:
- `player1_name` to `player8_name`: the name a player has in this mission, in the briefing and in the game. Empty keeps the usual human or AI name.
- `player1_lord`: `Arab` or `Europ` gives the human player the Arabian or the European lord for this mission. Empty keeps the player's own choice, and the starting troops are the ones of that lord.
- `player1_skip_start_units`: `1` gives the human player no starting troops in this mission (the lord still comes). Empty or `0` keeps them.

### Trail settings file
Each trail can have a trail settings file (a .json file, set in the GUI next to the trail's csv file) with settings for the trail as a whole. `resources/trail-settings.schema.json` describes it and `resources/trails/template-*-settings.json` hold the game's own values. Every entry is optional:
- `trail_type`: `First`, `Warchest` or `Extreme`.
- `trail_title`, `trail_summary`: the texts under the trail's button in the skirmish menu.
- `starting_year`: the year the first mission starts in.
- `trail_visuals`: `trail_button_idle` and `trail_button_highlighted` (pictures, for example .png, for the trail's button in the skirmish menu) and `trail_background` (the trail screen's background: a .tgx file, or a .png/.jpg/.bmp that the game turns into a .tgx once and keeps in `ucp/.cache`; use the size of the game's own file).
- `trail_mission_positions`: a list of `{ "x": .., "y": .. }` points on the 800 x 600 trail screen, one per mission. Their number is the trail's number of missions (at most 50 for the first trail, 30 for the Warchest and the Extreme trail), and the game reads that many lines from the csv file.
- `trail_csv_files`: the trail's csv file per game language, for example `{ "default": "trail.csv", "german": "trail-de.csv" }`.
- `ai_character_mapping`: your own names for the AI keys (`"SK_RICHARD": "Alfonso"`). The csv file may use them in player1 to player8.

Relative paths in the file are taken from the file's own folder.

### Csv files per language
Next to each trail's csv file, the GUI takes a csv file per game language. The game uses the one for its language and the first one for every other language. A trail settings file with `trail_csv_files` takes the place of these.

### Export and Import CSV Data
Each trail's "CSV data" panel in the GUI has an Export and an Import button. Export writes every mission line of the trail's csv files into a JSON file of its own (`<csv name>/<csv name>_mission_01.json`, ...), Import puts them back together into the csv files. The GUI cannot write files itself, so a button records the request and the game carries it out once at its next start; the panel then shows what was done. With an `ai_character_mapping`, the JSON files use your AI names and the csv file the AI keys.

## Support
All support is welcome!

[!["Buy Me A Coffee"](https://raw.githubusercontent.com/gynt/ucp-extension-running-units/main/locale/orange_img.webp)](https://www.buymeacoffee.com/gynt)

If you have PayPal:
[!["Support me on Ko-Fi"](https://raw.githubusercontent.com/gynt/ucp-extension-running-units/main/locale/kofi_button_red.png)](https://ko-fi.com/kofigynt)
