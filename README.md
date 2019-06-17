# Trueline: Bash Powerline Style Prompt with True Color Support

Trueline is a fast and extensible [Powerline](https://github.com/powerline/powerline)
style bash prompt with true color (24-bit) and fancy glyph support.

The pure Bash code implementation and overall features are modelled after the excellent
[Pureline](https://github.com/chris-marsh/pureline) command prompt. However Trueline also
adds the ability to use RGB color codes, expands icon/glyph usage across prompt segments
(inspired by [Powerlevel9k](https://github.com/bhilburn/powerlevel9k)) and, among other
goodies, shows the current input mode (when in vi-mode).

![](https://user-images.githubusercontent.com/2583971/59619548-25ff6480-9101-11e9-8c77-5733f094f39e.png)

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
    [black]='36;39;46'
    [default]='36;39;46'
    [white]='208;208;208'
    [green]='152;195;121'
)

declare -a TRUELINE_SEGMENTS=(
    'user,black,white'
    'working_dir,white,black'
    'time,black,green'
)

declare -A TRUELINE_SYMBOLS=(
    [segment_separator]=''
    [working_dir_folder]='...'
    [working_dir_separator]='|'
    [working_dir_home]='~'
)

TRUELINE_SHOW_VIMODE=false

_trueline_time_segment() {
    local prompt_time="\t"
    if [[ -n $prompt_time ]]; then
        local fg_color="$1"
        local bg_color="$2"
        local segment="$(_trueline_separator)"
        segment+="$(_trueline_content "$fg_color" "$bg_color" 1 " $prompt_time ")"
        PS1+="$segment"
        _last_color=$bg_color
    fi
}

source ~/trueline/trueline.sh
```

which generates the following prompt:

![](https://user-images.githubusercontent.com/2583971/59627345-5ef50480-9114-11e9-8a6b-4b2c3e1d5d4f.png)

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

_Note:_ you can define as many colors as you want but you _must always_ include in your
color palette definition a `default` color name. This `default` color is used by the
prompt closing separator (as well as by the continuation prompt) and it should match your
terminal background. This means that if your terminal background color RGB value is
`130;137;151` you should then have an entry like so:

```bash
declare -A TRUELINE_COLORS=(
    [default]='130;137;151'
    # other color definitions...
)
```

### Segments

Prompt segments are defined in an ordered array called `TRUELINE_SEGMENTS` that has the
following structure:

```bash
declare -a TRUELINE_SEGMENTS=(
    'segment_name,segment_fg_color,segment_bg_color'
)
```

where the segment foreground and background color names are keys of the `TRUELINE_COLORS`
array and the order of the elements in the array define the order in which each segment
is rendered in the prompt.

By default Trueline offers the following segments:

| Segment Name | Description |
|--------------|-------------|
| exit_status  | return code of last command |
| git          | git branch/remote and repository status |
| read_only    | indicator of read only directory |
| user         | username and host (conditional on ssh status) |
| venv         | Python virtual environment |
| working_dir  | current working directory |

but more segments can be easily added (see [Extensions](#Extensions)).

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

| Symbol Name | Glyph or Unicode Value |
|-------------|-------------|
| git_ahead | U+f55c |
| git_behind| U+f544 |
| git_bitbucket | U+f171 |
| git_branch | U+e0a0 |
| git_github | U+f408|
| git_gitlab | U+f296|
| git_modified | ✚ |
| ps2 | ... |
| read_only | U+f023 |
| segment_separator | U+e0b0 |
| ssh | U+f817 |
| venv | U+e73c|
| vimode_cmd | N |
| vimode_ins | I |
| working_dir_folder | U+e5fe |
| working_dir_home | U+f015 |
| working_dir_separator | U+e0b1 |

### Options

Most Trueline settings are controlled with the 3 structures defined above. However
Trueline also defines a series of variables that control some extra options. In particular
these, along with their default values, are:

- `TRUELINE_SHOW_VIMODE=false`: boolean variable that determines whether or not to show the
    current vi mode (vi-mode must be enabled separately in your `.bashrc` via `set -o
    vi`). If this variable is set to `true` then a new segment is shown first (i.e before
    any other segment defined in `TRUELINE_SEGMENTS`) and it's appearance can be
    controlled by means of the following variables:
    - `TRUELINE_VIMODE_INS_COLORS=('black' 'light_blue')`: insert mode segment foreground
    and background colors.
    - `TRUELINE_VIMODE_CMD_COLORS=('black' 'green')`: command mode segment foreground
    and background colors.
    - `TRUELINE_VIMODE_INS_CURSOR='vert'`: insert mode cursor shape (possible
    values are `vert`, `block` and `under`).
    - `TRUELINE_VIMODE_CMD_CURSOR='block'`: command mode cursor shape (possible
    values are `vert`, `block` and `under`).
- In-segment options: the following segments have (sub)settings of their own
    - git:
        - `TRUELINE_GIT_MODIFIED_COLOR='red'`: foreground color for symbol and number of
        modified files.
        - `TRUELINE_GIT_BEHIND_AHEAD_COLOR='purple'`: foreground color for symbol and
        number of commits behind/ahead.

### Extensions

New segments can be easily added to the prompt by following this template:

```bash
_trueline_new_segment_name_segment() {
    local some_content=$(...)
    if [[ -n $some_content ]]; then
        local fg_color="$1"
        local bg_color="$2"
        local segment="$(_trueline_separator)"
        segment+="$(_trueline_content "$fg_color" "$bg_color" 1 " $some_content ")"
        PS1+="$segment"
        _last_color=$bg_color
    fi
}
```

and then simply adding the `new_segment_name` to your `TRUELINE_SEGMENTS` array (PRs with
complicated segments are also welcome!)
