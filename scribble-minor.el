;; -*- lexical-binding: t; -*-
;; $Id: scribble.el,v 1.49 2015/11/03 17:54:56 user Exp $
;; Package-Requires: ((emacs "28.1") (transient "0.3.7") (racket-mode "20250528"))

;; This minor mode is inspired by the original scribble-mode by Neil Van Dyke (see https://www.neilvandyke.org/scribble-emacs/).

(defconst scribble-minor-mode-title   "Racket Scribble Emacs Minor Mode")
(defconst scribble-minor-mode-version "0.1")

;;-------------------------------------------------------------------- Requires

(require 'cl-lib)
(require 'compile)
(require 'imenu)
(require 'outline)
(require 'transient)

;;---------------------------------------------------------------------- Custom

(defgroup scribble
  nil
  "Racket Scribble Emacs Minor Mode"
  :group 'wp
  :prefix "scribble-")

(defface scribble-comment-face
  '((t :foreground "cyan"))
  "Face for Comments in Scribble mode."
  :group 'scribble)

(defface scribble-title-face
  '((t :height 2.0736 :slant italic))
  "Face for titles in Scribble mode."
  :group 'scribble)

(defface scribble-section-heading-face
  '((t :height 2.0736 :weight bold))
  "Face for section headings in Scribble mode."
  :group 'scribble)

(defface scribble-subsection-heading-face
  '((t :height 1.728 :weight bold))
  "Face for subsection headings in Scribble mode."
  :group 'scribble)

(defface scribble-subsubsection-heading-face
  '((t :height 1.44 :weight bold))
  "Face for subsubsection headings in Scribble mode."
  :group 'scribble)

(defface scribble-sub*section-heading-face
  '((t :height 1.2 :weight bold))
  "Face for deep-subsection headings in Scribble mode."
  :group 'scribble)

(defface scribble-bold-face
  '((t  :weight bold))
  "Face for @bold in Scribble mode."
  :group 'scribble)

(defface scribble-emph-face
  '((t  :slant italic))
  "Face for @emph in Scribble mode."
  :group 'scribble)

(defface scribble-italic-face
  '((t  :slant italic))
  "Face for @italic in Scribble mode."
  :group 'scribble)

(defface scribble-tt-face
  '((t :inherit fixed-pitch))
  "Face for @tt in Scribble mode."
  :group 'scribble)

(defface scribble-link-text-face
  '((t :underline t :foreground "blue"))
  "Face for link text in Scribble mode."
  :group 'scribble)

(defface scribble-racket-result-face
  '((t :foreground "blue3"))
  "Face for Racket results in Scribble mode."
  :group 'scribble)

(defface scribble-racket-value-face
  '((t :foreground "green2"))
  "Face for Racket values in Scribble mode."
  :group 'scribble)

(defface scribble-bnf-nonterm-face
  '((t :slant italic))
  "Face for @nonterm in Scribble mode."
  :group 'scribble)

(defface scribble-racket-litchar-face
  '((t :foreground "#aaaa00"
       :background "#f4f4f4"
       :slant      normal
       :weight     normal))
  "Face for @litchar in Scribble mode."
  :group 'scribble)

;;---------------------------------------------------- Customization Procedures

(defun scribble-customize ()
  (interactive)
  (customize-group 'scribble))

;; TODO: Implement making any non-face changes take effect.

;;-------------------------------------------------------------- Scribble Forms

(defsubst scribble-get-form-name (form) (car form))
(defsubst scribble-get-form-face (form) (cdr form))

(defconst scribble-forms
  '(
    ;; scribble/base
    (title . scribble-title-face)
    (section . scribble-section-heading-face)
    (subsection . scribble-subsection-heading-face)
    (subsubsection . scribble-subsubsection-heading-face)
    (sub*section . scribble-sub*section-heading-face)
    (italic . scribble-italic-face)
    (bold . scribble-bold-face)
    (tt . scribble-tt-face)
    (emph . scribble-emph-face)
    (hyperlink . scribble-link-text-face)
    (secref . scribble-link-text-face)
    (seclink . scribble-link-text-face)
    (author) (author+email) (para) (nested) (centered) (margin-note)
    (margin-note*) (itemlist) (item) (tabular) (verbatim) (elem) (code)
    (codeblock) (subscript) (superscript) (smaller) (larger) (linebreak)
    (hspace) (literal) (image) (url) (other-doc) (elemtag) (elemref) (index)
    (index*) (as-index) (section-index) (index-section) (table-of-contents)
    (local-table-of-contents)
    ;; scribble/manual
    (racketresult . scribble-racket-result-face)
    (litchar . scribble-racket-litchar-face)
    (racketvalfont . scribble-racket-value-face)
    (racketresultfont . scribble-racket-result-face)
    (racketblock) (RACKETBLOCK) (racketblock0) (RACKETBLOCK0)
    (racketresultblock) (RACKETRESULTBLOCK) (racketresultblock0)
    (RACKETRESULTBLOCK0) (racketinput) (RACKETINPUT) (racketmod) (racket)
    (RACKET) (racketid) (racketmodlink) (racketfont) (racketidfont)
    (racketvarfont) (racketkeywordfont) (racketparenfont) (racketmetafont)
    (racketerror) (racketmodfont) (racketoutputfont) (procedure) (var) (svar)
    ;; scribble/bnf
    (nonterm . scribble-bnf-nonterm-face)
    (BNF-etc . scribble-comment-face)
    (BNF) (BNF-seq) (BNF-group) (optional) (kleenestar) (kleeneplus)
    (kleenerange) (BNF-alt))
  "Scribble forms known to `scribble-minor-mode', as (NAME . FACE).
When FACE is non-nil, it is applied to the form's body.")

;;----------------------------------------------------------------------- Imenu

(defvar scribble-imenu-generic-expression
  '((nil
     "@\\(?:sub\\(?:sub\\)?\\)?section\\(?:\\[[^]]*\\]\\|([^)]*)\\)*{\\([^}]*\\)"
     1)))

;; TODO: Use one of the lower-level ways of doing this.

;;-------------------------------------------------------------- Buffer Display

(defun scribble-buffer-display (name proc)
  (with-current-buffer (get-buffer-create name)
    (let ((inhibit-read-only t))
      (buffer-disable-undo)
      (erase-buffer)
      (funcall proc)
      (buffer-enable-undo))
    (set-buffer-modified-p nil)
    (setq buffer-read-only t)
    (goto-char (point-min))
    ;; TODO: Maybe make "q" restore window config.
    (local-set-key "q" 'scribble-quit-buffer-display)
    (pop-to-buffer (current-buffer))
    (message "Press \"q\" to quit the \"%s\" buffer." name)))

(defun scribble-quit-buffer-display ()
  (interactive)
  (let ((buf (current-buffer)))
    (condition-case nil
        (delete-window)
      (error nil))
    (kill-buffer buf)))

;;----------------------------------------------------------------------- About

(defun scribble-about ()
  (interactive)
  (scribble-buffer-display
   "*About Scribble Mode*"
   (function 
    (lambda ()
      (insert (propertize scribble-minor-mode-title 'face 'bold)
              "\n\n"
              "Version "
              (propertize scribble-minor-mode-version 'face 'bold)
              "\n")))))

;;------------------------------------------------------------------ Minor Mode

;; `racket-hash-lang-mode' already gets lexing, indentation, comments, paren
;; matching and text filling from the "#lang" itself, and `racket-xp-mode'
;; covers documentation and completion.  This minor mode adds only what
;; hash-lang does not: faces for prose forms, imenu, outline, and a few
;; editing commands.

(defcustom scribble-minor-mode-module-language-regexp
  (rx bos (? "rhombus/") "scribble" (or eos "/"))
  "Regexp matched against a lang's \"module-language\" string.
When it matches, `scribble-minor-mode' is enabled in that
`racket-hash-lang-mode' buffer."
  :type 'regexp
  :group 'scribble)

;;;###autoload
(defun scribble-minor-mode-maybe-enable (module-language)
  "Enable `scribble-minor-mode' when MODULE-LANGUAGE is a Scribble lang.
Intended for `racket-hash-lang-module-language-hook'."
  (when (and module-language
             (string-match-p scribble-minor-mode-module-language-regexp
                             module-language))
    (scribble--set-comment-delimiters module-language)
    (scribble-minor-mode 1)))

(defun scribble--xp-eldoc-around (fn &rest args)
  "Around advice for `racket-xp-eldoc-point-or-sexp-head'.
That function runs on every cursor move and calls `backward-up-list',
which in `racket-hash-lang-mode' does one blocking back-end round trip
per sexp -- per word, in prose -- making movement lag in Scribble
buffers.  There, find the enclosing form with the syntax table instead."
  (if (bound-and-true-p scribble-minor-mode)
      (let ((forward-sexp-function nil))
        (apply fn args))
    (apply fn args)))

(advice-add 'racket-xp-eldoc-point-or-sexp-head
            :around #'scribble--xp-eldoc-around)

(defcustom scribble-comment-starts
  '(("\\`rhombus/" . "@//")
    (""            . "@;;"))
  "Alist from module-language regexps to line comment starts.
The first entry whose regexp matches the lang wins.  These replace the
delimiters `racket-hash-lang-mode' gets from the lang, which are the
host language's (\"//\" for Rhombus) rather than the ones for prose."
  :type '(alist :key-type regexp :value-type string)
  :group 'scribble)

(defun scribble--set-comment-delimiters (module-language)
  "Set the comment variables for MODULE-LANGUAGE, a Scribble lang.
`racket-hash-lang-mode' sets them just before running
`racket-hash-lang-module-language-hook', so we override them there."
  (let ((start (assoc-default module-language scribble-comment-starts
                              #'string-match-p)))
    (when start
      (setq-local comment-start      start)
      (setq-local comment-continue   start)
      (setq-local comment-end        "")
      (setq-local comment-padding    " ")
      (setq-local comment-use-syntax nil)
      (setq-local comment-start-skip nil)
      (setq-local comment-end-skip   nil)
      (comment-normalize-vars))))

;;;###autoload
(add-hook 'racket-hash-lang-module-language-hook
          #'scribble-minor-mode-maybe-enable)

;; Font-Lock:

;; (defcustom scribble-hide-markup t
;;   "When non-nil, hide the markup around forms in `scribble-hide-markup-forms'.
;; For example, show \"@bold{word}\" as just \"word\" in bold.  Toggle in a
;; buffer with `scribble-toggle-markup-hiding'."
;;   :type 'boolean
;;   :group 'scribble)

;; (defcustom scribble-hide-markup-forms '(bold italic emph section)
;;   "Forms whose \"@name{\" and \"}\" are hidden when `scribble-hide-markup'.
;; Changes take effect after reloading scribble.el."
;;   :type '(repeat symbol)
;;   :group 'scribble)

;; (defcustom scribble-reveal-markup-at-point t
;;   "When non-nil, show hidden markup of the form containing point.
;; Only matters when `scribble-hide-markup' is non-nil."
;;   :type 'boolean
;;   :group 'scribble)

;; (defconst scribble--hide-markup-open-rx
;;   (concat "@" (regexp-opt (mapcar #'symbol-name scribble-hide-markup-forms))
;;           "\\_>\\(?:\\[[^]]*\\]\\)?{")
;;   "Regexp matching the opening \"@name[...]{\" of a form with hidden markup.")

;; (defvar-local scribble--revealed nil
;;   "Markers (BEG . END) of the form whose markup is revealed, or nil.")

;; (defun scribble--markup-facespec ()
;;   "Font-lock facespec for hidden markup of the form just matched.
;; Leaves the markup visible when the form is the revealed one."
;;   (unless (and scribble--revealed
;;                (= (match-beginning 0) (car scribble--revealed)))
;;     '(face nil invisible scribble-markup)))

(defun scribble--skip-form-args (limit)
  "Skip \"[...]\" and \"(...)\" argument groups at point, up to LIMIT.
Return the position of the body's opening `{' if point then is at
one, else nil.  Groups are skipped with `scan-lists', so they may nest
and contain strings."
  (let ((ok t))
    (while (and ok (< (point) limit) (memq (char-after) '(?\[ ?\()))
      (let ((end (ignore-errors (scan-lists (point) 1 0))))
        (if end (goto-char end) (setq ok nil))))
    (and ok (eq (char-after) ?{) (point))))

(defun scribble--search-start (pos)
  "Where to start searching for forms that may cover POS.
That is the start of the line holding the outermost bracket enclosing
POS, or of POS's own line when no bracket encloses it.  Argument groups
right before that bracket are included, as they may span lines, as in
\"@section(~tag:\\n \\\"t\\\"){Title}\"."
  (save-excursion
    (let ((p pos) up)
      (while (setq up (ignore-errors (scan-lists p -1 1)))
        (setq p up))
      (goto-char p)
      (while (and (memq (char-before) '(?\] ?\)))
                  (setq up (ignore-errors (scan-lists (point) -1 0))))
        (goto-char up))
      (line-beginning-position))))

(defun scribble--make-body-matcher (name-rx)
  "Return a font-lock matcher for @NAME-RX ARGS {BODY}.
ARGS is any sequence of \"[...]\" (Racket) and \"(...)\" (Rhombus) groups.
On success, match group 1 spans BODY, up to the balancing `}';
group 2 spans the opening \"@NAME ARGS {\" and group 3 the closing `}'.
Groups 1-3 are clipped to the region being fontified.

The region may start in the middle of a form: `racket-hash-lang-mode'
refontifies just the changed text (or the changed tokens), without
`font-lock-extend-region-functions'.  So a pass starts searching from
`scribble--search-start' of the region start, skips forms that end
before the region, and clips the rest to it -- re-applying a `prepend'
face to text outside the region would stack duplicates."
  (let ((rx (concat "@" name-rx "\\_>"))
        (pass nil))                     ; (BUFFER LIMIT START) of this pass
    (lambda (limit)
      ;; The first call of a pass has point at the region start.
      (unless (and pass
                   (eq (nth 0 pass) (current-buffer))
                   (= (nth 1 pass) limit))
        (setq pass (list (current-buffer) limit (point)))
        (goto-char (scribble--search-start (point))))
      (let ((start (nth 2 pass))
            found)
        (cl-flet ((clip (b e)
                    (let ((b (max b start)))
                      (list b (max b (min e limit))))))
          (while (and (not found) (re-search-forward rx limit t))
            (let* ((beg (match-beginning 0))
                   (after-name (point))
                   (open (scribble--skip-form-args limit))
                   (close (and open
                               (condition-case nil
                                   (1- (scan-lists open 1 0))
                                 (scan-error nil)))))
              (cond
               ((not close)
                (goto-char after-name))
               ((< close start)
                ;; Entirely before the region, nested forms too.
                (goto-char (1+ close)))
               (t
                ;; Continue inside the body, so nested forms match too.
                ;; Point stays past BEG, as font-lock requires.
                (goto-char (1+ open))
                (set-match-data (append (list beg (1+ close))
                                        (clip (1+ open) close)
                                        (clip beg (1+ open))
                                        (clip close (1+ close))))
                (setq found t))))))
        ;; A pass ends when we return nil or point reaches LIMIT.
        (when (or (not found) (>= (point) limit))
          (setq pass nil))
        found))))

(defconst scribble--semantic-font-lock-keywords
  ;; Group forms by (FACE . HIDE-MARKUP?) so each group is one regexp.
  (let ((groups '()))
    (dolist (form scribble-forms)
      (let ((face (scribble-get-form-face form)))
        (when face
          (let* ((sym  (scribble-get-form-name form))
                 (key  (cons face nil)) ; markup hiding disabled
                 ;; (key  (cons face (and (memq sym scribble-hide-markup-forms) t)))
                 (pair (assoc key groups)))
            (if pair
                (push (symbol-name sym) (cdr pair))
              (push (list key (symbol-name sym)) groups))))))
    (mapcar (lambda (group)
              (let ((face (car (car group))))
                ;; (hide (cdr (car group)))
                `(,(scribble--make-body-matcher (regexp-opt (cdr group)))
                  (1 ',face prepend)
                  ;; ,@(and hide
                  ;;        '((2 (scribble--markup-facespec) prepend)
                  ;;          (3 (scribble--markup-facespec) prepend)))
                  )))
            groups))
  "Font-lock keywords giving prose forms (headings, bold, ...) their faces.
These are layered over the lexer token faces from `racket-hash-lang-mode'.")

;; Outline:

(defconst scribble-outline-regexp
  "@\\(?:title\\|\\(?:sub\\)\\{0,2\\}section\\|sub\\*section\\)\\_>"
  "Value for `outline-regexp' in `scribble-minor-mode'.")

(defun scribble-outline-level ()
  "Value for `outline-level' in `scribble-minor-mode'."
  (save-excursion
    (save-match-data
      (looking-at scribble-outline-regexp)
      (let ((s (match-string 0)))
        (cond ((equal s "@title")         1)
              ((equal s "@section")       2)
              ((equal s "@subsection")    3)
              ((equal s "@subsubsection") 4)
              (t                          5))))))

;; Commands:

(defun scribble-wrap-region (name)
  "Wrap the active region in @NAME{...}, or insert @NAME{} at point."
  (interactive
   (list (completing-read "Form: "
                          (mapcar (lambda (form)
                                    (symbol-name (scribble-get-form-name form)))
                                  scribble-forms))))
  (if (use-region-p)
      (let ((beg (region-beginning))
            (end (copy-marker (region-end))))
        (goto-char beg)
        (insert "@" name "{")
        (goto-char end)
        (insert "}")
        (set-marker end nil))
    (insert "@" name "{}")
    (backward-char 1)))

;; (defun scribble--hidden-form-at-point ()
;;   "Return (BEG . END) of the innermost hidden-markup form around point.
;; Point counts as inside from just before \"@\" to just after the closing `}'."
;;   (save-excursion
;;     (save-match-data
;;       (let ((pt (point)))
;;         (or
;;          ;; Point in or right before the opening "@name[...]{".
;;          (let ((at (if (eq (char-after) ?@)
;;                        (point)
;;                      (save-excursion
;;                        (and (search-backward "@" (line-beginning-position) t)
;;                             (point))))))
;;            (when (and at (progn (goto-char at)
;;                                 (looking-at scribble--hide-markup-open-rx))
;;                       (<= pt (match-end 0)))
;;              (let ((close (ignore-errors (scan-lists (1- (match-end 0)) 1 0))))
;;                (and close (cons at close)))))
;;          ;; Point in the body, or right after the closing `}'.
;;          (let ((pos (if (eq (char-before pt) ?}) (1- pt) pt))
;;                (result nil)
;;                (depth 0))
;;            (while (and (not result) pos (< depth 20))
;;              (setq pos (ignore-errors (scan-lists pos -1 1)))
;;              (setq depth (1+ depth))
;;              (when (and pos (eq (char-after pos) ?{))
;;                (goto-char (1+ pos))
;;                (when (looking-back scribble--hide-markup-open-rx
;;                                    (line-beginning-position))
;;                  (let ((close (ignore-errors (scan-lists pos 1 0))))
;;                    (when close
;;                      (setq result (cons (match-beginning 0) close)))))))
;;            result))))))

;; (defun scribble--update-reveal (&optional force-none)
;;   "Reveal the markup of the hidden-markup form at point, re-hiding the old one.
;; With FORCE-NONE, just re-hide."
;;   (let* ((new (and (not force-none)
;;                    scribble-hide-markup
;;                    scribble-reveal-markup-at-point
;;                    (scribble--hidden-form-at-point)))
;;          (old scribble--revealed))
;;     (unless (and old new
;;                  (= (car new) (car old))
;;                  (= (cdr new) (cdr old)))
;;       (when (or old new)
;;         (setq scribble--revealed
;;               (and new (cons (copy-marker (car new)) (copy-marker (cdr new)))))
;;         (when old
;;           (let ((beg (marker-position (car old)))
;;                 (end (marker-position (cdr old))))
;;             (set-marker (car old) nil)
;;             (set-marker (cdr old) nil)
;;             (when (and beg end (< beg end))
;;               (font-lock-flush beg (min end (point-max))))))
;;         (when new
;;           (font-lock-flush (car new) (cdr new)))))))

;; (defun scribble--reveal-post-command ()
;;   (scribble--update-reveal))

;; (defun scribble--apply-markup-hiding ()
;;   (if scribble-hide-markup
;;       (add-to-invisibility-spec 'scribble-markup)
;;     (remove-from-invisibility-spec 'scribble-markup)))

;; (defun scribble-toggle-markup-hiding (&optional arg)
;;   "Toggle hiding of markup around bold/italic forms in this buffer.
;; With a prefix ARG, hide markup when ARG is positive, show it otherwise.
;; See `scribble-hide-markup-forms'."
;;   (interactive "P")
;;   (setq-local scribble-hide-markup
;;               (if (null arg)
;;                   (not scribble-hide-markup)
;;                 (> (prefix-numeric-value arg) 0)))
;;   (scribble--apply-markup-hiding)
;;   (message "Scribble markup %s" (if scribble-hide-markup "hidden" "shown")))

;; Compile:

(defcustom scribble-view-program
  (pcase system-type
    ('darwin "open")
    ((or 'windows-nt 'ms-dos 'cygwin) nil)
    (_ "xdg-open"))
  "External program `scribble-view' uses to open output files.
When nil, use the system's default handler on Windows, else visit the
file in Emacs."
  :type '(choice (string :tag "Program")
                 (const :tag "Default handler / Emacs" nil))
  :group 'scribble)

(defcustom scribble-raco-program "raco"
  "Program used to run \"raco scribble\"."
  :type 'string
  :group 'scribble)

(defconst scribble--format-outputs
  '(("--html"      . ".html")
    ("--htmls"     . "/index.html")
    ("--markdown"  . ".md")
    ("--text"      . ".txt")
    ("--pdf"       . ".pdf")
    ("--xelatex"   . ".pdf")
    ("--lualatex"  . ".pdf")
    ("--typst-pdf" . ".pdf")
    ("--latex"     . ".tex")
    ("--typst"     . ".typ"))
  "Alist from raco scribble format flags to output file suffixes.")

(defcustom scribble-master nil
  "The master file of this Scribble document, as in AUCTeX's `TeX-master'.
When t, the current file is the one to compile, view and watch.  When
a string, it names the master file, relative to the directory of the
current file; a name without an extension may omit \".scrbl\".  When
nil, the master is unknown: opening the file asks for it, and records
the answer as a file-local variable at the end of the file:

  @;; Local Variables:
  @;; scribble-master: \"main.scrbl\"
  @;; End:

Set the default to t to never ask and treat every file as its own
master."
  :type '(choice (const :tag "Ask" nil)
                 (const :tag "This file" t)
                 (string :tag "Master file"))
  :group 'scribble)
(make-variable-buffer-local 'scribble-master)
;;;###autoload
(put 'scribble-master 'safe-local-variable
     (lambda (v) (or (booleanp v) (stringp v))))

(defun scribble--master-file (file master)
  "The master file of FILE given MASTER, a value of `scribble-master'."
  (if (not (stringp master))
      file
    (let ((path (expand-file-name master (file-name-directory file))))
      (cond ((file-exists-p path) path)
            ((and (not (file-name-extension path))
                  (file-exists-p (concat path ".scrbl")))
             (concat path ".scrbl"))
            (t (user-error "Master file %s does not exist" path))))))

(defun scribble--read-master (file)
  "Ask for the master file of FILE; return a value of `scribble-master'."
  (let* ((dir (file-name-directory file))
         (master (expand-file-name
                  (read-file-name "Master file (default this file): "
                                  dir file t nil
                                  (lambda (f)
                                    (or (file-directory-p f)
                                        (string-suffix-p ".scrbl" f)))))))
    (if (file-equal-p master file)
        t
      (file-relative-name master dir))))

(defun scribble-set-master (master)
  "Set the master file of the current buffer to MASTER.
Interactively, ask for it.  Also record it as a file-local variable,
so it is used the next time the file is visited."
  (interactive
   (list (scribble--read-master
          (or buffer-file-name (user-error "Buffer is not visiting a file")))))
  (setq scribble-master master)
  (save-excursion
    (add-file-local-variable 'scribble-master master))
  master)

(defun scribble--maybe-ask-master (buffer)
  "Ask for the master of BUFFER if it has none and is selected."
  (when (and (buffer-live-p buffer)
             (eq buffer (window-buffer (selected-window)))
             (not (minibufferp)))
    (with-current-buffer buffer
      (when (and (bound-and-true-p scribble-minor-mode) buffer-file-name
                 (scribble--master-unknown-p))
        (scribble-set-master (scribble--read-master buffer-file-name))))))

(defun scribble--master-unknown-p ()
  "Non-nil if the current buffer's master must be asked for."
  (and (null scribble-master) (not noninteractive)))

(defun scribble--source-file ()
  "The file to compile, view or watch: the master of the current file.
When the master is unknown, ask for it; see `scribble-master'."
  (let ((file (or buffer-file-name
                  (user-error "Buffer is not visiting a file"))))
    (when (scribble--master-unknown-p)
      (scribble-set-master (scribble--read-master file)))
    (scribble--master-file file scribble-master)))

(defun scribble--read-directory (prompt initial-input _history)
  (expand-file-name (read-directory-name prompt nil nil nil initial-input)))

(defun scribble--read-file (prompt initial-input _history)
  (expand-file-name (read-file-name prompt nil nil t initial-input)))

(defun scribble--expand-args (args)
  "Split transient's \"--opt=VAL\" ARGS into \"--opt\" \"VAL\" for raco."
  (mapcan (lambda (arg)
            (if (string-match "\\`\\([-+][-+][^=]+\\)=\\(.*\\)\\'" arg)
                (list (match-string 1 arg) (match-string 2 arg))
              (list arg)))
          args))

(defun scribble--output-file (args)
  "Guess the file raco scribble writes for the current buffer given ARGS."
  (let* ((file (scribble--source-file))
         (format (seq-find (lambda (a) (assoc a scribble--format-outputs)) args))
         (suffix (cdr (assoc (or format "--html") scribble--format-outputs)))
         (dest (or (transient-arg-value "--dest=" args)
                   (file-name-directory file)))
         (name (file-name-sans-extension
                (or (transient-arg-value "--dest-name=" args)
                    (file-name-nondirectory file)))))
    (expand-file-name (concat name suffix) dest)))

(defvar-local scribble--last-compile-args nil
  "Arguments of the last `scribble-compile-run' in this buffer.")

(defun scribble--compile-args ()
  "Arguments for compiling or viewing the current buffer.
Inside `scribble-compile', its current arguments; otherwise those of the
last compile in this buffer, else the saved `scribble-compile' value."
  (cond ((eq transient-current-command 'scribble-compile)
         (transient-args 'scribble-compile))
        (scribble--last-compile-args)
        ((alist-get 'scribble-compile transient-values))
        (t '("--typst-pdf"))))

(defun scribble-compile-run (&optional args)
  "Run raco scribble on the current master file with ARGS.
ARGS come from `scribble-compile'.  See `scribble-master'."
  (interactive (list (scribble--compile-args)))
  (setq args (or args (scribble--compile-args)))
  (let* ((file (scribble--source-file))
         (default-directory (file-name-directory file)))
    (setq scribble--last-compile-args args)
    (compile (mapconcat #'shell-quote-argument
                        `(,scribble-raco-program "scribble"
                          ,@(scribble--expand-args args)
                          ,(file-name-nondirectory file))
                        " "))))

(defun scribble-view (&optional args)
  "View the output of compiling the current master file with ARGS.
ARGS default to those of the last compile (see `scribble--compile-args').
The file is opened with `scribble-view-program'."
  (interactive (list (scribble--compile-args)))
  (setq args (or args (scribble--compile-args)))
  (let ((out (scribble--output-file args)))
    (unless (file-exists-p out)
      (user-error "No output yet: %s" out))
    (cond (scribble-view-program
           (call-process scribble-view-program nil 0 nil out))
          ((fboundp 'w32-shell-execute)
           (w32-shell-execute "open" out))
          (t (find-file out)))))

;; Watch:

(defun scribble--watch-buffer-name (file)
  (format "*scribble-watch: %s*" (file-name-nondirectory file)))

(define-derived-mode scribble-watch-log-mode compilation-mode "Scribble-Watch"
  "Major mode for the output of \"raco scribble --watch\".
Errors are clickable as in `compilation-mode'."
  (setq-local compilation-error-screen-columns nil))

(defun scribble--watch-process ()
  "The live \"raco scribble --watch\" process of the current master, or nil.
The process belongs to the master file, so it is shared by every file
naming that master in `scribble-master'."
  ;; Called from the menu, so never ask for an unknown master: no watcher
  ;; can have been started without one.
  (let* ((log (and (not (scribble--master-unknown-p))
                   (get-buffer (scribble--watch-buffer-name
                                (scribble--source-file)))))
         (proc (and log (get-buffer-process log))))
    (and proc (process-live-p proc) proc)))

(defun scribble--watch-live-p ()
  (and (scribble--watch-process) t))

(defun scribble--watch-stop-owned ()
  "Stop the watchers started from the current buffer.
For `kill-buffer-hook'."
  (let ((buf (current-buffer)))
    (dolist (proc (process-list))
      (when (eq (process-get proc 'scribble-owner) buf)
        (delete-process proc)))))

(defun scribble--watch-sentinel (proc event)
  (let ((buf (process-buffer proc)))
    (when (buffer-live-p buf)
      (with-current-buffer buf
        (let ((inhibit-read-only t))
          (save-excursion
            (goto-char (point-max))
            (insert (format "\n[scribble-watch %s at %s]\n"
                            (string-trim event)
                            (format-time-string "%T")))))))))

(defun scribble-watch (&optional args)
  "Run \"raco scribble --watch\" on the current master file with ARGS.
See `scribble-master'.
The file is re-rendered whenever it or a local dependency changes.
Output accumulates in a dedicated log buffer; see `scribble-watch-log'.
ARGS default to those of `scribble-compile' (see `scribble--compile-args')."
  (interactive (list (scribble--compile-args)))
  (setq args (or args (scribble--compile-args)))
  (let* ((file (scribble--source-file))
         (default-directory (file-name-directory file))
         (log (get-buffer-create (scribble--watch-buffer-name file)))
         (cmd `(,scribble-raco-program "scribble" "--watch"
                ,@(scribble--expand-args args)
                ,(file-name-nondirectory file))))
    (when (scribble--watch-live-p)
      (if (y-or-n-p "Watcher already running; restart it? ")
          (scribble-watch-stop)
        (user-error "Watcher already running")))
    (setq scribble--last-compile-args args)
    (with-current-buffer log
      (unless (derived-mode-p 'scribble-watch-log-mode)
        (scribble-watch-log-mode))
      (setq default-directory (file-name-directory file))
      (let ((inhibit-read-only t))
        (goto-char (point-max))
        (unless (bobp) (insert "\n"))
        (insert (format "[scribble-watch started at %s]\n%s\n\n"
                        (format-time-string "%T")
                        (mapconcat #'shell-quote-argument cmd " ")))))
    (process-put (make-process :name "scribble-watch"
                               :buffer log
                               :command cmd
                               :connection-type 'pipe
                               :noquery t
                               :filter #'compilation-filter
                               :sentinel #'scribble--watch-sentinel)
                 'scribble-owner (current-buffer))
    (add-hook 'kill-buffer-hook #'scribble--watch-stop-owned nil t)
    (display-buffer log)
    (message "Watching %s" (file-name-nondirectory file))))

(defun scribble-watch-stop ()
  "Stop the \"raco scribble --watch\" process of the current master file."
  (interactive)
  (let ((proc (scribble--watch-process)))
    (if (not proc)
        (when (called-interactively-p 'interactive)
          (message "No watcher running"))
      (delete-process proc)
      (when (called-interactively-p 'interactive)
        (message "Watcher stopped")))))

(defun scribble-watch-toggle (&optional args)
  "Start `scribble-watch' with ARGS, or stop it if it is running."
  (interactive (list (scribble--compile-args)))
  (if (scribble--watch-live-p)
      (progn (scribble-watch-stop) (message "Watcher stopped"))
    (scribble-watch args)))

(defun scribble-watch-log ()
  "Display the watch log buffer of the current master file."
  (interactive)
  (let ((buf (get-buffer (scribble--watch-buffer-name (scribble--source-file)))))
    (if buf
        (display-buffer buf)
      (user-error "No watch log for this file"))))

;;;###autoload (autoload 'scribble-compile "scribble-minor" nil t)
(transient-define-prefix scribble-compile ()
  "Compile the current Scribble master file with raco scribble.
See `scribble-master'."
  :incompatible '(("--html" "--htmls" "--markdown" "--text"
                   "--pdf" "--xelatex" "--lualatex" "--typst-pdf"
                   "--latex" "--typst"))
  :value '("--typst-pdf")
  ["Format"
   [("h" "HTML"             "--html")
    ("H" "HTML directory"   "--htmls")
    ("m" "Markdown"         "--markdown")
    ("t" "Text"             "--text")]
   [("p" "PDF via pdfLaTeX" "--pdf")
    ("x" "PDF via XeLaTeX"  "--xelatex")
    ("u" "PDF via LuaLaTeX" "--lualatex")
    ("P" "PDF via Typst"    "--typst-pdf")]
   [("l" "LaTeX source"     "--latex")
    ("y" "Typst source"     "--typst")]]
  ["Options"
   [("-d" "Output directory" "--dest=" :reader scribble--read-directory)
    ("-n" "Output name"      "--dest-name=")
    ("-s" "Extra style file" "++style=" :reader scribble--read-file)]
   [("-q" "Quiet"            "--quiet")
    ("-y" "Make (update compiled files)" "--make")
    ("-e" "Errortrace"       "--errortrace")]]
  ["Actions"
   [("c" "Compile"     scribble-compile-run)
    ("v" "View output" scribble-view)]
   [("w" "Watch / stop watching" scribble-watch-toggle)
    ("L" "Watch log"   scribble-watch-log)]])

;; Menu and Keymap:

(defvar scribble-minor-mode-menu
  (let ((km (make-sparse-keymap "Scribble")))
    (define-key km [scribble-about]
      '(menu-item "About Scribble Emacs Mode..." scribble-about
                  :help "See information about Scribble Emacs mode"))
    (define-key km [scribble-separator-1]
      '(menu-item "--"))
    (define-key km [scribble-customize]
      '(menu-item "Customize..." scribble-customize
                  :help "Set Emacs customization options for Scribble"))
;;     (define-key km [scribble-toggle-markup-hiding]
;;       '(menu-item "Hide Markup" scribble-toggle-markup-hiding
;;                   :button (:toggle . scribble-hide-markup)
;;                   :help "Hide @bold{...}-style markup, showing only styled text"))
    (define-key km [scribble-set-master]
      '(menu-item "Set Master File..." scribble-set-master
                  :help "Choose the master file to compile, view and watch"))
    (define-key km [scribble-compile]
      '(menu-item "Compile..." scribble-compile
                  :help "Compile to HTML, PDF, ... with raco scribble"))
    (define-key km [scribble-view]
      '(menu-item "View Output" scribble-view
                  :help "View the output of the last compile"))
    (define-key km [scribble-watch-log]
      '(menu-item "Show Watch Log" scribble-watch-log
                  :help "Display the raco scribble --watch log"))
    (define-key km [scribble-watch-toggle]
      '(menu-item "Watch" scribble-watch-toggle
                  :button (:toggle . (scribble--watch-live-p))
                  :help "Re-render on every change with raco scribble --watch"))
    (define-key km [scribble-wrap-region]
      '(menu-item "Wrap Region in Form..." scribble-wrap-region
                  :help "Wrap the region in @form{...}"))
    km))

(defvar scribble-minor-mode-map
  (let ((km (make-sparse-keymap)))
    (define-key km (kbd "C-c C-b") #'scribble-compile)
    (define-key km (kbd "C-c C-v") #'scribble-view)
    (define-key km (kbd "C-c C-w") #'scribble-wrap-region)
;;     (define-key km (kbd "C-c C-x C-m") #'scribble-toggle-markup-hiding)
    (define-key km [menu-bar Scribble] (cons "Scribble" scribble-minor-mode-menu))
    km))

;; Mode:

;;;###autoload
(define-minor-mode scribble-minor-mode
  "Scribble prose conveniences on top of `racket-hash-lang-mode'.

Enabled automatically for Scribble langs; see
`scribble-minor-mode-module-language-regexp'.

\\{scribble-minor-mode-map}"
  :lighter " Scrbl"
  :keymap scribble-minor-mode-map
  :group 'scribble
  (if scribble-minor-mode
      (progn
        (setq-local imenu-generic-expression scribble-imenu-generic-expression)
        (setq-local imenu-create-index-function
                    #'imenu-default-create-index-function)
        (setq-local imenu-case-fold-search nil)
        (setq-local outline-regexp scribble-outline-regexp)
        (setq-local outline-level #'scribble-outline-level)
        ;; We are enabled from a back-end notification, where prompting
        ;; is unwelcome, so ask for an unknown master once Emacs is idle.
        (when (and buffer-file-name (scribble--master-unknown-p))
          (run-with-idle-timer 0 nil #'scribble--maybe-ask-master
                               (current-buffer)))
;;         (unless (memq 'invisible font-lock-extra-managed-props)
;;           (setq-local font-lock-extra-managed-props
;;                       (cons 'invisible font-lock-extra-managed-props)))
;;         (scribble--apply-markup-hiding)
;;         (add-hook 'post-command-hook #'scribble--reveal-post-command nil t)
        (font-lock-add-keywords nil scribble--semantic-font-lock-keywords
                                'append))
    (font-lock-remove-keywords nil scribble--semantic-font-lock-keywords)
;;     (remove-hook 'post-command-hook #'scribble--reveal-post-command t)
;;     (scribble--update-reveal t)
;;     (remove-from-invisibility-spec 'scribble-markup)
;;     ;; Clear our `invisible' props while font-lock still manages them.
;;     (save-restriction
;;       (widen)
;;       (font-lock-unfontify-region (point-min) (point-max)))
;;     (setq-local font-lock-extra-managed-props
;;                 (remq 'invisible font-lock-extra-managed-props))
    (kill-local-variable 'outline-regexp)
    (kill-local-variable 'outline-level))
  (font-lock-flush))


;;;###autoload
(add-to-list 'auto-mode-alist '("\\.scrbl\\'" . racket-hash-lang-mode))

(provide 'scribble-minor)

;;; scribble-minor.el ends here
