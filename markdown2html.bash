#!/usr/bin/env bash
# License: GNU Affero General Public License Version 3 (GNU AGPLv3), (c) 2023, Marc Gilligan <marcg@ulfnic.com>
[[ $DEBUG ]] && set -x
set -o errexit


help_doc() {
	cat <<-'HelpDoc'

	HelpDoc
	[[ $1 ]] && exit "$1"
}



print_stderr() {
	if [[ $1 == '0' ]]; then
		[[ $2 ]] && printf "$2" "${@:3}" 1>&2 || :
	else
		[[ $2 ]] && printf '%s'"$2" "ERROR: ${0##*/}, " "${@:3}" 1>&2 || :
		exit "$1"
	fi
}



[[ $1 ]] || help_doc 0
while [[ $1 ]]; do
	case $1 in
		'--help'|'-h')
			help_doc 0 ;;
		'--')
			shift; break ;;
		'-'*)
			print_stderr 1 '%s\n' 'unrecognized parameter: '"$1" ;;
	esac
	shift
done



