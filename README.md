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


