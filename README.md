# PyenvX

This script is inspired by pipx, but it's designed to work seamlessly with pyenv. It allows you to install and manage the latest versions of CLI or GUI tools, such as pdm, poetry, or Anki, while utilizing the power of pyenv. There's no need to install a massive amount of Python dependencies through your package manager!

## Requirements

- [`pyenv`](https://github.com/pyenv/pyenv#installation) must be installed and configured.
- [`pyenv-virtualenv`](https://github.com/pyenv/pyenv-virtualenv#installation) must be installed and integrated with `pyenv`.
- `curl`

## Installation

```bash
FILE="~/.local/bin/pyenvx" bash -c "curl -fsSl https://raw.githubusercontent.com/afaikiac/pyenvx/main/pyenvx.bash -o $FILE && chmod +x $FILE && echo 'pyenvx was installed!'"
```

## Usage

```bash
pyenvx --help
```

```plain
Usage:
  pyenvx <command> [arguments]

Commands:
  install     Install the specified package(s) in separate virtual environments.
              If a virtual environment for a package already exists, it will be updated.
              Usage: pyenvx install package1 [package2 ...]

  update      Update the specified package(s) in their respective virtual environments.
              Usage: pyenvx update package1 [package2 ...]

  uninstall   Uninstall the specified package(s) by deleting their respective virtual environments.
              Usage: pyenvx uninstall package1 [package2 ...]

  virtualenvs Show a list of all virtual environments managed by this script.

  --help, -h  Display this help message.

Examples:
  pyenvx install pdm poetry
  pyenvx update pdm
  pyenvx uninstall pdm
  pyenvx virtualenvs

Notes:
  - A virtual environment for each package will be created with a 'pyenvx-' prefix.```
```

For instance, if you would like to add system Python and all `pyenvx` virtual environments to the global, use the following command:

```bash
pyenv global system $(pyenvx virtualenvs)
```

## Configuration

To make use of CLI tools more convenient, you can add the `pyenv` shims folder to your `$PATH`:

```bash
export PATH=$PYENV_ROOT/shims:$PATH"
```

Shell completions for CLI tools can be added manually, depending on your preferred shell.

If you prefer packages to follow the XDG standard, you can configure your `~/.profile` as follows:

``` bash
export XDG_DATA_HOME="$HOME/.local/share"

if command -v pyenv &>/dev/null; then
  export PYENV_ROOT="$XDG_DATA_HOME/pyenv"
  export PATH=$PYENV_ROOT/shims:$PATH
fi
```

To remove all locally installed packages via `pip`, you can use this small hack:

```bash
pip freeze | awk -v FS='==' '{print $1}' | xargs pip uninstall --yes
```

And start enjoying the convenience of managing your packages with `pyenv`!
