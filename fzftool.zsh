## INSTALLATION & REQUIREMENTS

# This file needs to be sourced into your zsh shell, and tmux needs
# to be running before you can use it.
# See the Readme.org file for details of use & configuration.
# LICENSE: GNU GPL V3 (http://www.gnu.org/licenses)
# Bitcoin donations gratefully accepted: 1AmWPmshr6i9gajMi1yqHgx7BYzpPKuzMz

# NOTE: if fzftoolmenu is called recursively in a fzfrepl pipeline the final value printed after quitting
#       all called commands may not be what you expect. This is usually not a problem because you would
#       save the output using the final fzfrepl prompt (i.e. press alt-j, or press alt-v to view in PAGER
#       and save from there). I have looked into trying to fix it, but its complicated; I think the output
#       from an fzftoolmenu call is being printed to the prompt of the calling fzf process.
#       I cannot replicate this behaviour with a single fzf call, so it might be something to do with ptys
#       being shared between calls.

# TODO: for tools that dont use fzfrepl there should be a way of automatically going back to fzftool menu
#       to choose next tool in pipeline
# TODO: add option/keybinding to prevent live updating of preview window 
# TODO: change name? this website says not to use "tool" in command names: https://smallstep.com/blog/the-poetics-of-cli-command-names/
# TODO: allow handling files separately when multiple files are selected: C-v should call "less FILE1 FILE2..." so that :n/:p can be
#       used to change files viewed, and there should be a keybinding to quickly change the current input file for the main view
# TODO: allow scoping in pre-defined environmental variables, e.g. (regexps in regex-collection.zsh)
# TODO: look at this https://jvns.ca/blog/2024/11/29/why-pipes-get-stuck-buffering/
# TODO: manpage?
function fzftoolmenu() {
    if [[ $# -lt 1 || "${@[(I)-h|--help]}" -gt 0 ]]; then
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
    local header1="ctrl-g:quit|enter:run in ${dfltwin//e(val|xec)/this window}|alt-1:run in ${win1}|alt-2:run in ${win2}|ctrl-v:view raw file|alt-v:view formatted file|alt-h:show help for selected tool|alt-a:show files menu"
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
    # Quote sources/args
    local sources="${${@/%/\"}[@]/#/\"}"
    # Replace "-" arg with STDIN
    local tempfile="${FZFREPL_DATADIR:-${TMPDIR:-/tmp}}/fzftool-$$.in"
    if [[ ${sources} == *\"-\"* ]]; then
	if [[ -t 0 ]]; then
	    print -u2 "Error: no command or input supplied."
	    return 1
	else
	    cat > ${tempfile}
	    sources=${sources//\"-\"/${tempfile}}
	fi
    fi
    # Feed tools menu to fzf
    sed -e '/#/d;/^\s*\$/d' -e "s#{}#${sources}#g" "${toolsmenu}" | \
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
    	    --bind="enter:execute(${windowcmds[${dfltwin}]})+abort" \
	    --bind="alt-a:execute(source ${FZFTOOL_SRC} && fzftool ${sources} \
	    				 ${FZFREPL_DATADIR:-${TMPDIR:-/tmp}}/fzfrepl-*.out(N))+abort"
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
    local header1="ctrl-g:quit|enter:tools menu|ctrl-j:print filename|ctrl-v:view raw|alt-v:view formatted|alt-a:add fzfrepl output files"
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
    # Replace "-" arg with STDIN
    typeset -a args=(${@})
    local tempfile="${FZFREPL_DATADIR:-${TMPDIR:-/tmp}}/fzftool-$$.in"
    if [[ -n ${args[(r)(#s)-(#e)]} ]]; then
	cat > "${tempfile}"
	args[(i)(#s)-(#e)]="${tempfile}"
    fi
    # Feed input to fzf
    if [[ ${#args} -eq 1 ]]; then
	fzftoolmenu "${args}"
    else
	# reload action needs args to be quoted to prevent splitting at whitespace.
	# Also add any fzfrepl output files that aren't already there
	typeset -a args2=(${${${args/%/\"}[@]/#/\"}:#\"${FZFREPL_DATADIR:-${TMPDIR:-/tmp}}/fzfrepl-*.out\"})
	print -l ${args[*]} |fzf --height=100% \
				 --header="${header2}" \
				 --preview="stat -c 'SIZE:%s bytes OWNER:%U GROUP:%G PERMS:%A' {} && ${preview}" \
				 --bind="alt-a:reload(print -l ${args2[*]} ${FZFREPL_DATADIR:-${TMPDIR:-/tmp}}/fzfrepl-*.out(N))" \
				 --bind="alt-V:execute(${PAGER} {} >&2)" \
				 --bind="alt-v:execute({${preview}}|${PAGER} >&2)" \
				 --bind="ctrl-j:accept" \
				 --bind="enter:execute(source ${FZFTOOL_SRC} && fzftoolmenu {+})"
    fi
}
