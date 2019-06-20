# shellcheck disable=SC2155
#---------+
# Helpers |
#---------+
_trueline_content() {
    fg_c="${TRUELINE_COLORS[$1]}"
    bg_c="${TRUELINE_COLORS[$2]}"
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

_trueline_separator() {
    if [[ -n "$_last_color" ]]; then
        # Only add a separator if it's not the first section (and hence last
        # color is set/defined)
        _trueline_content "$_last_color" "$bg_color" 1 "${TRUELINE_SYMBOLS[segment_separator]}"
    fi
}


#----------+
# Segments |
#----------+
_trueline_is_root() {
    if [[ "${EUID}" -eq 0 ]]; then
        echo 'is_root'
    fi
}
_trueline_has_ssh() {
    if [[ -n "$SSH_CLIENT" ]] || [[ -n "$SSH_TTY" ]]; then
        echo 'has_ssh'
    fi
}
_trueline_user_segment() {
    local fg_color="$1"
    local bg_color="$2"
    local user="$USER"
    local is_root="$(_trueline_is_root)"
    if [[ -n "$is_root" ]]; then
        if [[ -z "$user" ]]; then
            user='root'
        fi
        fg_color=${TRUELINE_USER_ROOT_COLORS[0]}
        bg_color=${TRUELINE_USER_ROOT_COLORS[1]}
    fi
    local has_ssh="$(_trueline_has_ssh)"
    if [[ -n "$has_ssh" ]]; then
        user="${TRUELINE_SYMBOLS[ssh]} $user@$HOSTNAME"
    fi
    local segment="$(_trueline_separator)"
    segment+="$(_trueline_content "$fg_color" "$bg_color" 1 " $user ")"
    PS1+="$segment"
    _last_color=$bg_color
}

_trueline_has_venv() {
    printf "%s" "${VIRTUAL_ENV##*/}"
}
_trueline_venv_segment() {
    local venv="$(_trueline_has_venv)"
    if [[ -n "$venv" ]]; then
        local fg_color="$1"
        local bg_color="$2"
        local segment="$(_trueline_separator)"
        segment+="$(_trueline_content "$fg_color" "$bg_color" 1 " ${TRUELINE_SYMBOLS[venv]} $venv ")"
        PS1+="$segment"
        _last_color=$bg_color
    fi
}

_trueline_has_git_branch() {
    printf "%s" "$(git rev-parse --abbrev-ref HEAD 2> /dev/null)"
}
_trueline_git_mod_files() {
    nr_mod_files="$(git diff --name-only --diff-filter=M 2> /dev/null | wc -l )"
    mod_files=''
    if [[ ! "$nr_mod_files" -eq 0 ]]; then
        mod_files="${TRUELINE_SYMBOLS[git_modified]} $nr_mod_files "
    fi
    echo "$mod_files"
}
_trueline_git_behind_ahead() {
    branch="$1"
    upstream="$(git config --get branch."$branch".merge)"
    if [[ -n $upstream ]]; then
        nr_behind_ahead="$(git rev-list --count --left-right '@{upstream}...HEAD' 2>/dev/null)" || nr_behind_ahead=''
        nr_behind="${nr_behind_ahead%	*}"
        nr_ahead="${nr_behind_ahead#*	}"
        git_behind_ahead=''
        if [[ ! "$nr_behind" -eq 0 ]]; then
            git_behind_ahead+="${TRUELINE_SYMBOLS[git_behind]} $nr_behind "
        fi
        if [[ ! "$nr_ahead" -eq 0 ]]; then
            git_behind_ahead+="${TRUELINE_SYMBOLS[git_ahead]} $nr_ahead "
        fi
        echo "$git_behind_ahead"
    fi
}
_trueline_git_remote_icon() {
    remote=$(command git ls-remote --get-url 2> /dev/null)
    remote_icon="${TRUELINE_SYMBOLS[git_branch]}"
    if [[ "$remote" =~ "github" ]]; then
        remote_icon="${TRUELINE_SYMBOLS[git_github]} "
    elif [[ "$remote" =~ "bitbucket" ]]; then
        remote_icon="${TRUELINE_SYMBOLS[git_bitbucket]} "
    elif [[ "$remote" =~ "gitlab" ]]; then
        remote_icon="${TRUELINE_SYMBOLS[git_gitlab]} "
    fi
    echo "$remote_icon"
}
_trueline_git_segment() {
    local branch="$(_trueline_has_git_branch)"
    if [[ -n $branch ]]; then
        local fg_color="$1"
        local bg_color="$2"
        local segment="$(_trueline_separator)"

        local branch_icon="$(_trueline_git_remote_icon)"
        segment+="$(_trueline_content "$fg_color" "$bg_color" 2 " $branch_icon $branch ")"
        local mod_files="$(_trueline_git_mod_files)"
        if [[ -n "$mod_files" ]]; then
            segment+="$(_trueline_content "$TRUELINE_GIT_MODIFIED_COLOR" "$bg_color" 2 "$mod_files")"
        fi
        local behind_ahead="$(_trueline_git_behind_ahead "$branch")"
        if [[ -n "$behind_ahead" ]]; then
            segment+="$(_trueline_content "$TRUELINE_GIT_BEHIND_AHEAD_COLOR" "$bg_color" 2 "$behind_ahead")"
        fi
        PS1+="$segment"
        _last_color=$bg_color
    fi
}

_trueline_working_dir_segment() {
    local fg_color="$1"
    local bg_color="$2"
    local segment="$(_trueline_separator)"
    local wd_separator=${TRUELINE_SYMBOLS[working_dir_separator]}

    local p="${PWD/$HOME/${TRUELINE_SYMBOLS[working_dir_home]}}"
    local arr=
    IFS='/' read -r -a arr <<< "$p"
    local path_size="${#arr[@]}"
    if [[ "$path_size" -eq 1 ]]; then
        local path_="\[\033[1m\]${arr[0]:=/}"
    elif [[ "$path_size" -eq 2 ]]; then
        local path_="${arr[0]:=/} $wd_separator \[\033[1m\]${arr[-1]}"
    else
        if [[ "$path_size" -gt 3 ]]; then
            p="${TRUELINE_SYMBOLS[working_dir_folder]}/"$(echo "$p" | rev | cut -d '/' -f-3 | rev)
        fi
        local curr=$(basename "$p")
        p=$(dirname "$p")
        local path_="${p//\// $wd_separator } $wd_separator \[\033[1m\]$curr"
        if [[ "${p:0:1}" = '/' ]]; then
            path_="/$path_"
        fi
    fi
    segment+="$(_trueline_content "$fg_color" "$bg_color" 2 " $path_ ")"
    PS1+="$segment"
    _last_color=$bg_color
}

_trueline_is_read_only() {
    if [[ ! -w $PWD ]]; then
        echo 'read_only'
    fi
}
_trueline_read_only_segment() {
    local read_only="$(_trueline_is_read_only)"
    if [[ -n $read_only ]]; then
        local fg_color="$1"
        local bg_color="$2"
        local segment="$(_trueline_separator)"
        segment+="$(_trueline_content "$fg_color" "$bg_color" 1 " ${TRUELINE_SYMBOLS[read_only]} ")"
        PS1+="$segment"
        _last_color=$bg_color
    fi
}

_trueline_exit_status_segment() {
    if [[ "$_exit_status" != 0 ]]; then
        local fg_color="$1"
        local bg_color="$2"
        local segment="$(_trueline_separator)"
        segment+="$(_trueline_content "$fg_color" "$bg_color" 1 " $_exit_status ")"
        PS1+="$segment"
        _last_color=$bg_color
    fi
}

_trueline_vimode_cursor_shape() {
    shape="$1"
    case "$shape" in
        under)
            cursor_parameter=4 ;;
        vert)
            cursor_parameter=6 ;;
        **)
            cursor_parameter=2 ;;
    esac
    echo "\1\e[$cursor_parameter q\2"
}
_trueline_vimode_segment() {
    if [[ "$TRUELINE_SHOW_VIMODE" = true ]]; then
        local seg_separator=${TRUELINE_SYMBOLS[segment_separator]}

        bind "set show-mode-in-prompt on"
        local vimode_ins_fg=${TRUELINE_VIMODE_INS_COLORS[0]}
        local vimode_ins_bg=${TRUELINE_VIMODE_INS_COLORS[1]}
        local segment="$(_trueline_content "$vimode_ins_fg" "$vimode_ins_bg" 1 " ${TRUELINE_SYMBOLS[vimode_ins]} " "vi")"
        segment+="$(_trueline_content "$vimode_ins_bg" "$_first_color_bg" 1 "$seg_separator" "vi")"
        segment+="$(_trueline_vimode_cursor_shape "$TRUELINE_VIMODE_INS_CURSOR")"
        bind "set vi-ins-mode-string $segment"

        local vimode_cmd_fg=${TRUELINE_VIMODE_CMD_COLORS[0]}
        local vimode_cmd_bg=${TRUELINE_VIMODE_CMD_COLORS[1]}
        segment="$(_trueline_content "$vimode_cmd_fg" "$vimode_cmd_bg" 1 " ${TRUELINE_SYMBOLS[vimode_cmd]} " "vi")"
        segment+="$(_trueline_content "$vimode_cmd_bg" "$_first_color_bg" 1 "$seg_separator" "vi")"
        segment+="$(_trueline_vimode_cursor_shape "$TRUELINE_VIMODE_CMD_CURSOR")"
        bind "set vi-cmd-mode-string $segment"

        # Switch to block cursor before executing a command
        bind -m vi-insert 'RETURN: "\e\n"'
    else
        bind "set show-mode-in-prompt off"
    fi
}


#-------------+
# PS1 and PS2 |
#-------------+
_trueline_continuation_prompt() {
    PS2=$(_trueline_content "$_first_color_fg" "$_first_color_bg" 1 " ${TRUELINE_SYMBOLS[ps2]} ")
    PS2+=$(_trueline_content "$_first_color_bg" default 1 "${TRUELINE_SYMBOLS[segment_separator]} ")
}

_trueline_prompt_command() {
    _exit_status="$?"
    PS1=""

    local segment_def=
    for segment_def in "${TRUELINE_SEGMENTS[@]}"; do
        local segment_name=$(echo "$segment_def" | cut -d ',' -f1)
        local segment_fg=$(echo "$segment_def" | cut -d ',' -f2)
        local segment_bg=$(echo "$segment_def" | cut -d ',' -f3)
        if [[ -z "$_first_color_fg" ]]; then
            _first_color_fg="$segment_fg"
            _first_color_bg="$segment_bg"
        fi
        # Note: we cannot call within a subshell because global variables
        # (such as _last_color) won't be passed along
        '_trueline_'"$segment_name"'_segment' "$segment_fg" "$segment_bg"
    done

    _trueline_vimode_segment
    PS1+=$(_trueline_content "$_last_color" default 1 "${TRUELINE_SYMBOLS[segment_separator]}")
    PS1+=" "  # non-breakable space
    _trueline_continuation_prompt

    unset _first_color_fg
    unset _first_color_bg
    unset _last_color
    unset _exit_status
}


#---------------+
# Configuration |
#---------------+
if [[ "${#TRUELINE_COLORS[@]}" -eq 0 ]]; then
    declare -A TRUELINE_COLORS=(
        [black]='36;39;46' #24272e
        [cursor_grey]='40;44;52' #282c34
        [default]='36;39;46' #24272e
        [green]='152;195;121' #98c379
        [grey]='171;178;191' #abb2bf
        [light_blue]='97;175;239' #61afef
        [mono]='130;137;151' #828997
        [orange]='209;154;102' #d19a66
        [purple]='198;120;221' #c678dd
        [red]='224;108;117' #e06c75
        [special_grey]='59;64;72' #3b4048
        [white]='208;208;208' #d0d0d0
    )
fi

if [[ "${#TRUELINE_SEGMENTS[@]}" -eq 0 ]]; then
    declare -a TRUELINE_SEGMENTS=(
        'user,black,white'
        'venv,black,purple'
        'git,grey,special_grey'
        'working_dir,mono,cursor_grey'
        'read_only,black,orange'
        'exit_status,black,red'

    )
fi

if [[ "${#TRUELINE_SYMBOLS[@]}" -eq 0 ]]; then
    declare -A TRUELINE_SYMBOLS=(
        [git_ahead]=''
        [git_behind]=''
        [git_bitbucket]=''
        [git_branch]=''
        [git_github]=''
        [git_gitlab]=''
        [git_modified]='✚'
        [ps2]='...'
        [read_only]=''
        [segment_separator]=''
        [ssh]=''
        [venv]=''
        [vimode_cmd]='N'
        [vimode_ins]='I'
        [working_dir_folder]=''
        [working_dir_home]=''
        [working_dir_separator]=''
    )
fi

if [[ -z "$TRUELINE_SHOW_VIMODE" ]]; then
    TRUELINE_SHOW_VIMODE=false
fi
if [[ -z "$TRUELINE_VIMODE_INS_COLORS" ]]; then
    TRUELINE_VIMODE_INS_COLORS=('black' 'light_blue')
fi
if [[ -z "$TRUELINE_VIMODE_CMD_COLORS" ]]; then
    TRUELINE_VIMODE_CMD_COLORS=('black' 'green')
fi
if [[ -z "$TRUELINE_VIMODE_INS_CURSOR" ]]; then
    TRUELINE_VIMODE_INS_CURSOR='vert'
fi
if [[ -z "$TRUELINE_VIMODE_CMD_CURSOR" ]]; then
    TRUELINE_VIMODE_CMD_CURSOR='block'
fi

if [[ -z "$TRUELINE_GIT_MODIFIED_COLOR" ]]; then
    TRUELINE_GIT_MODIFIED_COLOR='red'
fi
if [[ -z "$TRUELINE_GIT_BEHIND_AHEAD_COLOR" ]]; then
    TRUELINE_GIT_BEHIND_AHEAD_COLOR='purple'
fi

if [[ -z "$TRUELINE_USER_ROOT_COLORS" ]]; then
    TRUELINE_USER_ROOT_COLORS=('black' 'red')
fi

# Actually set the prompt:
unset PROMPT_COMMAND
PROMPT_COMMAND=_trueline_prompt_command
