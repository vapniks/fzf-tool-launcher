## INSTALLATION & REQUIREMENTS

# This file needs to be sourced into your zsh shell, and tmux needs
# to be running before you can use it.
# See the Readme.org file for details of use & configuration.
# LICENSE: GNU GPL V3 (http://www.gnu.org/licenses)
# Bitcoin donations gratefully accepted: 1AmWPmshr6i9gajMi1yqHgx7BYzpPKuzMz

# TODO: accept STDIN as an alternative to a file arg?
function fzftoolmenu() {
    if [[ "${#}" -lt 1 || "${@[(I)-h|--help]}" -gt 0 ]]; then
	print "Usage: fzftoolmenu <FILE>
Select program for processing file."
	return
    fi
    local toolsmenu 
    zstyle -s ':fzftool:' tools_menu_file toolsmenu || toolsmenu="${HOME}/.fzfrepl/tools_menu"
    # Commands for running tool in different types of window
    typeset -A windowcmds
    typeset cmdstr="{2..}"
    typeset kittycmd="eval \"kitty @launch --type XXX --env PAGER=${PAGER} --env LESS=${LESS} --env FZF_DEFAULT_OPTS=\${(q)FZF_DEFAULT_OPTS} --env FZFREPL_DEFAULT_OPTS=\${(q)FZFREPL_DEFAULT_OPTS} --env FZFREPL_DEFAULT_OPTS=\${(q)FZFREPL_DEFAULT_OPTS} \$(echo {2..})\""    
    windowcmds[kitty_tab]="${kittycmd//XXX/tab}"
    windowcmds[kitty_win]="${kittycmd//XXX/window}"
    windowcmds[tmux_win]="tmux new-window -n '$(basename ${1})' -d \"{2..}\""
    windowcmds[tmux_pane]="tmux split-window -d \"{2..}\""
    # Note: xterm command must be followed by & to allow file menu to still be usable after forking a tool menu
    windowcmds[xterm]="xterm -T '$(basename ${1})' -e \"{2..}\" &"
    windowcmds[eval]="eval {2..}"
    windowcmds[exec]="exec {2..}"
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
    # Command for viewing the files formatted
    typeset viewfile 
    typeset -a filetypes
    zstyle -g filetypes ':fzftool:previewcmd:'
    viewfile="${PAGER} ${1}"
    if [[ ${#filetypes} -gt 0 ]]; then
	local t tmp
        foreach t (${filetypes}) {
	    zstyle -s ':fzftool:previewcmd:' "${t}" tmp
	    if [[ "${1}" == *${t} ]]; then
		viewfile="${tmp//\{\}/${1}}|${PAGER}"
		break
	    fi
	}
    fi
    # Fit header to screen
    local header1="ctrl-g:quit|enter:run in ${dfltwin//e(val|xec)/this window}|alt-1:run in ${win1}|alt-2:run in ${win2}|ctrl-v:view raw file|alt-v:view formatted file|alt-h:show help for selected tool"
    local header2 i1=0 ncols=$((COLUMNS-5))
    local i2=${ncols}
    until ((i2>${#header1})); do
	i2=${${header1[${i1:-0},${i2}]}[(I)\|]}
	header2+="${header1[${i1},((i1+i2-1))]}
"
	i1=$((i1+i2+1))
	i2=$((i1+ncols))
    done
    header2+=${header1[$i1,$i2]}
    # Command to show tool manpage
    local helpcmd="man \$(print {1}|cut -f1 -d\:) >&2||{eval \"\$(print {1}|cut -f1 -d\:) --help\" >&2}|less"
    # Feed tools menu to fzf, after substituting {} for quoted file args
    local fileargs="${${@/%/\"}[@]/#/\"}"
    sed -e '/#/d;/^\s*\$/d' -e "s#{}#${fileargs}#g" "${toolsmenu}" | \
    	fzf --with-nth=1 --preview-window=down:3:wrap \
    	    --height=100% \
    	    --header="${header2}" \
    	    --preview='echo {2..}' \
	    --prompt='> ' \
    	    --bind="alt-h:execute(${helpcmd})" \
    	    --bind="alt-v:execute(${viewfile} >&2)" \
    	    --bind="ctrl-v:execute(${PAGER} ${*} >&2)" \
    	    --bind="alt-1:execute(${windowcmds[${win1}]})+abort" \
    	    --bind="alt-2:execute(${windowcmds[${win2}]})+abort" \
    	    --bind="enter:execute(${windowcmds[${dfltwin}]})+abort"
}

function fzftool() {
    typeset -gx FZFTOOL_SRC="${FZFTOOL_SRC:-${funcsourcetrace[1]%%:[0-9]##}}"

    if [[ "${#}" -lt 1 || "${@[(I)-h|--help]}" -gt 0 ]]; then
	print "Usage: fzftool <FILES>...
Preview & select file(s) to be processed, and program(s) to do the processing."
	return
    fi
    typeset preview maxsize 
    typeset -a filetypes
    zstyle -g filetypes ':fzftool:previewcmd:'
    zstyle -s ':fzftool:' max_preview_size maxsize || maxsize=10000000
    local condstr="[ \$(stat -c '%s' {}) -gt ${maxsize} ]"
    if [[ ${#filetypes} -gt 0 ]]; then
	preview='f={} && if'
	local t tmp
        foreach t (${filetypes}) {
	    zstyle -s ':fzftool:previewcmd:' "${t}" tmp
	    preview+=" [ -z \"\${f%%*${t}}\" ];then ${tmp};elif"
	    preview+=" [ -z \"\${f%%*${t:u}}\" ];then ${tmp};elif"
	    preview+=" [ -z \"\${f%%*${(C)t}}\" ];then ${tmp};elif"
	}
	preview="if ${condstr};then head -c${maxsize} {};echo \"\n\nTRUNCATED TO FIRST ${maxsize} BYTES\";else {${preview%%elif}else cat {};fi||cat {}};fi"
    else
	preview="cat {}"
    fi
    # Fit header to fit screen
    local header1="ctrl-g:quit|enter:tools menu|ctrl-j:print filename|ctrl-v:view raw|alt-v:view formatted"
    local header2 i1=0 ncols=$((COLUMNS-5))
    local i2=${ncols}
    until ((i2>${#header1})); do
	i2=${${header1[${i1:-0},${i2}]}[(I)|]}
	header2+="${header1[${i1},((i1+i2-1))]}
"
	i1=$((i1+i2+1))
	i2=$((i1+ncols))
    done
    header2+=${header1[$i1,$i2]}
    # Feed input to fzf
    if [[ $# -eq 1 ]]; then
	fzftoolmenu ${@}
    else
	print -l ${@}|fzf --height=100% \
			  --header="${header2}" \
			  --preview="stat -c 'SIZE:%s bytes OWNER:%U GROUP:%G PERMS:%A' {} && ${preview}" \
			  --bind="alt-a:reload(print -l ${*} ${FZFREPL_DATADIR:-${TMPDIR:-/tmp}}/fzfrepl-*.out)" \
			  --bind="ctrl-v:execute(${PAGER} {} >&2)" \
			  --bind="alt-v:execute({${preview}}|${PAGER} >&2)" \
			  --bind="ctrl-j:accept" \
			  --bind="enter:execute(source ${FZFTOOL_SRC} && fzftoolmenu {+})"
    fi
}
