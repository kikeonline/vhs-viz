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
