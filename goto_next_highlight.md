# TUI: new command "go to next highlight leaf"

Implement a command that recursively expands the closest unexpanded highlight following the cursor (at same or bigger depth). I.e. starting from the cursor position, it finds (if any) the next unexpanded (visible) highlight within same scope or descendant of the scope, expands it, and recurses from the beginning of the expanded scope.

This could maybe replace "go to next search result" which can be unreliable, but both commands have their merrits.