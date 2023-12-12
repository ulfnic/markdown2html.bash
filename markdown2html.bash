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



in_path=
out_path='/dev/fd/1'
[[ $1 ]] || help_doc 0
while [[ $1 ]]; do
	case $1 in
		'-O')
			shift; [[ $1 == '-' ]] && out_path='/dev/fd/1' || out_path=$1
			;;
		'--help'|'-h')
			help_doc 0 ;;
		'--')
			shift; break ;;
		'-'?*)
			print_stderr 1 '%s\n' 'unrecognized parameter: '"$1" ;;
		*)
			[[ $1 == '-' ]] && in_path='/dev/fd/0' || in_path=$1 ;;
	esac
	shift
done
[[ $1 ]] && in_path=$1
[[ $2 ]] && print_stderr 1 '%s\n' 'unrecognized parameter: '"$2"



# Validate and convert param values
[[ $in_path == '/dev/fd/'* ]] || [[ -f $in_path ]] || print_stderr 1 '%s\n' 'bad input filepath: '"$in_path"
[[ $out_path == '/dev/fd/'* ]] || [[ -f $out_path ]] || print_stderr 1 '%s\n' 'bad output filepath: '"$in_path"



# Read input file
readarray -t line_arr < "$in_path"



