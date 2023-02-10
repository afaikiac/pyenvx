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

function check_pyenv_in_path() {
	if ! command -v pyenv &>/dev/null; then
		die "'pyenv' not found. Please install it first."
	fi
}

function check_pyenv_virtualenv_module() {
	if ! command -v pyenv virtualenv &>/dev/null; then
		die "'pyenv virtualenv' not found. Please install it first."
	fi
}

function check_python() {
    local versions=("$@")
	if [ ${#versions[@]} -eq 0 ]; then
		die "No Python interpreters found. Please install one first."
	fi
}

function check_package_name() {
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

	if ! pyenv versions --bare | grep "$python_version" &>/dev/null; then
		die "Error: Python version '$python_version' not found"
	fi

	pyenv virtualenv "$python_version" "$venv_name" || die "Failed to create virtual environment"
	log "Virtual environment '$venv_name' was created"
}

function add_venv_to_global() {
	local venv_name=$1

	local global_envs
	global_envs=$(pyenv global)

	if ! echo "$global_envs" | grep -F "$venv_name" &>/dev/null; then
		pyenv global $global_envs $venv_name || die "Failed to add virtual environment to global"
		log "Virtual environment '$venv_name' now in global"
	else
		log "Virtual environment '$venv_name' already in global"
	fi
}

function remove_venv_from_global() {
	local venv_name=$1

	local global_envs
	global_envs=$(pyenv global)

	if echo "$global_envs" | grep -F "$venv_name" &>/dev/null; then
		global_envs=$(echo "$global_envs" | grep -v "$venv_name")
		pyenv global $global_envs || die "Failed to remove virtual environment '$venv_name' from global"
		log "Virtual environment '$venv_name' was removed from global"
	else
		log "There is no '$venv_name' virtual environment in global"
	fi
}

function install_package_in_venv() {
	local package=$1
	local venv_name=$2

	if ! pyenv virtualenvs --bare | grep "$venv_name" &>/dev/null; then
		die "Error: Virtual environment '$venv_name' doesn't exist"
	fi

	pyenv activate "$venv_name" || die "Failed to activate virtual environment '$venv_name'"
	pip install --upgrade "$package" || die "Failed to install and upgrade package '$package'"
	log "Package '$package' was installed successfully in '$venv_name' virtual environment"
	pyenv deactivate
}

function select_version() {
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

function get_python_versions() {
	pyenv versions --bare --skip-aliases | grep -v "/"
}

function install() {
	local package=$1
	local venv_name="$package"

	check_package_name "$package"

	if pyenv virtualenvs --bare | grep "$venv_name" &>/dev/null; then
		install_package_in_venv "$package" "$venv_name"
		add_venv_to_global "$venv_name"
	else
		local versions=($(get_python_versions))
		check_python "${versions[@]}"
		local python_version
		python_version=$(
			select_version \
				"Please enter the Python interpreter to use with '$package'" \
				"${versions[@]}"
		)
		create_venv "$venv_name" "$python_version"
		install_package_in_venv "$package" "$venv_name"
		add_venv_to_global "$venv_name"
	fi
}

function uninstall() {
	local venv_name=$1

	if pyenv virtualenvs --bare | grep "$venv_name" &>/dev/null; then
		remove_venv_from_global "$venv_name"
		pyenv virtualenv-delete "$venv_name" || die "Failed to delete virtual environment '$venv_name'"
		log "Virtual environment '$venv_name' was deleted successfully"
	else
		log "Virtual environment '$venv_name' doesn't exist"
	fi
}

function main() {
	check_pyenv_in_path
	check_pyenv_virtualenv_module

	eval "$(pyenv init -)"
	eval "$(pyenv virtualenv-init -)"

	local command=$1
	shift 1

	case "$command" in
	install)
		for package in "$@"; do
			install "$package"
		done
		;;
	uninstall)
		for venv_name in "$@"; do
			uninstall "$venv_name"
		done
		;;
	*)
		local script_name
		script_name=$(basename "$0")
		echo "Usage:"
		echo "$script_name install package_name [package_name ...]"
		echo "$script_name uninstall virtual_evironment_name [virtual_evironment_name ...]"
		exit 1
		;;
	esac
}

main "$@"
