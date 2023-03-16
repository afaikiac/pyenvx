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

function is_venv_in_global() {
	local venv_name=$1
	pyenv global | grep "^$venv_name$" &>/dev/null
}

function add_venv_to_global() {
	local venv_name=$1
	pyenv global $(pyenv global) $venv_name
}

function remove_venv_from_global() {
	local venv_name=$1
	pyenv global $(pyenv global | grep -v "^$venv_name$")
}

function prompt_select_version() {
	local prompt_text=$1
	shift 1
	local versions=("$@")

	print "$prompt_text"
	for i in "${!versions[@]}"; do
		print "$i. ${versions[i]}"
	done

	local chosen_version
	local default_selected=$((${#versions[@]} - 1))
	while true; do
		read -p "Please select ($default_selected): " selected
		if [ -z "$selected" ]; then
			selected=$default_selected
		fi

		if [ "$selected" -ge 0 ] 2>/dev/null && [ "$selected" -lt "${#versions[@]}" ] 2>/dev/null; then
			chosen_version="${versions[selected]}"
			break
		else
			print "Invalid selection. Please try again."
		fi
	done

	echo "$chosen_version"
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

	create_venv "$venv_name" "$python_version"
	install_package_in_venv "$package" "$venv_name"
	if ! is_venv_in_global "$venv_name"; then
		add_venv_to_global "$venv_name"
	fi
}

function update() {
	local package=$1
	local venv_name=$2

	install_package_in_venv "$package" "$venv_name"
	if ! is_venv_in_global "$venv_name"; then
		add_venv_to_global "$venv_name"
	fi
}

function uninstall() {
	local venv_name=$1

	if is_venv_in_global "$venv_name"; then
		remove_venv_from_global "$venv_name"
	fi
	pyenv virtualenv-delete --force "$venv_name"
	log "Virtual environment '$venv_name' was uninstalled"
}

function setup_pyenv_or_die() {
	verify_pyenv_in_path_or_die
	verify_pyenv_virtualenv_module_or_die

	eval "$(pyenv init -)"
	eval "$(pyenv virtualenv-init -)"
}

function print_help() {
	print "$(basename "$0") 2.0.0-beta"
	print
    print "Some useful pyenvx commands are:"
	print "   install   package [package ...]"
	print "   update    package [package ...]"
	print "   uninstall package [package ...]"
}

function main() {
	setup_pyenv_or_die

	if [ $# -eq 0 ]; then
		print_help
		exit 1
	fi

	local VENV_PREFIX="pyenvx-"
	# local VENV_PREFIX=""

	local command=$1
	shift 1

	case "$command" in
	install)
		for package in "$@"; do
			verify_package_name_or_die "$package"
			local venv_name="$VENV_PREFIX$package"
			if ! is_virtualenv "$venv_name"; then
				local python_versions=($(get_python_versions_or_die))
				local python_version
				python_version=$(
					prompt_select_version \
						"Please enter the Python interpreter to use with '$package'" \
						"${python_versions[@]}"
				)
				install "$package" "$venv_name" "$python_version"
			else
				update "$package" "$venv_name"
			fi
		done
		;;
	update)
		for package in "$@"; do
			local venv_name="$VENV_PREFIX$package"
			if is_virtualenv "$venv_name"; then
				update "$package" "$venv_name"
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
	*)
		print_help
		exit 1
		;;
	esac
}

main "$@"
