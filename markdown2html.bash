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
		'-O'|'--output-file')
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
inside_fenced_codeblock_power=
indented_codeblock_buffer=()



trim_whitespace(){
	local -n 'trim_whitespace__str='"$1"
	trim_whitespace__str="${trim_whitespace__str#"${trim_whitespace__str%%[^[:space:]]*}"}"
	trim_whitespace__str="${trim_whitespace__str%"${trim_whitespace__str##*[^[:space:]]}"}"
}



html_encode() {
	local -n 'html_encode__str='"$1"
	html_encode__str=${html_encode__str//'&'/'&amp;'}
	html_encode__str=${html_encode__str//'<'/'&lt;'}
	html_encode__str=${html_encode__str//'>'/'&gt;'}
}



html_encode_incl_quotes(){
	local -n 'html_encode_incl_quotes__str='"$1"
	html_encode_incl_quotes__str=${html_encode_incl_quotes__str//'&'/'&amp;'}
	html_encode_incl_quotes__str=${html_encode_incl_quotes__str//'<'/'&lt;'}
	html_encode_incl_quotes__str=${html_encode_incl_quotes__str//'>'/'&gt;'}
	html_encode_incl_quotes__str=${html_encode_incl_quotes__str//'"'/'&#34;'}
	html_encode_incl_quotes__str=${html_encode_incl_quotes__str//"'"/'&#39;'}
}



line_is_fenced_codeblock_syntax() {
	# Test if the line is a codeblock
	[[ $line == '```'* ]] || return 1

	# Assign codeblock's power and lang
	local re='^(`+)[[:blank:]]*([^[:blank:]]*)'
	[[ $line =~ $re ]]
	fenced_codeblock_power=${#BASH_REMATCH[1]}
	fenced_codeblock_lang=${BASH_REMATCH[2]}
	[[ $fenced_codeblock_lang ]] && html_encode fenced_codeblock_lang

	return 0
}



handle_indented_codeblocks() {
	local re

	if [[ $inside_type != 'indented_codeblock' ]]; then
		re='^(    | ? ? ?	)([[:blank:]]*[^[:blank:]].*)'
		[[ $line =~ $re ]] || return 1

		# New codeblock
		open_inside_type 'indented_codeblock'

		local code_str=${BASH_REMATCH[2]}
		html_encode_incl_quotes code_str
		html_line_arr+=("$code_str")
		indented_codeblock_buffer=()
		return 0
	fi

	re='^(    | ? ? ?	)(.+)|^[[:blank:]]*$'
	if [[ ! $line =~ $re ]]; then

		# Close existing codeblock
		indented_codeblock_buffer=()
		close_current_inside_type
		return 1
	fi

	# Continue existing codeblock
	local code_str=${BASH_REMATCH[2]}

	if [[ ! $code_str ]]; then
		indented_codeblock_buffer+=('')
		return 0
	fi

	html_encode code_str
	html_line_arr+=("${indented_codeblock_buffer[@]}" "$code_str")
	indented_codeblock_buffer=()
	return 0
}



handle_headers() {
	local header_re='^(##?#?#?#?#?)[[:blank:]][[:blank:]]*(.*)'

	[[ $line == \#* ]] || return 1
	[[ $line =~ $header_re ]] || return 1
	local \
		header_level=${#BASH_REMATCH[1]} \
		header_text=${BASH_REMATCH[2]}

	# Handle trailing #s, spaces and tabs if they exist
	header_tail=${header_text##*[![:blank:]#]}
	if [[ $header_tail ]]; then

		# Remove tail from text
		header_text=${header_text%"$header_tail"}

		# Append tail to text allowing leading #s
		header_text+=${header_tail%%[[:blank:]]*}
	fi

	html_line_arr+=("<h${header_level}>${header_text}</h${header_level}>")

	return 0
}



handle_alt_headers() {
	local alt_header_re='^[[:blank:]]*([=]+|[-]+)[[:blank:]]*$'

	# Extract alt-header syntax from the following line if any
	[[ ${line_arr[line_num+1]} =~ $alt_header_re ]] || return 1
	[[ ${BASH_REMATCH[1]} == '='* ]] && local h_level=1 || local h_level=2
	html_line_arr+=("<h${h_level}>${line}</h${h_level}>")
	skip_next_line=1
	return 0
}



open_inside_type() {
	inside_type=$1
	case $inside_type in
		'paragraph')
			html_line_arr+=('<p>')
			;;
		'fenced_codeblock')
			local code_tag_append

			[[ $fenced_codeblock_power ]] || print_stderr 1 '%s\n' 'open_inside_type() $fenced_codeblock_power missing'
			inside_fenced_codeblock_power=$fenced_codeblock_power

			# If a lang was specified prepare a class attribute
			[[ $fenced_codeblock_lang ]] && code_tag_append=' class="language-'$fenced_codeblock_lang'"'

			html_line_arr+=('<pre><code'"$code_tag_append"'>')
			;;
		'indented_codeblock')
			html_line_arr+=('<pre><code>')
			;;			
		*)
			print_stderr 1 '%s\n' 'open_inside_type() unknown $inside_type: '"$inside_type"
	esac
}



close_current_inside_type() {
	case $inside_type in
		'paragraph')
			html_line_arr+=('</p>')
			;;
		'fenced_codeblock')
			inside_fenced_codeblock_power=
			html_line_arr+=('</code></pre>')
			;;
		'indented_codeblock')
			html_line_arr+=('</code></pre>')
			;;
	esac
	inside_type=
}



# Format into HTML
skip_next_line=
line_num=-1
for line in "${line_arr[@]}"; do
	(( line_num++ )) || :
	[[ $skip_next_line ]] && skip_next_line= && continue

	if line_is_fenced_codeblock_syntax; then
		if [[ $inside_type == 'fenced_codeblock' ]]; then

			# Ending a fenced_codeblock requires the same number of backticks used to start it.
			if [[ $fenced_codeblock_power == $inside_fenced_codeblock_power ]]; then

				# Fenced codeblock ends
				close_current_inside_type
				continue
			fi

			# Line is code
			html_encode 'line'
			html_line_arr+=("$line")
			continue
		fi

		# Fenced codeblock starts
		open_inside_type 'fenced_codeblock'
		continue
	fi

	if [[ $inside_type == 'fenced_codeblock' ]]; then

		# Line is code
		html_encode 'line'
		html_line_arr+=("$line")
		continue
	fi


	handle_indented_codeblocks && continue


	handle_headers && continue
	handle_alt_headers && continue


	# Line is paragraph related beyond this point
	if [[ ! $line ]]; then
		close_current_inside_type		
		continue
	fi

	[[ ! $inside_type == 'paragraph' ]] && open_inside_type 'paragraph'
	trim_whitespace line
	html_line_arr+=("$line"'<br />')

done



# Wrap up enclosures and print formatted HTML
close_current_inside_type
printf '%s\n' "${html_line_arr[@]}" > "$out_path"



