<!-- markdownlint-disable MD045 -->

# Trueline: Bash Powerline Style Prompt with True Color Support

Trueline is a fast and extensible [Powerline](https://github.com/powerline/powerline)
style bash prompt with true color (24-bit) and fancy glyph support.

The pure Bash code implementation and overall features are modelled after the excellent
[Pureline](https://github.com/chris-marsh/pureline) command prompt. However Trueline also
adds the ability to use RGB color codes, expands icon/glyph usage across prompt segments
(inspired by [Powerlevel9k](https://github.com/bhilburn/powerlevel9k)), simplifies
configuration and, among other goodies, shows the current input mode (when in vi-mode).

![](https://user-images.githubusercontent.com/2583971/59968771-a7962e80-9515-11e9-9feb-d993ef0f4855.png)

## Installation

Download the `trueline.sh` script in this repo and source it from within your `.bashrc`
file:

```bash
$> git clone https://github.com/petobens/trueline ~/trueline
$> echo 'source ~/trueline/trueline.sh' >> ~/.bashrc
```

or alternatively

```bash
$> wget https://raw.githubusercontent.com/petobens/trueline/master/trueline.sh -P ~/
$> echo 'source ~/trueline.sh' >> ~/.bashrc
```

If you use a font that supports "Powerline" glyphs, such as those included in the
wonderful [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts) project, then the prompt
should render properly and no further configuration is necessary (as long as you like the
default settings shown in the image above).

## Customization

Customizing and extending the prompt is easy and there are several segment options
available to do so.

All settings go inside your `.bashrc` and must be defined before actually sourcing the
`trueline.sh` file (otherwise default settings will be used). To see how this works let's
start with a simple configuration example:

```bash
declare -A TRUELINE_COLORS=(
    [light_blue]='75;161;207'
    [grey]='99;99;100'
    [pink]='199;88;157'
)

declare -a TRUELINE_SEGMENTS=(
    'working_dir,light_blue,black,normal'
    'git,grey,black,normal'
    'time,white,black,normal'
    'newline,pink,black,bold'
)

declare -A TRUELINE_SYMBOLS=(
    [git_modified]='*'
    [git_github]=''
    [segment_separator]=''
    [working_dir_folder]='...'
    [working_dir_separator]='/'
    [working_dir_home]='~'
    [newline]='❯'
    [clock]='🕒'
)

TRUELINE_GIT_SHOW_STATUS_NUMBERS=false
TRUELINE_GIT_MODIFIED_COLOR='grey'
TRUELINE_WORKING_DIR_SPACE_BETWEEN_PATH_SEPARATOR=false

_trueline_time_segment() {
    local prompt_time="${TRUELINE_SYMBOLS[clock]} \t"
    if [[ -n "$prompt_time" ]]; then
        local fg_color="$1"
        local bg_color="$2"
        local font_style="$3"
        local segment="$(_trueline_separator)"
        segment+="$(_trueline_content "$fg_color" "$bg_color" "$font_style" " $prompt_time ")"
        PS1+="$segment"
        _trueline_record_colors "$fg_color" "$bg_color" "$font_style"
    fi
}

source ~/trueline/trueline.sh
```

which generates the following prompt (that essentially replicates the minimal ZSH
[Pure](https://github.com/sindresorhus/pure) prompt):

![](https://user-images.githubusercontent.com/2583971/59968784-c8f71a80-9515-11e9-9e3d-53ac7f67e475.png)

You can see in the config above that there are basically 5 different/relevant settings:
colors, segments, symbols, options and extensions. Let's break each of these down.

### Colors

Colors are defined by means of an associative array named `TRUELINE_COLORS`. The keys of
this array are color names and the values RGB color codes:

```bash
declare -A TRUELINE_COLORS=(
    [color_name]='red;green;blue'
)
```

Default colors are loosely based on [Atom's One Dark
theme](https://atom.io/themes/one-dark-syntax) and given by:

```bash
declare -A TRUELINE_COLORS=(
    [black]='36;39;46'
    [cursor_grey]='40;44;52'
    [green]='152;195;121'
    [grey]='171;178;191'
    [light_blue]='97;175;239'
    [mono]='130;137;151'
    [orange]='209;154;102'
    [purple]='198;120;221'
    [red]='224;108;117'
    [special_grey]='59;64;72'
    [white]='208;208;208'
)
```

Any `TRUELINE_COLORS` array defined in the bashrc file prior to sourcing the Trueline
script will actually update the default array above (in the sense that it will overwrite
existing keys and add non-existing ones). This basically means that default colors can
always be used and the array only needs to be defined when new extra colors are truly
needed.

_Note:_ you can define any color name you want except for `default_bg` which is used by
Trueline to obtain the default terminal background color.

### Segments

Prompt segments are defined in an ordered array called `TRUELINE_SEGMENTS` that has the
following structure:

```bash
declare -a TRUELINE_SEGMENTS=(
    'segment_name,segment_fg_color,segment_bg_color,font_style'
)
```

where the segment foreground and background color names are keys of the `TRUELINE_COLORS`
array and the font style is either `bold`, `dim`, `italic`, `normal` or `underlined`. The
order of the elements in the array define the order in which each segment is rendered in
the prompt.

Trueline offers the following segments (status indicates whether they are enabled/rendered
by default):

| Segment Name   | Status     | Description                                   |
| -------------- | ---------- | -------------                                 |
| aws_profile    | enabled    | current AWS profile                           |
| bg_jobs        | enabled    | number of background jobs                     |
| cmd_duration   | disabled   | last command execution time                   |
| conda_env      | enabled    | current anaconda environment                  |
| exit_status    | enabled    | return code of last command                   |
| git            | enabled    | git branch/remote and repository status       |
| newline        | disabled   | splits prompt segments across multiple lines  |
| read_only      | enabled    | indicator of read only directory              |
| user           | enabled    | username and host (conditional on ssh status) |
| venv           | enabled    | Python virtual environment                    |
| working_dir    | enabled    | current working directory                     |

but more segments can be easily added (see [Extensions](#Extensions)).

To enable the newline segment one could use the following config:

```bash
declare -a TRUELINE_SEGMENTS=(
    'working_dir,mono,cursor_grey,normal'
    'git,grey,special_grey,normal'
    'newline,black,orange,bold'
)
```

which results in:
![](https://user-images.githubusercontent.com/2583971/60122514-bb32d680-975b-11e9-8a57-811ed430a933.png)

### Symbols

Symbols (i.e icons/glyphs) are defined through an associative array named
`TRUELINE_SYMBOLS` where each entry key is a (predefined) segment symbol name and the
value is the actual symbol/icon:

```bash
declare -A TRUELINE_SYMBOLS=(
    [segment_symbol_name]='|' # actual symbol
)
```

The following table shows the current predefined symbol names along with their default
values (i.e either the actual glyph or the corresponding nerd-font unicode code):

| Symbol Name   | Glyph         |   | Symbol Name           | Glyph         |
| ------------- | ------------- | - | -------------         | ------------- |
| aws_profile   | U+f52c        |   | ps2                   | ...           |
| bg_jobs       | U+f085        |   | read_only             | U+f023        |
| exit_status   | blank         |   | segment_separator     | U+e0b0        |
| git_ahead     | U+f55c        |   | local                 | U+f108        |
| git_behind    | U+f544        |   | ssh                   | U+f817        |
| git_bitbucket | U+f171        |   | timer                 | U+fa1e        |
| git_branch    | U+e0a0        |   | venv (and conda)      | U+e73c        |
| git_github    | U+f408        |   | vimode_cmd            | N             |
| git_gitlab    | U+f296        |   | vimode_ins            | I             |
| git_modified  | U+f44d        |   | working_dir_folder    | U+e5fe        |
| newline       | U+f155        |   | working_dir_home      | U+f015        |
| newline_root  | U+f292        |   | working_dir_separator | U+e0b1        |

As with `TRUELINE_COLORS`, any `TRUELINE_SYMBOLS` array defined in the bashrc file prior
to sourcing the Trueline script will actually update the array with the default symbols
shown above (thus such array needs to be defined only when overriding some icon or adding
new ones).

### Options

Most Trueline settings are controlled with the 3 structures defined above. However
Trueline also defines a series of variables that control some extra options. In particular
we can distinguish between intra-segment and external options. These, along with their
default values, are defined as follows:

#### Intra-segment

The next segments have (sub)settings of their own:

- git:
    - `TRUELINE_GIT_SHOW_STATUS_NUMBERS=true`: boolean variable that determines
    whether to show (or not) the actual number of modified files and commits
    behind/ahead next to the corresponding modified-behind/ahead status symbol.
    - `TRUELINE_GIT_MODIFIED_COLOR='red'`: foreground color for symbol and number of
    modified files.
    - `TRUELINE_GIT_BEHIND_AHEAD_COLOR='purple'`: foreground color for symbol and
    number of commits behind/ahead.
- user:
    - `TRUELINE_USER_ROOT_COLORS=('black' 'red')`: root user foreground and
    background colors, when root has Trueline installed with this setting.
    - `TRUELINE_USER_SHOW_HOST__SSH=false`: boolean variable that determines whether
    to show the host portion of the segment (or just the user portion) to an SSH
    user connecting *to the host* where this option is set.
    - `TRUELINE_USER_SHOW_IP__SSH=false`: boolean variable that determines whether
    to show the IP address as the host portion of the segment to an SSH user
    connecting *to the host* where this option is set.
    - `TRUELINE_USER_SHORT_HOSTNAME__SSH=true`: boolean variable that determines
    whether to show the short hostname (host) or the full hostname (host.domain.com)
    to an SSH user connecting *to the host* where this option is set.
    - `TRUELINE_USER_SHOW_HOST__LOCAL=false`: boolean variable that determines
    whether to show the host portion of the segment (or just the user portion)
    to a local user.
    - `TRUELINE_USER_SHOW_IP__LOCAL=false`: boolean variable that determines
    whether to show the IP address as the host portion of the segment to a local
    user.
    - `TRUELINE_USER_SHORT_HOSTNAME__LOCAL=true`: boolean variable that determines
    whether to show the short hostname (host) or the full hostname (host.domain.com)
    to a local user.
- working_dir:
    - `TRUELINE_WORKING_DIR_SPACE_BETWEEN_PATH_SEPARATOR=true`: boolean variable that
    determines whether to add (or not) a space before and after the path separator.
    - `TRUELINE_WORKING_DIR_ABBREVIATE_PARENT_DIRS=false`: boolean variable that when
    set to true shows the full working directory (instead of trimming it). Each parent
    directory is shortened to `TRUELINE_WORKING_DIR_ABBREVIATE_PARENT_DIRS_LENGTH`.
    - `TRUELINE_WORKING_DIR_ABBREVIATE_PARENT_DIRS_LENGTH=1`: length of each parent
        directory when `TRUELINE_WORKING_DIR_ABBREVIATE_PARENT_DIRS` is enabled.

#### External

- `TRUELINE_SHOW_VIMODE=false`: boolean variable that determines whether or not to show
    the current vi mode (if this is set to `true` and vi-mode is not already enabled then
    Trueline will enabled it; vi-mode must be otherwise enabled separately in your
    `.bashrc` via `set -o vi`). When set to `true` a new segment is shown first (i.e
    before any other segment defined in `TRUELINE_SEGMENTS`) and it's appearance can be
    controlled by means of the following variables:
    - `TRUELINE_VIMODE_INS_COLORS_STYLE=('black' 'light_blue' 'bold')`: insert mode
    segment foreground/background colors and font style.
    - `TRUELINE_VIMODE_CMD_COLORS_STYLE=('black' 'green' 'bold')`: command mode
    segment foreground/background colors and font style.
    - `TRUELINE_VIMODE_INS_CURSOR='vert'`: insert mode cursor shape (possible
    values are `vert`, `block` and `under`).
    - `TRUELINE_VIMODE_CMD_CURSOR='block'`: command mode cursor shape (possible
    values are `vert`, `block` and `under`).

### Extensions

New segments can be easily added to the prompt by following this template:

```bash
_trueline_new_segment_name_segment() {
    local some_content=$(...)
    if [[ -n "$some_content" ]]; then
        local fg_color="$1"
        local bg_color="$2"
        local font_style="$3"
        local segment="$(_trueline_separator)"
        segment+="$(_trueline_content "$fg_color" "$bg_color" "$font_style" " $some_content ")"
        PS1+="$segment"
        _trueline_record_colors "$fg_color" "$bg_color" "$font_style"
    fi
}
```

and then simply including the `new_segment_name` in your `TRUELINE_SEGMENTS` array.

PRs with complicated segments are welcome!
