## INSTALLATION & REQUIREMENTS

# This file needs to be sourced into your zsh shell, and tmux needs
# to be running before you can use it.
# See the Readme.org file for details of use & configuration.
# LICENSE: GNU GPL V3 (http://www.gnu.org/licenses)

function fzf-tool-launcher() {
    [[ ${SHELL} =~ zsh ]] || { echo "This function only works with zsh"; return 1 }
    if ! { which tmux >/dev/null && tmux list-sessions >/dev/null }; then
	print "No available tmux sessions"
	return 1
    fi
    typeset preview tools maxsize k v
    typeset -a filetypes
    zstyle -g filetypes ':fzf-tool-launcher:previewcmd:'
    zstyle -s ':fzf-tool-launcher:' max_preview_size maxsize || maxsize=10000000
    local condstr="[ \$(stat -c '%s' {}) -gt ${maxsize} ]"
    if [[ ${#filetypes} -gt 0 ]]; then
	preview='f={} && if'
	local t tmp
        foreach t (${filetypes}) {
	    zstyle -s ':fzf-tool-launcher:previewcmd:' "${t}" tmp
	    preview+=" [ -z \"\${f%%*${t}}\" ];then ${tmp};elif"
	}
	preview="if ${condstr};then head -c${maxsize} {};echo \"\n\nTRUNCATED TO FIRST ${maxsize} BYTES\";else {${preview%%elif}else cat {};fi||cat {}};fi"
    else
	preview="cat {}"
    fi
    local header="ctrl-g=quit:ctrl-v=view raw:alt-v=view formatted:enter=choose tool:ctrl-j=print filename"
    local toolsmenu 
    zstyle -s ':fzf-tool-launcher:' tools_menu_file toolsmenu || toolsmenu="~/.fzfrepl/tools_menu"
    # TODO: try to get {+} replacements working. Have tried all different kinds of quoting combinations, but none seem to work.
    # The substitution works for the --preview option, but not the --bind option. To get it to work for the --preview option
    # you have to quote the {+} replacement in the sed command, otherwise it introduces spaces which makes sed think the command
    # is incomplete. However, when I try the same thing with the --bind command it doesn't work; fzf emits an "unknown action" error,
    # followed by the text right after the +. fzf treats the + as an action separator (used for chaining commnds, see the docs).
    #tools="sed '/#/d;/^\s*\$/d' ${toolsmenu}|fzf --with-nth=1 --preview-window=down:3:wrap --preview='echo \{2..}|sed -e s@\{\}@{}@g -e s@\{\+\}@\"{+}\"@g' --bind='enter:execute(tmux new-window -n test -d \"\$(echo \{2..}|sed -e s@\{\}@{}@g)\")'"

    tools="sed '/#/d;/^\s*\$/d' ${toolsmenu}|fzf --with-nth=1 --preview-window=down:3:wrap --preview='echo \{2..}|sed s@\{\}@{}@' --bind='enter:execute(tmux new-window -n \$(basename {}) -d \"\$(echo \{2..}|sed s@\{\}@{}@)\")'"
    local file=$(print -l ${@}|fzf --height=100% \
				   --header="${header}" \
				   --preview="stat -c 'SIZE:%s bytes OWNER:%U GROUP:%G PERMS:%A' {} && ${preview}" \
				   --bind="ctrl-v:execute(less {} >&2)" \
				   --bind="alt-v:execute({${preview}}|less >&2)" \
				   --bind="ctrl-j:accept" \
				   --bind="enter:execute(${tools})")
    local -a lines
    lines=("${(@f)file}")
    print ${lines[-1]}
}
