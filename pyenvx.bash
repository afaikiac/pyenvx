#!/usr/bin/env bash

set -euo pipefail

RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
NORMAL=$(tput sgr0)
BOLD=$(tput bold)

print() {
	printf "%s\n" "$@" &>/dev/tty
}

log() {
	printf "%s\n" "[$(basename "$0")] $1" &>/dev/tty
}

die() {
	log "$@"
	exit 1
}

verify_pyenv_in_path_or_die() {
	if ! command -v pyenv &>/dev/null; then
		die "'pyenv' not found. Please install it first."
	fi
}

is_virtualenv() {
	local venv_name="$1"
	pyenv virtualenvs --bare --skip-aliases | grep "^.*/$venv_name$" &>/dev/null
}

verify_package_name_or_die() {
	local package=$1
	local response
	response=$(curl -s -o /dev/null -w "%{http_code}" https://pypi.org/project/"$package"/)

	if ! [ "$response" -eq 200 ]; then
		die "Package '$package' not found in PyPI"
	fi
	log "Package '$package' found in PyPI"
}

create_venv() {
	local venv_name=$1
	local python_version=$2

	pyenv virtualenv "$python_version" "$venv_name"
	log "Virtual environment '$venv_name' was created"
}

install_package_in_venv() {
	local package=$1
	local venv_name=$2

	pyenv activate "$venv_name"
	python -m pip install --upgrade pip
	pip install --upgrade "$package"
	log "Package '$package' was installed successfully in '$venv_name' virtual environment"
	pyenv deactivate
}

is_line_in_global() {
	local line=$1
	pyenv global | grep "^$line$" &>/dev/null
}

add_line_to_global() {
	local line=$1
	pyenv global $(pyenv global) $line
}

remove_line_from_global() {
	local line=$1
	pyenv global $(pyenv global | grep -v "^$line$")
}

prompt_select_item() {
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

prompt_yes_no() {
	read -p "$1 [Y/n] "
	[[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]
}

get_python_versions_or_die() {
	local versions=("$(pyenv versions --bare --skip-aliases | grep -v "/")")

	if [ ${#versions[@]} -eq 0 ]; then
		die "No Python interpreters found. Please install one first."
	fi

	echo "${versions[@]}"
}

install() {
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

update() {
	local package=$1
	local venv_name=$2

	install_package_in_venv "$package" "$venv_name"
	if ! is_line_in_global "$venv_name"; then
		add_line_to_global "$venv_name"
	fi
}

uninstall() {
	local venv_name=$1

	if is_line_in_global "$venv_name"; then
		remove_line_from_global "$venv_name"
	fi
	pyenv virtualenv-delete --force "$venv_name"
	log "Virtual environment '$venv_name' was uninstalled"
}

setup_pyenv_virtualenv() {
	local pyenv_virtualenv_root
	pyenv_virtualenv_root="$(pyenv root)/plugins/pyenv-virtualenv"

	if [ ! -d "$pyenv_virtualenv_root" ]; then
		local plugin_repo_url="https://github.com/pyenv/pyenv-virtualenv.git"
		git clone "$plugin_repo_url" "$pyenv_virtualenv_root"
	else
		if GIT_DIR="$pyenv_virtualenv_root/.git" git fetch &&
			! GIT_DIR="$pyenv_virtualenv_root/.git" git status -uno | grep -q 'Your branch is up to date'; then
			log "Update for pyenv-virtualenv is available"
			log "To update, run: ${GREEN}cd $pyenv_virtualenv_root && git pull${NORMAL}"
		fi
	fi
}

print_virtualenvs() {
	local venv_prefix="$1"

	pyenv virtualenvs --bare | grep "^$venv_prefix" | cut -d ' ' -f 1
}

print_help() {
	local script_name=$1
	local venv_prefix=$2
	cat <<EOF >/dev/tty
${BOLD}${GREEN}pyenvx 2.3.0${NORMAL}

A script to manage Python packages with their own virtual environments
using pyenv and pyenv-virtualenv.

Usage:
    $script_name ${BOLD}install${NORMAL} package1 [package2 ...]     
        Install the specified package(s) in separate virtual environments.
        And add virtual environments to global. If a virtual environment for
        a package already exists, the script will prompt you to recreate it.
  
    $script_name ${BOLD}update${NORMAL} package1 [package2 ...]
        Update the specified package(s) in their respective virtual
        environments. And add virtual environments to global.
  
    $script_name ${BOLD}uninstall${NORMAL} package1 [package2 ...]
        Uninstall the specified package(s) by deleting their respective
        virtual environments. And remove virtual environments from global.
  
    $script_name ${BOLD}virtualenvs${NORMAL}
        Show a list of all virtual environments managed by this script.
  
    $script_name [${BOLD}--help${NORMAL}, ${BOLD}-h${NORMAL}]
        Display this help message.

Examples:
    $script_name install pdm poetry
    $script_name update pdm
    $script_name uninstall pdm
    $script_name virtualenvs

Notes:
    - A virtual environment for each package will be created with
      a '$venv_prefix' prefix.

More information: https://github.com/afaikiac/pyenvx
EOF
}

main() {
	local VENV_PREFIX="pyenvx-"

	verify_pyenv_in_path_or_die
	eval "$(pyenv init -)"
	setup_pyenv_virtualenv
	eval "$(pyenv virtualenv-init -)"

	local command=${1:-"--help"}
	shift || true

	case "$command" in
	install)
		for package in "$@"; do
			verify_package_name_or_die "$package"
			local venv_name="$VENV_PREFIX$package"

			if is_virtualenv "$venv_name"; then
				if prompt_yes_no "Do you want to reinstall '$package'?"; then
					uninstall "$venv_name"
				else
					continue
				fi
			fi

			local python_versions=($(get_python_versions_or_die))
			local python_version
			python_version=$(
				prompt_select_item \
					"Please enter the Python interpreter to use with '$package'" \
					"${python_versions[@]}"
			)
			install "$package" "$venv_name" "$python_version" "$VENVS_FILE"
		done
		;;
	update)
		for package in "$@"; do
			local venv_name="$VENV_PREFIX$package"

			if ! is_virtualenv "$venv_name"; then
				log "Virtual environment '$venv_name' not found."
				continue
			fi

			update "$package" "$venv_name"
		done
		;;
	uninstall)
		for package in "$@"; do
			local venv_name="$VENV_PREFIX$package"

			if ! is_virtualenv "$venv_name"; then
				log "Virtual environment '$venv_name' not found."
				continue
			fi

			uninstall "$venv_name"
		done
		;;
	virtualenvs)
		print_virtualenvs "$VENV_PREFIX"
		;;
	--help | -h | *)
		print_help "$(basename "$0")" "$VENV_PREFIX"
		exit 1
		;;
	esac
}

main "$@"
