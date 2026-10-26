# # MealQuest

Turn-based battle game built in **Godot 4.7.2**. Your party of food (Tomato, Steak, Soup) fights an enemy knife using moves, cooldowns, guards, taunts and heals.

## Running the project

1. Open the project in Godot 4.7.2.
2. If you see "Cannot find class MoveData" (or TeamManager, BattleUI and so on), choose **Project > Reload Current Project**. Godot needs to rescan the `class_name` scripts.
3. To test the battle on its own, open `battle.tscn` and press **F6**.

## How the battle is organized

The battle is split into modules so several people can work at once. Each module has one job and talks to the others through signals.

| Module | Script | Job |
|---|---|---|
| Battle | `battle.gd` | Turn flow only. The one script that knows about all the others. |
| Team | `team_manager.gd` | Rules and numbers: HP, turn order, cooldowns, guard, taunt, rally. No visuals. |
| Animations | `battle_animations.gd` | Everything that moves: tomato roll, knife slash, shakes, death fades. |
| UI | `battle_ui.gd` | Moves menu, tooltips, turn arrow, textbox, health bars, damaged sprites, floating numbers. |
| Move data | `move_data.gd` | Resource type for one move (damage, cooldown, icon, text). |
| Party member data | `party_member_data.gd` | Resource type for one character (HP, damage, damaged sprite, moves). |

Scene tree under the Battle root (names must match exactly):

```
Battle (battle.gd)
├─ Team          team.tscn
├─ Animations    animations.tscn
├─ UI            ui.tscn          (Full Rect, Mouse Filter: Ignore, last in the tree)
├─ Hero, Ally1, Ally2, Enemy      (sprites, each with VBoxContainerH/ProgressBar)
├─ AnimationPlayer
├─ Textbox, ActionsPanel
```

## Folder layout

| Folder | Contents |
|---|---|
| `Separated Scenes/` | The module scripts and scenes (`team.tscn`, `animations.tscn`, `ui.tscn`) |
| `Separated Scenes/data/moves/` | One `.tres` per move (Roll, Defend, Meat Mash, Taunt, Harden, Broil, Hearty Broth, Dinner Call) |
| `Separated Scenes/data/party/` | One `.tres` per character (`tomato`, `steak`, `soup`) |
| `Animation_VFX_Import/` | Tomato roll frames, splat, knife frames |
| `UI_Move_Buttons/` | Move button images |

## Who owns what

| Role | Edits | Does not touch |
|---|---|---|
| Designer | `data/moves/*.tres`, `data/party/*.tres`, turn order on `team.tscn` | Scenes and scripts |
| Animator | `animations.tscn`, `battle_animations.gd` | `battle.tscn` |
| UI artist | `ui.tscn`, `battle_ui.gd` | `battle.tscn` |
| Gameplay programmer | `team.tscn`, `team_manager.gd` | `battle.tscn` |
| Lead | `battle.tscn`, `battle.gd`, where sprites sit on screen | |

## The one rule

**Edit a module inside its own scene, never through `battle.tscn`.**

Open the module with the clapperboard icon on the node, or double-click its `.tscn` in the FileSystem dock. If you change a value on an instance while inside `battle.tscn`, Godot saves that change in `battle.tscn`, and two people saving that file at once causes merge conflicts. A revert arrow beside a property on an instanced node means it is overridden in `battle.tscn`.

## Common tasks

**Change a move's damage, cooldown, text or tooltip**
1. Open `Separated Scenes/data/moves/<move>.tres`.
2. Edit the fields in the Inspector and press Ctrl+S.

**Give a move a button image**
1. Open the move's `.tres`.
2. Drag the image from `UI_Move_Buttons` into **Icon** and save.

**Change a character's HP, damage or damaged sprite**
1. Open `data/party/<character>.tres`. Tomato's HP and damage come from the `State` autoload (its **Use Global State** is on), so change them there.
2. Drag the damaged image into **Damaged Tex** and save.

**Change the turn order**
1. Open `team.tscn` and select the `Team` node.
2. Edit **Turn Order**. Numbers are party slots: 0 = Tomato, 1 = Steak, 2 = Soup.

**Swap the tomato or knife animation**
1. Open `animations.tscn` and select the `Animations` node.
2. Replace the images in **Tomato Frames** (9 roll frames, then the splat) or **Knife Frames**. Adjust **Roll Count** if the number of roll frames changes.

**Restyle the move text or menu position**
1. Open `ui.tscn` and select the `UI` node.
2. Use the **Move button text** and **Turn title and menu position** groups. Set **Move Icon Size** to match the shape of your button images.

## Things that need code

- A new kind of move (poison, double hit). Add a case to the `kind` list in `move_data.gd`, then handle it in `battle.gd` and `team_manager.gd`.
- A new attack animation. Add an awaitable function to `battle_animations.gd` and call it from `_do_attack` in `battle.gd`.
- A fourth party member. Add a sprite node with a health bar, create a new `PartyMemberData` `.tres`, and add it to **Members** on the Team node.
- A second enemy with different attacks. The enemy's attack is currently the knife slash only.

## Git workflow

- Use a branch per task, named for the area (for example `anim/knife-slash` or `data/steak-balance`).
- Run `git pull` before you start each session, and commit small and often.
- Commit the `.uid` files that Godot creates next to scripts. Add `.godot/` to `.gitignore`.
- Merge into `main` often so conflicts never pile up.
- Only the lead edits `battle.tscn` and `battle.gd`. Ask the lead if a sprite needs to move.


## Troubleshooting

| Problem | Fix |
|---|---|
| "Cannot find class MoveData" (or similar) | Project > Reload Current Project |
| "Node not found: Team / Animations / UI" | Check the node names and that they are direct children of the Battle root |
| "Assign PartyMemberData resources" in the Output | Fill **Members** on the Team node with `tomato.tres`, `steak.tres`, `soup.tres` in that order |
| Move buttons show text instead of icons | The icon is not set in the move's `.tres`, or the file was not saved |
| Buttons or turn arrow missing | `UI` must be Full Rect, Mouse Filter Ignore, and last in the Battle tree |
| An autoload fails with "File not found" | Project > Project Settings > Globals: fix or remove the entry that points to a moved file |
| Taunt or Rally lasts too long | They reset in `TeamManager.end_round()` |