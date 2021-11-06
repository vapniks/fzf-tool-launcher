## INSTALLATION & REQUIREMENTS

# This file needs to be sourced into your zsh shell, and tmux needs
# to be running before you can use it.
# See the Readme.org file for details of use & configuration.
# LICENSE: GNU GPL V3 (http://www.gnu.org/licenses)
# Bitcoin donations gratefully accepted: 1AmWPmshr6i9gajMi1yqHgx7BYzpPKuzMz

function fzf-tool-launcher() {
    [[ ${SHELL} =~ zsh ]] || { echo "This function only works with zsh"; return 1 }
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
	    preview+=" [ -z \"\${f%%*${t:u}}\" ];then ${tmp};elif"
	    preview+=" [ -z \"\${f%%*${(C)t}}\" ];then ${tmp};elif"
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
    # Also $tools doesn't work if {} (the selected filename) contains spaces due to same reasons stated above.
    #tools="sed '/#/d;/^\s*\$/d' ${toolsmenu}|fzf --with-nth=1 --preview-window=down:3:wrap --preview='echo \{2..}|sed -e s@\{\}@{}@g -e s@\{\+\}@\"{+}\"@g' --bind='enter:execute(tmux new-window -n test -d \"\$(echo \{2..}|sed -e s@\{\}@{}@g)\")'"

    # NOTE: TRY $'' quoting to fix problem noted above, also maybe setting RC_QUOTES might help?

    # TODO: either in this function, or in fzfrepl, add keybinding to pipe output to new/existing tool window
    #       imagine having different frames in the same window all working on the same initial file...

    typeset -A windowcmds
    typeset cmdstr="\$(echo \{2..}|sed s@\{\}@{}@)"
    windowcmds[tmux_win]="tmux new-window -n \$(basename {}) -d \"${cmdstr}\""
    windowcmds[tmux_pane]="tmux split-window -d \"${cmdstr}\""
    typeset kittycmd="eval \"kitty @launch --type XXX --env PAGER=\${(q)PAGER} --env LESS=\${(q)LESS} --env FZF_DEFAULT_OPTS=\${(q)FZF_DEFAULT_OPTS} --env FZFREPL_DEFAULT_OPTS=\${(q)FZFREPL_DEFAULT_OPTS} ${cmdstr}\""
    windowcmds[kitty_tab]="${kittycmd//XXX/tab}"
    windowcmds[kitty_win]="${kittycmd//XXX/window}"
    # Note: xterm command must use -T option to allow file menu to still be usable after forking a tool menu
    windowcmds[xterm]="xterm -T \$(basename {}) -e \"${cmdstr}\" &"
    windowcmds[eval]="eval ${cmdstr}"
    windowcmds[exec]="exec ${cmdstr}"

    typeset dfltwin win1 win2
    dfltwin=${FZFTOOL_WINDOW:-eval}
    if [[ -n ${TMUX} ]]; then
	win1=${FZFTOOL_WIN1:-tmux_win}
	win2=${FZFTOOL_WIN2:-tmux_pane}
    elif [[ ${TERM} == *kitty* ]]; then
	win1=${FZFTOOL_WIN1:-kitty_tab}
	win2=${FZFTOOL_WIN2:-kitty_win}
    elif [[ ${TERM} == *xterm* ]]; then
	win1=${FZFTOOL_WIN1:-xterm}
	win2=${FZFTOOL_WIN2:-xterm}
    else
	win1=${FZFTOOL_WIN1:-eval}
	win2=${FZFTOOL_WIN2:-eval}
    fi
    
    tools="sed '/#/d;/^\s*\$/d' ${toolsmenu}|fzf --with-nth=1 --preview-window=down:3:wrap --preview='echo \{2..}|sed s@\{\}@{}@'  --bind='enter:execute(XXX)'"
    local file=$(print -l ${@}|fzf --height=100% \
				   --header="${header}" \
				   --preview="stat -c 'SIZE:%s bytes OWNER:%U GROUP:%G PERMS:%A' {} && ${preview}" \
				   --bind="ctrl-v:execute(less {} >&2)" \
				   --bind="alt-v:execute({${preview}}|less >&2)" \
				   --bind="ctrl-j:accept" \
				   --bind="alt-1:execute(${tools//XXX/${windowcmds[${win1}]}})" \
				   --bind="alt-2:execute(${tools//XXX/${windowcmds[${win2}]}})" \
				   --bind="enter:execute(${tools//XXX/${windowcmds[${dfltwin}]}})")
    local -a lines
    lines=("${(@f)file}")
    print ${lines[-1]}
}
