# VHS design system

## Grid.swift
Use Space tokens for all margins and gaps: 4, 8, 12, 16, 20, 24, 32 points. Window content margins are 20 points. Probe custom sections in snapshot mode; native slider internals align themselves.

## Tokens.swift
Layout contains control-column and window dimensions plus the preview corner radius. The preview keeps its source aspect ratio. The minimum editor size must preserve every control.

## Color and typography
Use semantic system background, primary and secondary text, native control tint, and system text styles. The default accent follows the Mac. Scene RGB values are user content and are independent of the editor's semantic colors. Do not tint the editor with the scene color.

## Motion and accessibility
Phase 1 adds no custom animation. Use native sliders and buttons; preserve keyboard interaction, help, labels, and values. Do not convey meaning solely through color. Appearance follows macOS, including increased contrast.
