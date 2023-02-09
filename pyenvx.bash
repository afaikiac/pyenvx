#!/usr/bin/env bash

set -euo pipefail

log() {
	echo "$(date +"%Y-%m-%d %T") [$(basename "$0")] $1"
}

die() {
	log "$@"
	exit 1
}

check_pyenv_in_path() {
	if ! command -v pyenv &>/dev/null; then
		die "'pyenv' not found. Please install it first."
	fi
}

check_pyenv_virtualenv_module() {
	if ! command -v pyenv virtualenv &>/dev/null; then
		die "'pyenv virtualenv' not found. Please install it first."
	fi
}

check_pip_in_path() {
	if ! command -v pip &>/dev/null; then
		die "'pip' not found. Please install it first."
	fi
}

create_venv() {
	local venv_name=$1
	local python_version=$2

	if ! pyenv versions --bare | grep "$python_version" &>/dev/null; then
		die "Error: Python version '$python_version' not found"
	fi

	pyenv virtualenv "$python_version" "$venv_name" || die "Failed to create virtual environment"
	log "Virtual environment '$venv_name' was created"
}

add_venv_to_global() {
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

remove_venv_from_global() {
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

install_package_in_venv() {
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

check_package_name() {
	local package=$1

	check_pip_in_path

	if ! pip index versions "$package" &>/dev/null; then
		die "Package '$package' not found in PyPI"
	fi
	log "Package '$package' found in PyPI"
}

install() {
	local package=$1
	local python_version=$2
	local venv_name="$package-$python_version"

	# it's possible to do it in venv
    # and ecxclude pip dependency
	check_package_name "$package"

	if pyenv virtualenvs --bare | grep "$venv_name" &>/dev/null; then
		install_package_in_venv "$package" "$venv_name"
	else
		create_venv "$venv_name" "$python_version"
		install_package_in_venv "$package" "$venv_name"
		add_venv_to_global "$venv_name"
	fi
}

uninstall() {
	local venv_name=$1

	if pyenv virtualenvs --bare | grep "$venv_name" &>/dev/null; then
		remove_venv_from_global "$venv_name"
		pyenv virtualenv-delete "$venv_name" || die "Failed to delete virtual environment '$venv_name'"
		log "Virtual environment '$venv_name' was deleted successfully"
	else
		log "Virtual environment '$venv_name' doesn't exist"
	fi
}

main() {
	check_pyenv_in_path
	check_pyenv_virtualenv_module

	eval "$(pyenv init -)"
	eval "$(pyenv virtualenv-init -)"

	local command=$1
	shift 1

	case "$command" in
	install)
		local python_version=$1
		shift 1
		pyenv install --skip-existing "$python_version" || die "Failed to install python version"
		for package in "$@"; do
			install "$package" "$python_version"
		done
		;;
	uninstall)
		for venv_name in "$@"; do
			uninstall "$venv_name"
		done
		;;
	*)
		echo "Usage:"
		echo "    $0 install python_version package_name [package_name ...]"
		echo "    $0 uninstall virtual_evironment_name [virtual_evironment_name ...]"
		exit 1
		;;
	esac
}

main "$@"
