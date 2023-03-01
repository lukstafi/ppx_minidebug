ppx_minidebug
=============

## `ppx_minidebug`: A poor man's version of [`ppx_debug`]()

Trace selected code if it has type annotations.

## Usage

## Installation

## Technical details

`Debug_runtime.pp_printf` must handle `"%a"`, `"@ "`, `"%s"` and `"%d"` tags, as `Format.fprintf` would.

## VS Code suggestions

### Go to file location using [Find and Transform](https://marketplace.visualstudio.com/items?itemName=ArturoDent.find-and-transform)

[Find and Transform](https://marketplace.visualstudio.com/items?itemName=ArturoDent.find-and-transform) is a powerful VS Code extension, so there might be easier ways to accomplish this, but it does the job done. I put the following in my `keybindings.json` file (command: `Open Keyboard Shortcuts (JSON)`):
```
  {
    "key": "alt+q",
    "command": "findInCurrentFile",
    "args": {
      "description": "Open file at cursor",
      "find": "\"([^\"]+)\":([0-9]+)",
      "replace": [
        "$${",
        "vscode.commands.executeCommand('workbench.action.quickOpen', `$1:$2`);",
        "return '\\\"$1\\\":$2';",
        "}$$",
      ],
      "isRegex": true,
      "restrictFind": "line",
    }
  }
```
Then, pressing `alt+q` will open a pre-populated dialog, and `enter` will get me to the file location.

### Visualize the flame graph using [Log Inspector](https://marketplace.visualstudio.com/items?itemName=LogInspector.loginspector)

[Log Inspector](https://marketplace.visualstudio.com/items?itemName=LogInspector.loginspector)'s main feature is visualizing timestamped logs as flame graphs. I see the following configuration in my `settings.json` file (command: `Open User Settings (JSON)`).
```

```
Then, pressing `` when visiting a log file opens the flame graph.