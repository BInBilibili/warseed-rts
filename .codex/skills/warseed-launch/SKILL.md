---
name: warseed-launch
description: "Use only for work inside the WARSEED project; after a modification, run the appropriate validation and include a clickable link to the project's one-click launcher."
---

# WARSEED project workflow

Apply this skill only when the current workspace is `D:\game\warseed-rts`.

## Text and localization rule

When adding or changing user-visible text:

- Use a translation key and the existing localization system first; do not add new hardcoded UI text in scenes or scripts.
- Add or update the same key in every existing `locale/*.po` file, with a translated `msgstr` for each language.
- Before finishing, verify that the changed keys are present and synchronized across all existing language files.

For UI or localization changes, also follow the repository workflow: read `AGENTS.md`, `docs/AI_DEVELOPMENT_WORKFLOW.md`, `docs/DECISIONS.md`, and the relevant current-state sections; record the work in `docs/work_items/` and update `docs/AI_DEVELOPMENT_STATE.md`. Run the focused UI test and, when the change affects UI layout or localization, run `tests/tools/accessibility_resolution_matrix.gd`; record any pre-existing or out-of-scope failures instead of calling the matrix PASS.

After modifying project files:

1. Run focused validation for the changed area. For Godot or C# changes, use `dotnet build WARSEED.csproj --nologo` and a Godot headless startup check when the bundled Godot console is available.
2. Run `git diff --check` and avoid changing unrelated files.
3. Run the project's launcher after validation, without waiting for the game window to close:

   `wscript.exe //B //NoLogo "D:\\game\\warseed-rts\\START_WARSEED.vbs"`

   Treat a non-zero launcher result or a missing game process as a failed launch and report the concrete cause.
4. End the user-facing response with this clickable launcher link on its own line:

   `[Launch WARSEED](warseed://launch)`

   If the protocol has not been registered on this Windows machine, include the one-time installer link `[Install WARSEED launch link](D:/game/warseed-rts/INSTALL_WARSEED_LINK.cmd)` and the fallback command `cmd /c "D:\\game\\warseed-rts\\START_WARSEED.cmd"`.

The protocol link calls the repository's hidden `START_WARSEED.vbs` wrapper, which starts `START_WARSEED.cmd` without showing a command window. Do not claim that the game was started unless the launcher was actually run and the game process was observed. If the launcher or protocol installer is missing or broken, repair it as part of the requested project change or report the concrete failure.

This skill does not authorize commits, pushes, issue submission, or other external actions. It only standardizes local validation and the launcher link in responses.
