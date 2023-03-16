#!/usr/bin/env bash

set -euo pipefail

function print() {
	printf "%s\n" "$@" &>/dev/tty
}

function log() {
	printf "%s\n" "[$(basename "$0")] $1" &>/dev/tty
}

function die() {
	log "$@"
	exit 1
}

function verify_pyenv_in_path_or_die() {
	if ! command -v pyenv &>/dev/null; then
		die "'pyenv' not found. Please install it first."
	fi
}

function verify_pyenv_virtualenv_module_or_die() {
	if ! command -v pyenv virtualenv &>/dev/null; then
		die "'pyenv virtualenv' not found. Please install it first."
	fi
}

function is_virtualenv() {
	local venv_name="$1"
	pyenv virtualenvs --bare --skip-aliases | grep "^.*/$venv_name$" &>/dev/null
}

function verify_package_name_or_die() {
	local package=$1
	local response
	response=$(curl -s -o /dev/null -w "%{http_code}" https://pypi.org/project/"$package"/)

	if ! [ "$response" -eq 200 ]; then
		die "Package '$package' not found in PyPI"
	fi
	log "Package '$package' found in PyPI"
}

function create_venv() {
	local venv_name=$1
	local python_version=$2

	pyenv virtualenv "$python_version" "$venv_name"
	log "Virtual environment '$venv_name' was created"
}

function install_package_in_venv() {
	local package=$1
	local venv_name=$2

	pyenv activate "$venv_name"
	pip install --upgrade "$package"
	log "Package '$package' was installed successfully in '$venv_name' virtual environment"
	pyenv deactivate
}

function is_line_in_global() {
	local line=$1
	pyenv global | grep "^$line$" &>/dev/null
}

function add_line_to_global() {
	local line=$1
	pyenv global $(pyenv global) $line
}

function remove_line_from_global() {
	local line=$1
	pyenv global $(pyenv global | grep -v "^$line$")
}

function prompt_select_item() {
	local prompt_text=$1
	shift 1
	local items=("$@")

	print "$prompt_text"
	for i in "${!items[@]}"; do
		print "$i. ${items[i]}"
	done

	local chosen_item
	local default_selected=$((${#items[@]} - 1))
	while true; do
		read -p "Please select ($default_selected): " selected
		if [ -z "$selected" ]; then
			selected=$default_selected
		fi

		if [ "$selected" -ge 0 ] 2>/dev/null && [ "$selected" -lt "${#items[@]}" ] 2>/dev/null; then
			chosen_item="${items[selected]}"
			break
		else
			print "Invalid selection. Please try again."
		fi
	done

	echo "$chosen_item"
}

function get_python_versions_or_die() {
	local versions=("$(pyenv versions --bare --skip-aliases | grep -v "/")")

	if [ ${#versions[@]} -eq 0 ]; then
		die "No Python interpreters found. Please install one first."
	fi

	echo "${versions[@]}"
}

function install() {
	local package=$1
	local venv_name=$2
	local python_version=$3
	local venv_file=$4

	echo "$venv_name" >>"$venv_file"
	create_venv "$venv_name" "$python_version"
	install_package_in_venv "$package" "$venv_name"
	if ! is_line_in_global "$venv_name"; then
		add_line_to_global "$venv_name"
	fi
}

function update() {
	local package=$1
	local venv_name=$2
	local venv_file=$3

	echo "$venv_name" >>"$venv_file"
	install_package_in_venv "$package" "$venv_name"
	if ! is_line_in_global "$venv_name"; then
		add_line_to_global "$venv_name"
	fi
}

function uninstall() {
	local venv_name=$1

	if is_line_in_global "$venv_name"; then
		remove_line_from_global "$venv_name"
	fi
	pyenv virtualenv-delete --force "$venv_name"
	log "Virtual environment '$venv_name' was uninstalled"
}

function update_venv_list_in_file() {
	local file_fullpath=$1
	local venvs

	while IFS= read -r line; do
		if is_virtualenv "$line"; then
			venvs+=("$line")
		fi
	done <"$file_fullpath"

	printf "%s\n" "${venvs[@]}" >"$file_fullpath"
}

function setup_pyenv_or_die() {
	verify_pyenv_in_path_or_die
	verify_pyenv_virtualenv_module_or_die

	eval "$(pyenv init -)"
	eval "$(pyenv virtualenv-init -)"
}

function print_help() {
	local script_name=$1
	local venv_prefix=$2
	cat <<EOF >/dev/tty
$(tput bold)$(tput setaf 2)pyenvx 2.0.0$(tput sgr0)

A script to manage Python packages with their own virtual environments using pyenv and pyenv-virtualenv.

Usage:
  $script_name <command> [arguments]

Commands:
  $(tput bold)install$(tput sgr0)     Install the specified package(s) in separate virtual environments.
              If a virtual environment for a package already exists, it will be updated.
              Usage: $script_name install package1 [package2 ...]

  $(tput bold)update$(tput sgr0)      Update the specified package(s) in their respective virtual environments.
              Usage: $script_name update package1 [package2 ...]

  $(tput bold)uninstall$(tput sgr0)   Uninstall the specified package(s) by deleting their respective virtual environments.
              Usage: $script_name uninstall package1 [package2 ...]

  $(tput bold)global$(tput sgr0)      Show a list of all virtual environments managed by this script.

  $(tput bold)--help, -h$(tput sgr0)  Display this help message.

Examples:
  $script_name install pdm poetry
  $script_name update pdm
  $script_name uninstall pdm
  $script_name global

Notes:
  - A virtual environment for each package will be created with a '$venv_prefix' prefix.
EOF
}

function main() {
	local VENVS_FILE="${XDG_DATA_HOME:-"$HOME/.local/share"}/pyenvx/venvs"
	local VENV_PREFIX="pyenvx-"

	setup_pyenv_or_die

	if ! [[ -e "$VENVS_FILE" ]]; then
		mkdir -p "$(dirname "$VENVS_FILE")"
		touch "$VENVS_FILE"
	fi

	local command=${1:-"--help"}
	shift || true

	case "$command" in
	install)
		for package in "$@"; do
			verify_package_name_or_die "$package"
			local venv_name="$VENV_PREFIX$package"
			if ! is_virtualenv "$venv_name"; then
				local python_versions=($(get_python_versions_or_die))
				local python_version
				python_version=$(
					prompt_select_item \
						"Please enter the Python interpreter to use with '$package'" \
						"${python_versions[@]}"
				)
				install "$package" "$venv_name" "$python_version" "$VENVS_FILE"
			else
				update "$package" "$venv_name" "$VENVS_FILE"
			fi
		done
		;;
	update)
		for package in "$@"; do
			local venv_name="$VENV_PREFIX$package"
			if is_virtualenv "$venv_name"; then
				update "$package" "$venv_name" "$VENVS_FILE"
			else
				log "Virtual environment '$venv_name' not found."
			fi
		done
		;;
	uninstall)
		for package in "$@"; do
			local venv_name="$VENV_PREFIX$package"
			if is_virtualenv "$venv_name"; then
				uninstall "$venv_name"
			else
				log "Virtual environment '$venv_name' not found."
			fi
		done
		;;
	global)
		update_venv_list_in_file "$VENVS_FILE"
		cat "$VENVS_FILE" &>/dev/tty
		;;
	--help | -h | *)
		print_help "$(basename "$0")" "$VENV_PREFIX"
		exit 1
		;;
	esac
}

main "$@"
