# shellcheck disable=SC2155
#---------+
# Helpers |
#---------+
_trueline_font_style() {
    style="$1"
    case "$style" in
        bold)
            style=1
            ;;
        dim)
            style=2
            ;;
        italic)
            style=3
            ;;
        underlined)
            style=4
            ;;
        **)
            style=22
            ;;
    esac
    style+="m"
    echo "$style"
}

_trueline_content() {
    fg_c="${TRUELINE_COLORS[$1]}"
    bg_c="$2"
    style="$(_trueline_font_style "$3")"
    content="$4"
    esc_seq_start="\["
    esc_seq_end="\]"
    if [[ -n "$5" ]] && [[ "$5" == "vi" ]]; then
        esc_seq_start="\1"
        esc_seq_end="\2"
    fi
    output="$esc_seq_start\033[0m\033[38;2;$fg_c;"
    if [[ "$bg_c" != 'default_bg' ]]; then
        bg_c="${TRUELINE_COLORS[$bg_c]}"
        output+="48;2;$bg_c;"
    fi
    output+="$style$esc_seq_end$content$esc_seq_start\033[0m$esc_seq_end"
    echo "$output"
}

_trueline_separator() {
    if [[ -n "$_last_color" ]]; then
        # Only add a separator if it's not the first section (and hence last
        # color is set/defined)
        if [[ -n "$1" ]]; then
            local bg_color="$1"
        fi
        _trueline_content "$_last_color" "$bg_color" bold "${TRUELINE_SYMBOLS[segment_separator]}"
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
_trueline_ip_address() {
    \ip route get 1 | tr -s ' ' | cut -d' ' -f7
}
_trueline_has_ssh() {
    if [[ -n "$SSH_CLIENT" ]] || [[ -n "$SSH_TTY" ]]; then
        echo 'has_ssh'
    fi
}
_trueline_user_segment() {
    local fg_color="$1"
    local bg_color="$2"
    local font_style="$3"
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
        user="${TRUELINE_SYMBOLS[ssh]} $user@"
        if [ "$TRUELINE_USER_SHOW_IP_SSH" = true ]; then
            user+="$(_trueline_ip_address)"
        else
            user+="$HOSTNAME"
        fi
    fi
    local segment="$(_trueline_separator)"
    segment+="$(_trueline_content "$fg_color" "$bg_color" "$font_style" " $user ")"
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
        local font_style="$3"
        local segment="$(_trueline_separator)"
        segment+="$(_trueline_content "$fg_color" "$bg_color" "$font_style" " ${TRUELINE_SYMBOLS[venv]} $venv ")"
        PS1+="$segment"
        _last_color=$bg_color
    fi
}

_trueline_has_conda_env() {
    printf "%s" "${CONDA_DEFAULT_ENV}"
}
_trueline_conda_env_segment() {
    local conda_env="$(_trueline_has_conda_env)"
    if [[ -n "$conda_env" ]]; then
        local fg_color="$1"
        local bg_color="$2"
        local font_style="$3"
        local segment="$(_trueline_separator)"
        segment+="$(_trueline_content "$fg_color" "$bg_color" "$font_style" " ${TRUELINE_SYMBOLS[venv]} $conda_env")"
        PS1+="$segment"
        _last_color=$bg_color
    fi
}

_trueline_has_git_branch() {
    printf "%s" "$(git rev-parse --abbrev-ref HEAD 2> /dev/null)"
}
_trueline_git_mod_files() {
    nr_mod_files="$(git diff --name-only --diff-filter=M 2> /dev/null | wc -l | sed 's/^ *//')"
    mod_files=''
    if [[ ! "$nr_mod_files" -eq 0 ]]; then
        mod_files="${TRUELINE_SYMBOLS[git_modified]} "
        if [[ "$TRUELINE_GIT_SHOW_STATUS_NUMBERS" = true ]]; then
            mod_files+="$nr_mod_files "
        fi
    fi
    echo "$mod_files"
}
_trueline_git_behind_ahead() {
    branch="$1"
    upstream="$(git config --get branch."$branch".merge)"
    if [[ -n $upstream ]]; then
        nr_behind_ahead="$(git rev-list --count --left-right '@{upstream}...HEAD' 2> /dev/null)" || nr_behind_ahead=''
        nr_behind="${nr_behind_ahead%	*}"
        nr_ahead="${nr_behind_ahead#*	}"
        git_behind_ahead=''
        if [[ ! "$nr_behind" -eq 0 ]]; then
            git_behind_ahead+="${TRUELINE_SYMBOLS[git_behind]} "
            if [[ "$TRUELINE_GIT_SHOW_STATUS_NUMBERS" = true ]]; then
                git_behind_ahead+="$nr_behind "

            fi
        fi
        if [[ ! "$nr_ahead" -eq 0 ]]; then
            git_behind_ahead+="${TRUELINE_SYMBOLS[git_ahead]} "
            if [[ "$TRUELINE_GIT_SHOW_STATUS_NUMBERS" = true ]]; then
                git_behind_ahead+="$nr_ahead "

            fi
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
    if [[ -n "${remote_icon// /}" ]]; then
        remote_icon=" $remote_icon "
    fi
    echo "$remote_icon"
}
_trueline_git_segment() {
    local branch="$(_trueline_has_git_branch)"
    if [[ -n $branch ]]; then
        local fg_color="$1"
        local bg_color="$2"
        local font_style="$3"
        local segment="$(_trueline_separator)"

        local branch_icon="$(_trueline_git_remote_icon)"
        segment+="$(_trueline_content "$fg_color" "$bg_color" "$font_style" "$branch_icon$branch ")"
        local mod_files="$(_trueline_git_mod_files)"
        if [[ -n "$mod_files" ]]; then
            segment+="$(_trueline_content "$TRUELINE_GIT_MODIFIED_COLOR" "$bg_color" "$font_style" "$mod_files")"
        fi
        local behind_ahead="$(_trueline_git_behind_ahead "$branch")"
        if [[ -n "$behind_ahead" ]]; then
            segment+="$(_trueline_content "$TRUELINE_GIT_BEHIND_AHEAD_COLOR" "$bg_color" "$font_style" "$behind_ahead")"
        fi
        PS1+="$segment"
        _last_color=$bg_color
    fi
}

_trueline_working_dir_segment() {
    local fg_color="$1"
    local bg_color="$2"
    local font_style="$3"
    local segment="$(_trueline_separator)"
    local wd_separator="${TRUELINE_SYMBOLS[working_dir_separator]}"
    if [[ "$TRUELINE_WORKING_DIR_SPACE_BETWEEN_PATH_SEPARATOR" = true ]]; then
        wd_separator=" $wd_separator "
    fi

    local p="${PWD/$HOME/${TRUELINE_SYMBOLS[working_dir_home]}}"
    local arr=
    IFS='/' read -r -a arr <<< "$p"
    local path_size="${#arr[@]}"
    if [[ "$path_size" -eq 1 ]]; then
        local path_="\[\033[1m\]${arr[0]:=/}"
    elif [[ "$path_size" -eq 2 ]]; then
        local path_="${arr[0]:=/}$wd_separator\[\033[1m\]${arr[+1]}"
    else
        if [[ "$path_size" -gt 3 ]]; then
            if [[ "$TRUELINE_WORKING_DIR_ABBREVIATE_PARENT_DIRS" = true ]]; then
                p=$(echo "$p" | sed -r "s:([^/]{,$TRUELINE_WORKING_DIR_ABBREVIATE_PARENT_DIRS_LENGTH})[^/]*/:\1/:g")
            else
                p="${TRUELINE_SYMBOLS[working_dir_folder]}/"$(echo "$p" | rev | cut -d '/' -f-3 | rev)
            fi
        fi
        local curr=$(basename "$p")
        p=$(dirname "$p")
        local path_="${p//\//$wd_separator}$wd_separator\[\033[1m\]$curr"
        if [[ "${p:0:1}" = '/' ]]; then
            path_="/$path_"
        fi
    fi
    segment+="$(_trueline_content "$fg_color" "$bg_color" "$font_style" " $path_ ")"
    PS1+="$segment"
    _last_color=$bg_color
}

_trueline_bg_jobs_segment() {
    local bg_jobs=$(jobs -p | wc -l | sed 's/^ *//')
    if [[ ! "$bg_jobs" -eq 0 ]]; then
        local fg_color="$1"
        local bg_color="$2"
        local font_style="$3"
        local segment="$(_trueline_separator)"
        segment+="$(_trueline_content "$fg_color" "$bg_color" "$font_style" " ${TRUELINE_SYMBOLS[bg_jobs]} $bg_jobs ")"
        PS1+="$segment"
        _last_color=$bg_color
    fi
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
        local font_style="$3"
        local segment="$(_trueline_separator)"
        segment+="$(_trueline_content "$fg_color" "$bg_color" "$font_style" " ${TRUELINE_SYMBOLS[read_only]} ")"
        PS1+="$segment"
        _last_color=$bg_color
    fi
}

_trueline_exit_status_segment() {
    if [[ "$_exit_status" != 0 ]]; then
        local fg_color="$1"
        local bg_color="$2"
        local font_style="$3"
        local segment="$(_trueline_separator)"
        segment+="$(_trueline_content "$fg_color" "$bg_color" "$font_style" "${TRUELINE_SYMBOLS[exit_status]} $_exit_status ")"
        PS1+="$segment"
        _last_color=$bg_color
    fi
}

_trueline_newline_segment() {
    local fg_color="$1"
    local bg_color="$2"
    local font_style="$3"
    local is_root="$(_trueline_is_root)"
    local newline_symbol="${TRUELINE_SYMBOLS[newline]}"
    if [[ -n "$is_root" ]]; then
        local newline_symbol="${TRUELINE_SYMBOLS[newline_root]}"
    fi
    local segment="$(_trueline_separator default_bg)"
    segment+="\n"
    segment+="$(_trueline_content "$fg_color" "$bg_color" "$font_style" "$newline_symbol")"
    PS1+="$segment"
    _last_color=$bg_color
}

_trueline_vimode_cursor_shape() {
    shape="$1"
    case "$shape" in
        under)
            cursor_parameter=4
            ;;
        vert)
            cursor_parameter=6
            ;;
        **)
            cursor_parameter=2
            ;;
    esac
    echo "\1\e[$cursor_parameter q\2"
}
_trueline_vimode_segment() {
    if [[ "$TRUELINE_SHOW_VIMODE" = true ]]; then
        if [[ ! -o vi ]]; then
            set -o vi
        fi

        local seg_separator=${TRUELINE_SYMBOLS[segment_separator]}

        bind "set show-mode-in-prompt on"
        local vimode_ins_fg=${TRUELINE_VIMODE_INS_COLORS_STYLE[0]}
        local vimode_ins_bg=${TRUELINE_VIMODE_INS_COLORS_STYLE[1]}
        local vimode_ins_font_style=${TRUELINE_VIMODE_INS_COLORS_STYLE[2]}
        local segment="$(_trueline_content "$vimode_ins_fg" "$vimode_ins_bg" "$vimode_ins_font_style" " ${TRUELINE_SYMBOLS[vimode_ins]} " "vi")"
        segment+="$(_trueline_content "$vimode_ins_bg" "$_first_color_bg" bold "$seg_separator" "vi")"
        segment+="$(_trueline_vimode_cursor_shape "$TRUELINE_VIMODE_INS_CURSOR")"
        bind "set vi-ins-mode-string $segment"

        local vimode_cmd_fg=${TRUELINE_VIMODE_CMD_COLORS_STYLE[0]}
        local vimode_cmd_bg=${TRUELINE_VIMODE_CMD_COLORS_STYLE[1]}
        local vimode_cmd_font_style=${TRUELINE_VIMODE_CMD_COLORS_STYLE[2]}
        segment="$(_trueline_content "$vimode_cmd_fg" "$vimode_cmd_bg" "$vimode_cmd_font_style" " ${TRUELINE_SYMBOLS[vimode_cmd]} " "vi")"
        segment+="$(_trueline_content "$vimode_cmd_bg" "$_first_color_bg" bold "$seg_separator" "vi")"
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
    PS2=$(_trueline_content "$_first_color_fg" "$_first_color_bg" "$_first_font_style" " ${TRUELINE_SYMBOLS[ps2]} ")
    PS2+=$(_trueline_content "$_first_color_bg" default_bg bold "${TRUELINE_SYMBOLS[segment_separator]} ")
}

_trueline_prompt_command() {
    _exit_status="$?"
    PS1=""

    local segment_def=
    for segment_def in "${TRUELINE_SEGMENTS[@]}"; do
        local segment_name=$(echo "$segment_def" | cut -d ',' -f1)
        local segment_fg=$(echo "$segment_def" | cut -d ',' -f2)
        local segment_bg=$(echo "$segment_def" | cut -d ',' -f3)
        local font_style=$(echo "$segment_def" | cut -d ',' -f4)
        if [[ -z "$_first_color_fg" ]] || [[ "$segment_name" = 'newline' ]]; then
            _first_color_fg="$segment_fg"
            _first_color_bg="$segment_bg"
            _first_font_style="$font_style"
        fi
        # Note: we cannot call within a subshell because global variables
        # (such as _last_color) won't be passed along
        '_trueline_'"$segment_name"'_segment' "$segment_fg" "$segment_bg" "$font_style"
    done

    _trueline_vimode_segment
    PS1+=$(_trueline_content "$_last_color" default_bg bold "${TRUELINE_SYMBOLS[segment_separator]}")
    PS1+=" " # non-breakable space
    _trueline_continuation_prompt

    unset _first_color_fg
    unset _first_color_bg
    unset _first_font_style
    unset _last_color
    unset _exit_status
}

#---------------+
# Configuration |
#---------------+
declare -A TRUELINE_COLORS_DEFAULT=(
    [black]='36;39;46'        #24272e
    [cursor_grey]='40;44;52'  #282c34
    [green]='152;195;121'     #98c379
    [grey]='171;178;191'      #abb2bf
    [light_blue]='97;175;239' #61afef
    [mono]='130;137;151'      #828997
    [orange]='209;154;102'    #d19a66
    [purple]='198;120;221'    #c678dd
    [red]='224;108;117'       #e06c75
    [special_grey]='59;64;72' #3b4048
    [white]='208;208;208'     #d0d0d0
)
if [[ "${#TRUELINE_COLORS[@]}" -eq 0 ]]; then
    declare -A TRUELINE_COLORS=()
fi
for i in "${!TRUELINE_COLORS_DEFAULT[@]}"; do
    if [[ ! "${TRUELINE_COLORS["$i"]+exists}" ]]; then
        TRUELINE_COLORS["$i"]="${TRUELINE_COLORS_DEFAULT["$i"]}"
    fi
done
unset TRUELINE_COLORS_DEFAULT

if [[ "${#TRUELINE_SEGMENTS[@]}" -eq 0 ]]; then
    declare -a TRUELINE_SEGMENTS=(
        'user,black,white,bold'
        'venv,black,purple,bold'
        # 'conda_env,black,purple,bold'
        'git,grey,special_grey,normal'
        'working_dir,mono,cursor_grey,normal'
        'read_only,black,orange,bold'
        'bg_jobs,black,orange,bold'
        'exit_status,black,red,bold'
        # 'newline,black,orange,bold'
    )
fi

declare -A TRUELINE_SYMBOLS_DEFAULT=(
    [bg_jobs]=''
    [exit_status]=''
    [git_ahead]=''
    [git_behind]=''
    [git_bitbucket]=''
    [git_branch]=''
    [git_github]=''
    [git_gitlab]=''
    [git_modified]=''
    [newline]='  '
    [newline_root]='  '
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
if [[ "${#TRUELINE_SYMBOLS[@]}" -eq 0 ]]; then
    declare -A TRUELINE_SYMBOLS=()
fi
for i in "${!TRUELINE_SYMBOLS_DEFAULT[@]}"; do
    if [[ ! "${TRUELINE_SYMBOLS["$i"]+exists}" ]]; then
        TRUELINE_SYMBOLS["$i"]="${TRUELINE_SYMBOLS_DEFAULT["$i"]}"
    fi
done
unset TRUELINE_SYMBOLS_DEFAULT

# Vimode
if [[ -z "$TRUELINE_SHOW_VIMODE" ]]; then
    TRUELINE_SHOW_VIMODE=false
fi
if [[ -z "$TRUELINE_VIMODE_INS_COLORS_STYLE" ]]; then
    TRUELINE_VIMODE_INS_COLORS_STYLE=('black' 'light_blue' 'bold')
fi
if [[ -z "$TRUELINE_VIMODE_CMD_COLORS_STYLE" ]]; then
    TRUELINE_VIMODE_CMD_COLORS_STYLE=('black' 'green' 'bold')
fi
if [[ -z "$TRUELINE_VIMODE_INS_CURSOR" ]]; then
    TRUELINE_VIMODE_INS_CURSOR='vert'
fi
if [[ -z "$TRUELINE_VIMODE_CMD_CURSOR" ]]; then
    TRUELINE_VIMODE_CMD_CURSOR='block'
fi

# Git
if [[ -z "$TRUELINE_GIT_SHOW_STATUS_NUMBERS" ]]; then
    TRUELINE_GIT_SHOW_STATUS_NUMBERS=true
fi
if [[ -z "$TRUELINE_GIT_MODIFIED_COLOR" ]]; then
    TRUELINE_GIT_MODIFIED_COLOR='red'
fi
if [[ -z "$TRUELINE_GIT_BEHIND_AHEAD_COLOR" ]]; then
    TRUELINE_GIT_BEHIND_AHEAD_COLOR='purple'
fi

# User
if [[ -z "$TRUELINE_USER_ROOT_COLORS" ]]; then
    TRUELINE_USER_ROOT_COLORS=('black' 'red')
fi
if [[ -z "$TRUELINE_USER_SHOW_IP_SSH" ]]; then
    TRUELINE_USER_SHOW_IP_SSH=false
fi

# Working dir
if [[ -z "$TRUELINE_WORKING_DIR_SPACE_BETWEEN_PATH_SEPARATOR" ]]; then
    TRUELINE_WORKING_DIR_SPACE_BETWEEN_PATH_SEPARATOR=true

fi
if [[ -z "$TRUELINE_WORKING_DIR_ABBREVIATE_PARENT_DIRS" ]]; then
    TRUELINE_WORKING_DIR_ABBREVIATE_PARENT_DIRS=false
fi
if [[ -z "$TRUELINE_WORKING_DIR_ABBREVIATE_PARENT_DIRS_LENGTH" ]]; then
    TRUELINE_WORKING_DIR_ABBREVIATE_PARENT_DIRS_LENGTH=1
fi

#----------------+
# PROMPT_COMMAND |
#----------------+
# Backup old prompt command first
if [ -z "$_PROMPT_COMMAND_OLD" ]; then
    _PROMPT_COMMAND_OLD="$PROMPT_COMMAND"
fi
unset PROMPT_COMMAND
PROMPT_COMMAND=_trueline_prompt_command
