write_in_expect_out() {

	IFS= read -r -d $'\0' received_out < <(./markdown2html.bash <(printf '%s' "$write_in"); printf '\0')

	[[ $received_out == "$expect_out" ]] && return 0

	cat <<-EOF
	TEST ERROR: ${BASH_SOURCE[0]}, unexpected output
	===> Sent
	${write_in}
	===> Expected
	${expect_out}
	===> Received
	${received_out}
	EOF

	return 1
}
