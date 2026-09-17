-- termite.nvim
-- Shared mutable state.

return {
	terminals = {}, -- Ordered list of terminal entries: { buf, win, config }.
	visible = false, -- Whether the terminal panel is currently shown.
	maximized_idx = nil, -- Index of maximized terminal, or nil if none.
	last_maximized_idx = nil, -- Maximized terminal remembered across hide/show.
	tab_win = nil, -- Window id of the maximized-mode tab bar, or nil when hidden.
	tab_buf = nil, -- Buffer id backing the tab bar (reused across show/hide).
	last_editor_winnr = nil, -- Window to return to when focusing editor.
	last_focused_idx = nil, -- Index of the most recently focused terminal.
	next_count = 1, -- Incrementing counter for unique terminal ids.
	reflowing = false, -- Re-entrancy guard while a reflow is in progress.
}
