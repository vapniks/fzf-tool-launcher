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
    typeset preview='f={} && if' tools='f={} && if' k v
    typeset -a filetypes
    zstyle -g filetypes ':fzf-tools-launcher:previewcmd:'
    local maxsize t tmp
    zstyle -s ':fzf-tools-launcher:' max_preview_size maxsize || maxsize=10000000
    foreach t (${filetypes}) {
	zstyle -s ':fzf-tools-launcher:previewcmd:' "${t}" tmp
	preview+=" [ -z \"\${f%%*${t}}\" ];then ${tmp};elif"
    }
    local condstr="[ \$(stat -c '%s' {}) -gt ${maxsize} ]"
    preview="if ${condstr};then head -c${maxsize} {};echo \"\n\nTRUNCATED TO FIRST ${maxsize} BYTES\";else {${preview%%elif}else cat {};fi||cat {}};fi"
    local header="ctrl-g=quit:ctrl-v=view raw:alt-v=view formatted:enter=choose tool:ctrl-j=print filename"
    local toolsmenu 
    zstyle -s ':fzf-tools-launcher:' toolsmenu toolsmenu || toolsmenu="~/.fzfrepl/tools_menu"
    tools="sed '/#/d;/^\s*\$/d' ${toolsmenu}|fzf --with-nth=1 --preview-window=down:3:wrap --preview='echo \{2..}|sed s@\{\}@{}@' --bind='enter:execute(tmux new-window -n \$(basename {}) -d \"\$(echo \{2..}|sed s@\{\}@{}@)\")'"
    
    local file=$(print -l ${@}|fzf --height=100% \
				   --header="${header}" \
				   --preview="stat -c 'SIZE:%s bytes OWNER:%U GROUP:%G PERMS:%A' {} && {if ${condstr};then echo \"RAW:\";else echo \"FORMATTED:\";fi} && ${preview}" \
				   --bind="ctrl-v:execute(less {} >&2)" \
				   --bind="alt-v:execute({${preview}}|less >&2)" \
				   --bind="ctrl-j:accept" \
				   --bind="enter:execute(${tools})")
    local -a lines
    lines=("${(@f)file}")
    print ${lines[-1]}
}
