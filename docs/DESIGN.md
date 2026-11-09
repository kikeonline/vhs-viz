# Phase 1 design

- Archetype: one editing window plus a separate performance output.
- Information architecture: a Live Preview beside a fixed-width Source/Color column. No navigation hierarchy is needed for one source.
- Feeling: confident and immediate; visuals respond without animated editor transitions.
- Initial state: a visible violet solid and usable RGB controls. No empty project wizard.
- Render error: an inline Unable to Render state in place of the preview.

| Command | Menu | Shortcut | Other entry |
| --- | --- | --- | --- |
| Undo Color Change | Edit | Command-Z | — |
| Redo Color Change | Edit | Shift-Command-Z | — |
| Show Output | Window | Shift-Command-O | toolbar |
| Show Control Window | Window | Command-1 | — |
| Close | File | Command-W | native close button |
| Quit VHS | VHS | Command-Q | — |

Color controls are native sliders, with text labels, numeric values, accessibility values, and help. The Mac's appearance and accent remain authoritative. The output contains no editor overlays.

Icon concepts considered: stacked signal bands on violet; a projection aperture on blue; a two-reel cassette on charcoal. Chosen: signal bands, because the silhouette reads at small sizes and represents procedural visual output without lettering or an SF Symbol.

## Phase 2 file lifecycle

One project is active for preview and output. Native File commands: New Project (Command-N), Open Project… (Command-O), Save Project (Command-S), Save Project As… (Shift-Command-S), Rename Project… (Shift-Command-R). Closing the output never closes the document. Closing the control window and quitting protect unsaved edits.

The title is the filename for saved projects and the chosen name for Untitled projects. A native edited indicator and a visible Edited status identify unsaved changes. File commands are disabled during file operations; saving captures a snapshot so continued scene edits remain dirty. Rename is a 480pt sheet with focused name field, inline validation, Cancel, and Rename. Saved rename moves the file without overwriting another file; the filename is authoritative when opening, and the JSON title is synchronized on the next save. Rename does not create a scene undo step; scene history survives rename/save and resets on New/Open.

## Phase 3 source inspector

The single project window keeps preview left and an inline Source picker above a scrollable right inspector. The registry supplies names, defaults, numeric ranges, color controls, choices and toggles. Solid retains its RGB sliders. Other sources use native color pickers for two colors. Noise exposes an exact integer seed. Native parameter controls can scroll at the minimum window size; source selection always stays available.

Source changes preserve inactive settings and finish an active slider gesture before a separate undo entry. Numeric slider gestures remain one entry; native color panel updates, choices, toggles and committed seed edits are discrete scene changes. Undo/Redo names become Scene Change because history now includes more than color. All rendered surfaces use the common clock/frame. No effects, audio, or projection features are added in Phase 3.

Shape Rectangle uses a 3:2 silhouette; Size sets its height relative to the short viewport dimension. Circle uses Size as diameter; Triangle uses it as circumdiameter. Position is normalized from the top-left; positive rotation follows screen coordinates.
