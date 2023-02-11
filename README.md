# PyenvX

The creation of this script was inspired by `pipx` but it does not disrupt my `pyenv` workflow. I simply want the latest versions of CLI or GUI tools, such as `pdm`, `poetry` or `Anki`, while still utilizing the power of `pyenv`. And I don't want to have to install a massive amount of Python dependencies through my Linux package manager!

## Requirements

- [`pyenv`](https://github.com/pyenv/pyenv#installation) must be installed and configured.
- [`pyenv-virtualenv`](https://github.com/pyenv/pyenv-virtualenv#installation) must be installed and integrated with `pyenv`.

## Installation

```bash
git clone https://github.com/afaikiac/pyenvx.git
cp pyenvx/pyenvx.bash ~/bin/pyenvx
chmod +x ~/bin/pyenvx
```

## Usage

```bash
pyenvx install python_version package_name [package_name ...]
pyenvx uninstall virtual_evironment_name [virtual_evironment_name ...]
```

### Installing a package

```bash
$ pyenvx install pdm poetry
# This script creates a separate virtual environment with the Python interpreter
# that you specify in the prompt for each package:
#     package_name (e.g. pdm, poetry virtual environments)
# The package is then installed in the corresponding environment.
# Finally, the environment is added to the global pyenv setup.
# You can now run the programs!
$ pdm init
$ poetry init
```

```bash
# To update the package, simply run the command again.
$ pyenvx install pdm
```

### Uninstalling a package

```bash
# Check what's in your global setup
$ pyenv global
system
3.11.1
pdm
poetry
$ pyenvx uninstall pdm poetry
# The script removes these virtual environments 
# from your global pyenv setup and deletes them permanently. 
# As a result, the CLI programs in these venvs are no longer
# available on your computer.
```

## Configuration

To make use of CLI tools more convenient, you can add the `pyenv` shims folder to your `$PATH` by adding this line to your shell configuration:

```bash
export PATH=$PYENV_ROOT/shims:$PATH"
```

Shell completions for CLI tools can be added manually, depending on your preferred shell.

I like when packages follow the XDG standard, so I add the following to my `~/.profile`:

``` bash
export XDG_DATA_HOME=$HOME/.local/share
export PATH=$HOME/bin:$PATH
export PATH=$HOME/.local/bin:$PATH

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

## TODO

- Store venvs list in separate file and merge it with `pyenv global`
- Write `pyenv` module.
