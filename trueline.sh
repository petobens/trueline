# TrueLine
# TODO: First segment should not start with separator
# TODO: Continuation prompt should have it's own function?
# TODO: Add defaults (for colors, segments and icons)
# TODO: Do some profiling

trueline_content() {
    fg_c="${trueline_colors[$1]}"
    bg_c="${trueline_colors[$2]}"
    style="$3m" # 1 for bold; 2 for normal
    content="$4"
    esc_seq_start="\["
    esc_seq_end="\]"
    if [[ -n "$5" ]] && [[ "$5" == "vi" ]]; then
        esc_seq_start="\1"
        esc_seq_end="\2"
    fi
    echo "$esc_seq_start\033[38;2;$fg_c;48;2;$bg_c;$style$esc_seq_end$content$esc_seq_start\033[0m$esc_seq_end"
}

trueline_separator() {
    trueline_content "$_last_color" "$bg_color" 1 "$trueline_separator_symbol"
}

trueline_has_ssh(){
    if [[ -n "$SSH_CLIENT" ]] || [[ -n "$SSH_TTY" ]]; then
        echo 'has_ssh'
    fi
}
trueline_user_segment() {
    fg_color="$1"
    bg_color="$2"
    user="$USER"
    has_ssh="$(trueline_has_ssh)"
    if [[ -n "$has_ssh" ]]; then
        user=" $user@$HOSTNAME"
    fi
    segment="$(trueline_content "$fg_color" "$bg_color" 1 " $user ")"
    PS1+="$segment"
    _last_color=$bg_color
}

trueline_has_venv(){
    printf "%s" "${VIRTUAL_ENV##*/}"
}
trueline_venv_segment() {
    venv="$(trueline_has_venv)"
    if [[ -n "$venv" ]]; then
        fg_color="$1"
        bg_color="$2"
        segment="$(trueline_separator)"
        segment+="$(trueline_content "$fg_color" "$bg_color" 1 "  $venv ")"
        PS1+="$segment"
        _last_color=$bg_color
    fi
}


trueline_has_git_branch() {
    printf "%s" "$(git rev-parse --abbrev-ref HEAD 2> /dev/null)"
}
trueline_git_mod_files() {
    nr_mod_files="$(git diff --name-only --diff-filter=M 2> /dev/null | wc -l )"
    mod_files=''
    if [ ! "$nr_mod_files" -eq 0 ]; then
        mod_files="✚ $nr_mod_files "
    fi
    echo "$mod_files"
}
trueline_git_behind_ahead() {
    branch="$1"
    upstream="$(git config --get branch."$branch".merge)"
    if [[ -n $upstream ]]; then
        nr_behind_ahead="$(git rev-list --count --left-right '@{upstream}...HEAD' 2>/dev/null)" || nr_behind_ahead=''
        nr_behind="${nr_behind_ahead%	*}"
        nr_ahead="${nr_behind_ahead#*	}"
        git_behind_ahead=''
        if [ ! "$nr_behind" -eq 0 ]; then
            git_behind_ahead+=" $nr_behind "
        fi
        if [ ! "$nr_ahead" -eq 0 ]; then
            git_behind_ahead+=" $nr_ahead "
        fi
        echo "$git_behind_ahead"
    fi
}
trueline_git_remote_icon() {
    remote=$(command git ls-remote --get-url 2> /dev/null)
    remote_icon=''
    if [[ "$remote" =~ "github" ]]; then
        remote_icon=' '
    elif [[ "$remote" =~ "bitbucket" ]]; then
        remote_icon=' '
    elif [[ "$remote" =~ "gitlab" ]]; then
        remote_icon=' '
    fi
    echo "$remote_icon"
}
trueline_git_segment() {
    branch="$(trueline_has_git_branch)"
    if [[ -n $branch ]]; then
        fg_color="$1"
        bg_color="$2"
        segment="$(trueline_separator)"

        branch_icon="$(trueline_git_remote_icon)"
        segment+="$(trueline_content "$fg_color" "$bg_color" 2 " $branch_icon $branch ")"
        mod_files="$(trueline_git_mod_files)"
        if [[ -n "$mod_files" ]]; then
            segment+="$(trueline_content Red "$bg_color" 2 "$mod_files")"
        fi
        behind_ahead="$(trueline_git_behind_ahead "$branch")"
        if [[ -n "$behind_ahead" ]]; then
            segment+="$(trueline_content Purple "$bg_color" 2 "$behind_ahead")"
        fi
        PS1+="$segment"
        _last_color=$bg_color
    fi
}

trueline_working_dir_segment() {
    fg_color="$1"
    bg_color="$2"
    segment="$(trueline_separator)"

    p="${PWD/$HOME/ }"
    IFS='/' read -r -a arr <<< "$p"
    path_size="${#arr[@]}"
    if [ "$path_size" -eq 1 ]; then
        path_="\[\033[1m\]${arr[0]:=/}"
    elif [ "$path_size" -eq 2 ]; then
        path_="${arr[0]:=/}  \[\033[1m\]${arr[-1]}"
    else
        if [ "$path_size" -gt 3 ]; then
            p="/"$(echo "$p" | rev | cut -d '/' -f-3 | rev)
        fi
        curr=$(basename "$p")
        p=$(dirname "$p")
        path_="${p//\//  }  \[\033[1m\]$curr"
        if [[ "${p:0:1}" = '/' ]]; then
            path_="/$path_"
        fi
    fi
    segment+="$(trueline_content "$fg_color" "$bg_color" 2 " $path_ ")"
    PS1+="$segment"
    _last_color=$bg_color
}

trueline_is_read_only(){
    if [[ ! -w $PWD ]]; then
        echo 'read_only'
    fi
}
trueline_read_only_segment() {
    read_only="$(trueline_is_read_only)"
    if [[ -n $read_only ]]; then
        fg_color="$1"
        bg_color="$2"
        segment="$(trueline_separator)"
        segment+="$(trueline_content "$fg_color" "$bg_color" 1 "  ")"
        PS1+="$segment"
        _last_color=$bg_color
    fi
}

trueline_exit_status_segment() {
    if [ "$_exit_status" != 0 ]; then
        fg_color="$1"
        bg_color="$2"
        segment="$(trueline_separator)"
        segment+="$(trueline_content "$fg_color" "$bg_color" 1 " $_exit_status ")"
        PS1+="$segment"
        _last_color=$bg_color
    fi
}

trueline_vimode_segment() {
    bind "set show-mode-in-prompt on"
    vimode_ins_fg=${VIMODE_INS_COLORS[0]}
    vimode_ins_bg=${VIMODE_INS_COLORS[1]}
    segment="$(trueline_content "$vimode_ins_fg" "$vimode_ins_bg" 1 " I " "vi")"
    segment+="$(trueline_content "$vimode_ins_bg" "$_first_color" 1 "$trueline_separator_symbol" "vi")"
    segment+="\1\e[6 q\2" # thin vertical bar
    bind "set vi-ins-mode-string $segment"

    vimode_cmd_fg=${VIMODE_CMD_COLORS[0]}
    vimode_cmd_bg=${VIMODE_CMD_COLORS[1]}
    segment="$(trueline_content "$vimode_cmd_fg" "$vimode_cmd_bg" 1 " N " "vi")"
    segment+="$(trueline_content "$vimode_cmd_bg" "$_first_color" 1 "$trueline_separator_symbol" "vi")"
    segment+="\1\e[2 q\2"  # block cursor
    bind "set vi-cmd-mode-string $segment"
    # Switch to block cursor before executing a command
    bind -m vi-insert 'RETURN: "\e\n"'
}

trueline_separator_symbol=''
declare -A trueline_colors=(
    [Black]='36;39;46' #24272e
    [CursorGrey]='40;44;52' #282c34
    [Default]='36;39;46' #24272e
    [Green]='152;195;121' #98c379
    [Grey]='171;178;191' #abb2bf
    [LightBlue]='97;175;239' #61afef
    [Mono]='130;137;151' #828997
    [Orange]='209;154;102' #d19a66
    [Purple]='198;120;221' #c678dd
    [Red]='224;108;117' #e06c75
    [SpecialGrey]='59;64;72' #3b4048
    [White]='208;208;208' #d0d0d0
)

declare -a trueline_segments=(
    'user,Black,White'
    'venv,Black,Purple'
    'git,Grey,SpecialGrey'
    'working_dir,Mono,CursorGrey'
    'read_only,Black,Orange'
    'exit_status,Black,Red'

)

SHOW_VIMODE=true
VIMODE_INS_COLORS=('Black' 'LightBlue')
VIMODE_CMD_COLORS=('Black' 'Green')

trueline_prompt_command() {
    _exit_status="$?"
    PS1=""
    for segment_def in "${trueline_segments[@]}"; do
        segment_name=$(echo "$segment_def" | cut -d ',' -f1)
        segment_fg=$(echo "$segment_def" | cut -d ',' -f2)
        segment_bg=$(echo "$segment_def" | cut -d ',' -f3)
        if [[ -z "$_first_color" ]]; then
            _first_color="$segment_bg" # used by vimode
        fi
        # Note: we cannot call within a subshell because global variables
        # (such as _last_color) won't be passed along
        'trueline_'"$segment_name"'_segment' "$segment_fg" "$segment_bg"
    done

    if [[ "$SHOW_VIMODE" = true ]]; then
        trueline_vimode_segment
    fi

    PS1+=$(trueline_content "$_last_color" Default 1 "$trueline_separator_symbol")
    PS1+=" "  # non-breakable space
    unset _first_color
    unset _last_color
    unset _exit_status
}
unset PROMPT_COMMAND
PROMPT_COMMAND=trueline_prompt_command

# Continuation prompt
PS2=$(trueline_content Black White 1 " ... ")$(trueline_content White Black 1 "$trueline_separator_symbol ")
