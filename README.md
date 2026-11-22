# scribble-minor-mode
`scribble-minor-mode` is a minor mode for editing Racket scribble files in Emacs.

It is inspired by Neil Van Dyke's [scribble mode](https://www.neilvandyke.org/scribble-emacs/). Under the hood, `scribble-mode` does limited parsing on its own, whereas `scribble-minor-mode` leaves such heavy-lifting jobs to `racket-hash-lang-mode`. 

`scribble-minor-mode` provides a uniform transient menu for compiling scribble files.

## Multi-file documents

As with AUCTeX's `TeX-master`, a file that is part of a larger document can name its master file in a file-local variable at its end. Compile, view and watch commands invoked from that file then act on the master:

```
@;; Local Variables:
@;; scribble-master: "main.scrbl"
@;; End:
```

The path is relative to the file's directory, and `.scrbl` may be omitted. The value `t` means the file is its own master. In Rhombus files use `@//` instead of `@;;`.

When a file names no master, opening it asks for one (press `RET` for the file itself) and adds the answer as the local variable above; save the file to keep it. `M-x scribble-set-master` (also in the Scribble menu) changes it later. To never be asked, `(setq-default scribble-master t)`.
