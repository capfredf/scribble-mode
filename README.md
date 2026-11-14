# scribble-minor-mode
`scribble-minor-mode` is a minor mode for editing Racket scribble files in Emacs.

It is inspired by Neil Van Dyke's [scribble mode](https://www.neilvandyke.org/scribble-emacs/). Under the hood, `scribble-mode` does limited parsing on its own, whereas `scribble-minor-mode` leaves such heavy-lifting jobs to `racket-hash-lang-mode`. 

`scribble-minor-mode` provides a uniform transient menu for compiling scribble files.
