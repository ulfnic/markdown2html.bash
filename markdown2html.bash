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



# Define variables and functions
html_line_arr=()
inside_type=
inside_codeblock_power=



html_encode() {
	local -n html_encode__str=$1
	html_encode__str=${html_encode__str//'&'/'&amp;'}
	html_encode__str=${html_encode__str//'<'/'&lt;'}
	html_encode__str=${html_encode__str//'>'/'&gt;'}
}



line_is_codeblock_syntax() {
	[[ $line == '```'* ]] || return 1
	[[ ${line//'`'/} ]] && return 1
	codeblock_power=${#line}
	return 0
}



open_inside_type() {
	inside_type=$1
	case $inside_type in
		'codeblock')
			[[ $codeblock_power ]] || print_stderr 1 '%s\n' 'open_inside_type() $codeblock_power missing'
			inside_codeblock_power=$codeblock_power
			html_line_arr+=('<pre><code>')
			;;
		*)
			print_stderr 1 '%s\n' 'open_inside_type() unknown $inside_type: '"$inside_type"
	esac
}



close_current_inside_type() {
	case $inside_type in
		'codeblock')
			inside_codeblock_power=
			html_line_arr+=('</code></pre>')
			;;
	esac
	inside_type=
}



# Format into HTML
for line in "${line_arr[@]}"; do

	if line_is_codeblock_syntax; then
		if [[ $inside_type == 'codeblock' ]]; then

			# Ending a codeblock requires the same number of backticks used to start it.
			if [[ $codeblock_power == $inside_codeblock_power ]]; then

				# Codeblock ends
				close_current_inside_type
				continue
			fi

			# Line is code
			html_encode 'line'
			html_line_arr+=("$line")
			continue
		fi

		# Codeblock starts
		open_inside_type 'codeblock'
		continue
	fi

	if [[ $inside_type == 'codeblock' ]]; then

		# Line is code
		html_encode 'line'
		html_line_arr+=("$line")
		continue
	fi

	html_line_arr+=("$line"'<br />')

done



# Wrap up enclosures and print formatted HTML
close_current_inside_type
printf '%s\n' "${html_line_arr[@]}" > "$out_path"



