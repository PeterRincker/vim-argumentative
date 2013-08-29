# argumentative.vim

Argumentative aids with manipulating and moving between function arguments.

* Shifting arguments with `<,` and `>,`
* Moving between argument boundaries with `[,` and `],`
* New text objects `a,` and `i,`

## Installation

If you don't have a preferred installation method, I recommend
installing [pathogen.vim](https://github.com/tpope/vim-pathogen), and
then simply copy and paste:

    cd ~/.vim/bundle
    git clone git://github.com/PeterRincker/vim-argumentative.git

Once help tags have been generated, you can view the manual with
`:help argumentative`.


## Customization

Argumentative mappings can be changed from the default by simply adding
mappings in your `~/.vimrc` file to argumentative's `<Plug>` mappings.

    nmap [; <Plug>Argumentative_Prev
    nmap ]; <Plug>Argumentative_Next
    xmap [; <Plug>Argumentative_XPrev
    xmap ]; <Plug>Argumentative_XNext
    nmap <; <Plug>Argumentative_MoveLeft
    nmap >; <Plug>Argumentative_MoveRight
    xmap i; <Plug>Argumentative_InnerTextObject
    xmap a; <Plug>Argumentative_OuterTextObject
    omap i; <Plug>Argumentative_OpPendingInnerTextObject
    omap a; <Plug>Argumentative_OpPendingOuterTextObject
