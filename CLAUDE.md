# AA NotMischef v4 — project guide for Claude

Anime Adventures (Roblox) macro: **AutoHotkey v2** + a **Python vision helper**. The owner runs it on
two Windows PCs (and a friend may run a copy). This repo holds **code only**; every PC keeps its own
`Settings\` and `Logs\` (git-ignored, never uploaded). If a file named `HANDOVER (private).md` sits next
to this one, read it too — it has the owner's paths, history and open tasks (it is git-ignored).

## Hard rules
- **Never edit the owner's original "v2" macro copy.** Work in the v4 folder / this repo only.
- **No personal info in the repo, ever**: no Settings/Logs, no webhook URLs, Discord IDs, private-server
  links, real names, e-mail, Windows user paths. Commit as `NotMischief <NotMischief@users.noreply.github.com>`.
  `Images/LEO.jpg` and `Images/banner.png` (copyrighted art) stay out.
- Don't run unverified executables (e.g. other people's macros) — read them statically only.
- Never handle the owner's Roblox password or cookie.
- **No matchmaking-ban risk**: never leave Summer matchmaking games early, except the damage guard's
  late leave (wave >= LeaveWave, see below). Don't spam leaves.
- Summer-Hunt features must not change Dungeon (or other modes). Check `SH_On()` / mode first.
- Verify every change yourself before shipping (see Release). Don't break other processes.
- Prefer the macro's own pictures (`Logs\Watch`, `Logs\Record`, `Logs\BoardMiss`) over desktop screenshots.

## AutoHotkey v2 gotchas (all bit us before)
- Reserved words can't be variable names (`until` crashed it).
- Unreachable code after `return` raises a `#Warn` box that blocks reload.
- Assigning a global inside a function needs `global X` (declare once per function).
- For-loop variables are restored after the loop (don't use them afterwards).
- `if (...)` + one-line `try X` + `else` is a load error ("Unexpected Else" - `try` has its own
  `else`). Use braces around if/else bodies that contain `try`.
- Click coordinates are **client** coords of the 800x600 Roblox picture; FindText (`FT`) coords are ~31 px lower.
- Files are UTF-8 **with BOM**; most use LF, some CRLF — keep whatever the file already uses.
- A variable that is only read, never assigned, in a function raises a `#Warn` box at load ("local variable
  appears to never be assigned"). After any rename/replace, check the function's own definition line too.
- Validate syntax with AutoHotkey itself: `AutoHotkey64.exe /ErrorStdOut /validate Main.ahk` (Windows).

## Layout
- `Main.ahk` — includes + start-up (`AU_Start`, `WM_Init`, `VH_Start`).
- `Lib/GameMango.ahk` — the stage flow: map detection order, `MonitorStage`, `HandleStageEnd`, `TpLobby`.
- `Lib/Game/UnitPlacement.ahk` — placing (hover check, hotbar count, GoodSpots, retries).
- `Lib/Game/Upgrading.ahk` — upgrades, UPG reading, per-unit upgrade limits ("unknown" = don't upgrade blind).
- `Lib/Game/MapDetection.ahk` — `DetectHuntMap` (also reads the banner while loading).
- `Lib/Improved/SummerHunt.ahk` — Summer: lobby walk + board reading, captcha, cards/vote, banner reader
  (`SH_BannerOnce`), minimap learning/matching, map prints, Dungeon fallback, route list.
- `Lib/Improved/DamageGuard.ahk` — Tab "People / Total Damage" list reading; boost upgrades when last;
  leave at wave 47–49 if last and under MinDamage; optional Dungeon after N leaves (only if the
  "Dungeon on unknown maps" box is ticked).
- `Lib/Improved/SmartPlace.ahk` — spot finding helpers, GoodSpots memory (`Settings\GoodSpots`).
- `Lib/Improved/vision_helper.py` — Python helper (RapidOCR, OpenCV, mss), file IPC in `Logs\vision_ipc`
  (`req_*.txt` -> `resp_*.txt`). Commands: ocr, find, place, base, hover, fail, print, mini, forget, nomoney, count (hotbar "placed/max"
  label by digit shapes - templates for 0-3 from 50 hover pictures; `PL_SlotCount` falls back to OCR).
  Debug pictures go to `Logs\vision_ipc\pics` (newest 300 kept).
- `Lib/Improved/VisionHelper.ahk` — AHK side of the IPC (2 slow answers in a row -> built-in OCR for 20 s;
  `Settings\PythonWait.txt` = wait N times longer on a slow PC; time-outs and late answers are logged).
- `Lib/Improved/WatchMode.ahk` — F9: picture every 10 s; reloads in the lobby when code changed and resumes.
- `Lib/Improved/AutoUpdate.ahk` — checks this repo's `VERSION.txt` at start-up and in the lobby; replaces
  code only; keeps 3 backups. `Settings\AutoUpdate.txt`: Auto (default) / Ask / Off.

## Summer map recognition (in this order)
1. Lobby board read during the walk (`SH_ReadBoard`, strip "(Summe"-style cut-offs).
2. Banner/loading screen: map line just above "Summer Hunt"/"Weather:" (read while loading).
   **The game often shows "Planet Greenie (Summer)" on the loading screen and top title for any map —
   only trust Planet Greenie if the lobby board said so.**
3. Minimap path shape (`Settings\MiniMaps`, learnt per map, fixed position bottom-right).
4. Arrival banner again (6 s), 5. view-from-spawn print (`Settings\MapPrints`), 6. ask the user (20 s).

## UI reference (21.0, 800x600 client)
Panel X (276,227) · hotbar cards x0 = 212 + 64*(slot-1), y 512–570 · neutral click (607,553) ·
gear (27,572) · Settings X (581,147) · minimap box (645–795, 440–595) · wave text (150–310, 60–96) ·
Tab damage list (555–795, 70–370), its X (564,72).
Inventory (Items 34,296): tabs All|Skins|Relics|Charms|Artifacts|Portals(535,225)|Gifts · search (490,185) ·
X (660,189) · first tile (215,290). Clicking an item opens a popup next to the tile with Use (green) /
Delete (red) / View (yellow) - it moves, so Portal finds Use by the colour stack (`PT_FindUse`), never a fixed spot.

## Release (every change)
1. Edit in a clean way; keep the file's encoding/line endings.
2. Validate with AutoHotkey (`/validate`) and `python -I -m py_compile` for the helper.
3. Test vision changes on saved screenshots (Logs\Record / Watch / BoardMiss).
4. Bump `VERSION.txt` (`yyyy.mm.dd.hhmm`, local time, must increase).
5. Commit + push to `main` — every PC (and the friend's copy) auto-updates from it.
   Prefer trying risky changes on one PC first.
6. Tell the owner what changed, what was tested, and what wasn't.
