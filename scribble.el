;; -*- lexical-binding: t; -*-
;; $Id: scribble.el,v 1.49 2015/11/03 17:54:56 user Exp $
;; Package-Requires: ((emacs "29.1") (racket-mode "20250528"))

(defconst scribble-mode-title   "Racket Scribble Emacs Mode")
(defconst scribble-mode-version "0.6")
(defconst scribble-mode-date    "2016-02-19")
(defconst scribble-mode-web     "http://www.neilvandyke.org/scribble-emacs/")

(defconst scribble-mode-legal-notices
  "Copyright (c) 2011, 2013, 2015, 2016 Neil Van Dyke.  This program is Free
Software; you can redistribute it and/or modify it under the terms of the GNU
Lesser General Public License as published by the Free Software Foundation;
either version 3 of the License (LGPL 3), or (at your option) any later
version. This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of merchantability or
fitness for a particular purpose.  See http://www.gnu.org/licenses/ for
details.  For other licenses and consulting, please contact the author.")

;; TODO: !!! 2016-02-19 Recover documentation from old PLaneT package.

;; Note: Changes to above info must be reflected in "scribble-emacs.scrbl"
;; and "info.rkt".

;;-------------------------------------------------------------------- Requires

(require 'imenu)
(require 'outline)

;;---------------------------------------------------------------------- Custom

(defgroup scribble
  nil
  "Racket Scribble Emacs Mode"
  :group 'wp
  :prefix "scribble-")

(defface scribble-comment-face
  '((t :foreground "cyan"))
  "Face for Comments in Scribble mode."
  :group 'scribble)

(defface scribble-title-face
  '((t :family "DejaVu Serif" :height 2.0736 :slant italic))
  "Face for titles in Scribble mode."
  :group 'scribble)

(defface scribble-section-heading-face
  '((t :family "DejaVu Serif" :height 2.0736 :weight bold))
  "Face for section headings in Scribble mode."
  :group 'scribble)

(defface scribble-subsection-heading-face
  '((t :family "DejaVu Serif" :height 1.728 :weight bold))
  "Face for subsection headings in Scribble mode."
  :group 'scribble)

(defface scribble-subsubsection-heading-face
  '((t :family "DejaVu Serif" :height 1.44 :weight bold))
  "Face for subsubsection headings in Scribble mode."
  :group 'scribble)

(defface scribble-sub*section-heading-face
  '((t :family "DejaVu Serif" :height 1.2 :weight bold))
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
  '((t  :family "DejaVu Sans Mono"))
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

(defsubst scribble-get-form-name (form) (aref form 0))
(defsubst scribble-get-form-args (form) (aref form 1))
(defsubst scribble-get-form-type (form) (aref form 2))
(defsubst scribble-get-form-face (form) (aref form 3))

;; TODO: Maybe make types be strings.

(defsubst scribble-get-formarg-kind    (arg) (aref arg 0))
(defsubst scribble-get-formarg-name    (arg) (aref arg 1))
(defsubst scribble-get-formarg-type    (arg) (aref arg 2))
(defsubst scribble-get-formarg-default (arg) (aref arg 3))

;; Note: The information is from Racket 5.0.2 Scribble documentation.

(defconst scribble-style-form-type
  '(or/c style? f string? symbol? (listof symbol?)))

(defconst scribble-optional-style-form-arg
  `[k style ,scribble-style-form-type "#f"])

(defconst scribble-optional-underline?-form-arg
  `[k underline? any/c "#t"])

(defconst scribble-optional-tag-form-arg
  `[k tag (or/c false/c string? (listof string?)) "#f"])

(defconst scribble-heading-form-args
  `(,scribble-optional-tag-form-arg
    [k tag-prefix (or/c false/c string? module-path?) "#f"]
    ,scribble-optional-style-form-arg))

;; TODO: Support more than just "scribble/base".

(defconst scribble-base-forms
  `(
    ;; scribble/base
    ;; file:///usr/local/racket-5.0.2/share/racket/doc/scribble/base.html

    [title (,@scribble-heading-form-args
            [k version (or/c string? false/c) "#f"]
            [p -       pre-content?           -]
            ...)
           title-decl?
           scribble-title-face]
    [section       (,@scribble-heading-form-args
                    [p - pre-content? -]
                    ...)
                   part-start?
                   scribble-section-heading-face]
    [subsection    (,@scribble-heading-form-args
                    [p - pre-content? -]
                    ...)
                   part-start?
                   scribble-subsection-heading-face]
    [subsubsection (,@scribble-heading-form-args
                    [p - pre-content? -]
                    ...)
                   part-start?
                   scribble-subsubsection-heading-face]
    [sub*section   (,@scribble-heading-form-args
                    [p - pre-content? -]
                    ...)
                   part-start?
                   scribble-sub*section-heading-face]
    [author ([p - content? -])
            block?
            nil]
    [author+email ([p author     elem    -]
                   [p email      string? -]
                   [k obfuscate? any/c   "#f"])
                  element?
                  nil]
    [para (,scribble-optional-style-form-arg
           [p - pre-content? -]
           ...)
          paragraph?
          nil]
    [nested (,scribble-optional-style-form-arg
             [p - pre-flow? -]
             ...)
            nested-flow?
            nil]
    [centered ([p - pre-flow? -]
               ...)
              nested-flow?
              nil]
    [margin-note ([p - pre-flow? -]
                  ...)
                 block?
                 nil]
    [margin-note* ([p - pre-content? -]
                   ...)
                  element?
                  nil]
    [itemlist ([p - item? -]
               ...
               ,scribble-optional-style-form-arg)
              itemization?
              nil]
    [item ([p - pre-flow? -]
           ...)
          item?
          nil]
    [tabular ([p cells (listof (listof (or/c block? content? 'cont))) -]
              ,scribble-optional-style-form-arg)
             table?
             nil]
    [verbatim ([p indent exact-nonnegative-integer? "0"]
               [p -      string?                    -]
               ...)
              block?
              nil]
    [elem ([p - pre-content? -]
           ...
           ,scribble-optional-style-form-arg)
          element?
          nil]
    [italic ([p - pre-content? -]
             ...)
            element?
            scribble-italic-face]
    [bold ([p - pre-content? -]
           ...)
          element?
          scribble-bold-face]
    [code ([p - pre-content? -]
           ...)
          element?
          nil]
    [codeblock ([p - pre-content? -]
                ...)
               element?
               nil]
    [tt ([p - pre-content? -]
         ...) 
        element?
        scribble-tt-face]
    [subscript ([p - pre-content? -]
                ...) 
               element?
               nil]
    [superscript ([p - pre-content? -]
                  ...) 
                 element?
                 nil]
    [smaller ([p - pre-content? -]
              ...) 
             element?
             nil]
    [larger ([p - pre-content? -]
             ...) 
            element?
            nil]
    [emph ([p - pre-content? -]
           ...) 
          element?
          scribble-emph-face]
    [linebreak ()
               element?
               nil]
    [hspace ([p - exact-nonnegative-integer? -])
            element?
            nil]
    [literal ([p - string? -]
              ...) 
             element?
             nil]
    [image
     ([p path     (or/c path-string? (cons/c 'collects (listof bytes?))) -]
      [k scale    real?                "1.0"]
      [k suffixes (listof (rx "^[.]")) "null"]
      [p -        pre-content?         -]
      ...)
     element?
     nil]
    [hyperlink ([p url string?      -]
                [p -   pre-content? -]
                ...
                ,scribble-optional-underline?-form-arg
                [k style
                   (or/c style? string? symbol? false/c)
                   "(if underline? #f \"plainlink\")"])
               element?
               scribble-link-text-face]
    [url ([p dest string? -])
         element?
         nil]
    [secref ([p tag          string                          -]
             [k doc          (or/c module-path? false/c)     "#f"]
             [k tag-prefixes (or/c (listof string?) false/c) "#f"]
             ,scribble-optional-underline?-form-arg)
            element?
            scribble-link-text-face]
    [seclink ([p tag          string?                         -]
              [k doc          (or/c module-path? false/c)     "#f"]
              [k tag-prefixes (or/c (listof string?) false/c) "#f"]
              ,scribble-optional-underline?-form-arg
              [p -            pre-content?                    -]
              ...)
             element?
             scribble-link-text-face]
    [other-doc ([p module-path module-path? -]
                ,scribble-optional-underline?-form-arg)
               element?
               nil]
    [elemtag ([p t (or/c tag? string?) -]
              [p - pre-content?        -]
              ...)
             element?
             nil]
    [elemref ([p t (or/c tag? string?) -]
              [p - pre-content?        -]
              ...
              ,scribble-optional-underline?-form-arg)
             element?
             nil]
    [index ([p words (or/c string? (listof string?)) -]
            [p -     pre-content?                    -]
            ...)
           index-element?
           nil]
    [index* ([p words         (listof string?) -]
             [p word-contents (listof list?)   -]
             [p -             pre-content?     -]
             ...)
            index-element?
            nil]
    [as-index ([p - pre-content? -]
               ...)
              index-element?
              nil]
    [section-index ([p word string? -]
                    ...)
                   part-index-decl?
                   nil]
    [index-section ([k tag (or/c false/c string?) "\"doc-index\""]
                    ,scribble-optional-tag-form-arg)
                   part?
                   nil]
    [table-of-contents ()
                       delayed-block?
                       nil]
    [local-table-of-contents (,scribble-optional-style-form-arg)
                             delayed-block?
                             nil]))

(defconst scribble-manual-forms
  `(

    [racketblock  ([p - datum? -] ...) any/c nil]
    [RACKETBLOCK  ([p - datum? -] ...) any/c nil]
    [racketblock0 ([p - datum? -] ...) any/c nil]
    [RACKETBLOCK0 ([p - datum? -] ...) any/c nil]

    [racketresultblock  ([p - datum? -] ...) any/c nil]
    [RACKETRESULTBLOCK  ([p - datum? -] ...) any/c nil]
    [racketresultblock0 ([p - datum? -] ...) any/c nil]
    [RACKETRESULTBLOCK0 ([p - datum? -] ...) any/c nil]

    [racketinput ([p - datum? -] ...) any/c nil]
    [RACKETINPUT ([p - datum? -] ...) any/c nil]
    
    [racketmod ([k file string? "#f"]
                [p -    datum?  -]
                ...)
               any/c
               nil]

    [racket ([p - datum? -] ...) any/c nil]
    [RACKET ([p - datum? -] ...) any/c nil]

    ;; TODO: For "racketresult" and "racketid", maybe override body faces.
    [racketresult ([p - datum? -] ...) any/c scribble-racket-result-face]
    [racketid     ([p - datum? -] ...) any/c nil]

    [racketmodlink ([p - datum?            -]
                    [p - pre-content-expr? -]
                    ...)
                   any/c
                   nil]

    [litchar ([p - string? -] ...) element? scribble-racket-litchar-face]

    [racketfont        ([p - pre-content? -] ...) element? nil]
    [racketvalfont     ([p - pre-content? -] ...) element? scribble-racket-value-face]
    [racketresultfont  ([p - pre-content? -] ...) element? scribble-racket-result-face]
    [racketidfont      ([p - pre-content? -] ...) element? nil]
    [racketvarfont     ([p - pre-content? -] ...) element? nil]
    [racketkeywordfont ([p - pre-content? -] ...) element? nil]
    [racketparenfont   ([p - pre-content? -] ...) element? nil]
    [racketmetafont    ([p - pre-content? -] ...) element? nil]
    [racketerror       ([p - pre-content? -] ...) element? nil]
    [racketmodfont     ([p - pre-content? -] ...) element? nil]
    [racketoutputfont  ([p - pre-content? -] ...) element? nil]
    ;; TODO: Define faces for some of the above?

    ;; TODO: We could use overlays to make "@procedure" content have
    ;; "#<procedure:" and ">".
    [procedure         ([p - pre-content? -] ...) element? nil]

    [var  ([p - datum? -] ...) element? nil]
    [svar ([p - datum? -] ...) element? nil]
    
    ;; TODO: Possibly add support for all the "scheme" backword-compatibility
    ;; identifiers.

    ;; TODO: !!! CONTINUE ADDING AFTER
    ;; file:///usr/local/racket-5.0.2/share/racket/doc/scribble/scribble_manual_code.html

    ))

(defconst scribble-bnf-forms
  `([BNF ([p - (cons element? (listof element?)) -] ...) table? nil]

    [nonterm   ([p - pre-content? -] ...) element? scribble-bnf-nonterm-face]
    [BNF-seq   ([p - element?     -] ...) element? nil]
    [BNF-group ([p - pre-content? -] ...) element? nil]

    [optional   ([p - pre-content? -] ...) element? nil]
    [kleenestar ([p - pre-content? -] ...) element? nil]
    [kleeneplus ([p - pre-content? -] ...) element? nil]

    [kleenerange ([p n any/c        -]
                  [p m any/c        -]
                  [p - pre-content? -]
                  ...)
                 element?
                 nil]

    [BNF-alt ([p - element? -] ...) element? nil]
    [BNF-etc ([p - string? -]) void scribble-comment-face]))

(defconst scribble-forms
  `(,@scribble-base-forms
    ,@scribble-manual-forms
    ,@scribble-bnf-forms))

;;----------------------------------------------------------------------- Imenu

(defvar scribble-imenu-generic-expression
  '((nil
     "@\\(?:sub\\(?:sub\\)?\\)?section\\(?:\\[[^]]*\\]\\)?{\\([^}]*\\)"
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

;;---------------------------------------------------------------- Web Browsing

(defun scribble-browse-mode-web ()
  (interactive)
  (browse-url scribble-mode-web))

;; TODO: Add browsing to Scribble documentation.  First try to find URLs to
;; their existing documentation (based "~/.racket" and on dir of "racket"
;; command).  Fall back to public Web version.

;;----------------------------------------------------------------------- About

(defun scribble-about ()
  (interactive)
  (scribble-buffer-display
   "*About Scribble Mode*"
   (function 
    (lambda ()
      (insert (propertize scribble-mode-title 'face 'bold)
              "\n\n"
              "Version "
              (propertize scribble-mode-version 'face 'bold)
              "\n\n"
              (propertize scribble-mode-web 'face 'bold)
              "\n\n"
              scribble-mode-legal-notices
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
    (scribble-minor-mode 1)))

;;;###autoload
(add-hook 'racket-hash-lang-module-language-hook
          #'scribble-minor-mode-maybe-enable)

;; Font-Lock:

(defcustom scribble-hide-markup t
  "When non-nil, hide the markup around forms in `scribble-hide-markup-forms'.
For example, show \"@bold{word}\" as just \"word\" in bold.  Toggle in a
buffer with `scribble-toggle-markup-hiding'."
  :type 'boolean
  :group 'scribble)

(defcustom scribble-hide-markup-forms '(bold italic emph section)
  "Forms whose \"@name{\" and \"}\" are hidden when `scribble-hide-markup'.
Changes take effect after reloading scribble.el."
  :type '(repeat symbol)
  :group 'scribble)

(defcustom scribble-reveal-markup-at-point t
  "When non-nil, show hidden markup of the form containing point.
Only matters when `scribble-hide-markup' is non-nil."
  :type 'boolean
  :group 'scribble)

(defconst scribble--hide-markup-open-rx
  (concat "@" (regexp-opt (mapcar #'symbol-name scribble-hide-markup-forms))
          "\\_>\\(?:\\[[^]]*\\]\\)?{")
  "Regexp matching the opening \"@name[...]{\" of a form with hidden markup.")

(defvar-local scribble--revealed nil
  "Markers (BEG . END) of the form whose markup is revealed, or nil.")

(defun scribble--markup-facespec ()
  "Font-lock facespec for hidden markup of the form just matched.
Leaves the markup visible when the form is the revealed one."
  (unless (and scribble--revealed
               (= (match-beginning 0) (car scribble--revealed)))
    '(face nil invisible scribble-markup)))

(defun scribble--make-body-matcher (name-rx)
  "Return a font-lock matcher for @NAME-RX[...]{BODY}.
On success, match group 1 spans BODY, up to the balancing `}';
group 2 spans the opening \"@NAME[...]{\" and group 3 the closing `}'."
  (let ((rx (concat "@" name-rx "\\_>\\(?:\\[[^]]*\\]\\)?{")))
    (lambda (limit)
      (let (found)
        (while (and (not found) (re-search-forward rx limit t))
          (let* ((open (1- (point)))
                 (close (condition-case nil
                            (1- (scan-lists open 1 0))
                          (scan-error nil))))
            (when close
              (set-match-data (list (match-beginning 0) (1+ close)
                                    (1+ open) close
                                    (match-beginning 0) (1+ open)
                                    close (1+ close)))
              (setq found t))))
        found))))

(defconst scribble--semantic-font-lock-keywords
  ;; Group forms by (FACE . HIDE-MARKUP?) so each group is one regexp.
  (let ((groups '()))
    (dolist (form scribble-forms)
      (let ((face (scribble-get-form-face form)))
        (when face
          (let* ((sym  (scribble-get-form-name form))
                 (key  (cons face (and (memq sym scribble-hide-markup-forms) t)))
                 (pair (assoc key groups)))
            (if pair
                (push (symbol-name sym) (cdr pair))
              (push (list key (symbol-name sym)) groups))))))
    (mapcar (lambda (group)
              (let ((face (car (car group)))
                    (hide (cdr (car group))))
                `(,(scribble--make-body-matcher (regexp-opt (cdr group)))
                  (1 ',face prepend)
                  ,@(and hide
                         '((2 (scribble--markup-facespec) prepend)
                           (3 (scribble--markup-facespec) prepend))))))
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

(defun scribble--hidden-form-at-point ()
  "Return (BEG . END) of the innermost hidden-markup form around point.
Point counts as inside from just before \"@\" to just after the closing `}'."
  (save-excursion
    (save-match-data
      (let ((pt (point)))
        (or
         ;; Point in or right before the opening "@name[...]{".
         (let ((at (if (eq (char-after) ?@)
                       (point)
                     (save-excursion
                       (and (search-backward "@" (line-beginning-position) t)
                            (point))))))
           (when (and at (progn (goto-char at)
                                (looking-at scribble--hide-markup-open-rx))
                      (<= pt (match-end 0)))
             (let ((close (ignore-errors (scan-lists (1- (match-end 0)) 1 0))))
               (and close (cons at close)))))
         ;; Point in the body, or right after the closing `}'.
         (let ((pos (if (eq (char-before pt) ?}) (1- pt) pt))
               (result nil)
               (depth 0))
           (while (and (not result) pos (< depth 20))
             (setq pos (ignore-errors (scan-lists pos -1 1)))
             (setq depth (1+ depth))
             (when (and pos (eq (char-after pos) ?{))
               (goto-char (1+ pos))
               (when (looking-back scribble--hide-markup-open-rx
                                   (line-beginning-position))
                 (let ((close (ignore-errors (scan-lists pos 1 0))))
                   (when close
                     (setq result (cons (match-beginning 0) close)))))))
           result))))))

(defun scribble--update-reveal (&optional force-none)
  "Reveal the markup of the hidden-markup form at point, re-hiding the old one.
With FORCE-NONE, just re-hide."
  (let* ((new (and (not force-none)
                   scribble-hide-markup
                   scribble-reveal-markup-at-point
                   (scribble--hidden-form-at-point)))
         (old scribble--revealed))
    (unless (and old new
                 (= (car new) (car old))
                 (= (cdr new) (cdr old)))
      (when (or old new)
        (setq scribble--revealed
              (and new (cons (copy-marker (car new)) (copy-marker (cdr new)))))
        (when old
          (let ((beg (marker-position (car old)))
                (end (marker-position (cdr old))))
            (set-marker (car old) nil)
            (set-marker (cdr old) nil)
            (when (and beg end (< beg end))
              (font-lock-flush beg (min end (point-max))))))
        (when new
          (font-lock-flush (car new) (cdr new)))))))

(defun scribble--reveal-post-command ()
  (scribble--update-reveal))

(defun scribble--apply-markup-hiding ()
  (if scribble-hide-markup
      (add-to-invisibility-spec 'scribble-markup)
    (remove-from-invisibility-spec 'scribble-markup)))

(defun scribble-toggle-markup-hiding (&optional arg)
  "Toggle hiding of markup around bold/italic forms in this buffer.
With a prefix ARG, hide markup when ARG is positive, show it otherwise.
See `scribble-hide-markup-forms'."
  (interactive "P")
  (setq-local scribble-hide-markup
              (if (null arg)
                  (not scribble-hide-markup)
                (> (prefix-numeric-value arg) 0)))
  (scribble--apply-markup-hiding)
  (message "Scribble markup %s" (if scribble-hide-markup "hidden" "shown")))

;; Menu and Keymap:

(defvar scribble-minor-mode-menu
  (let ((km (make-sparse-keymap "Scribble")))
    (define-key km [scribble-about]
      '(menu-item "About Scribble Emacs Mode..." scribble-about
                  :help "See information about Scribble Emacs mode"))
    (define-key km [scribble-browse-mode-web]
      '(menu-item "Browse Scribble Emacs Mode Web..." scribble-browse-mode-web
                  :help "Browse Web pages for Scribble Emacs mode"))
    (define-key km [scribble-separator-1]
      '(menu-item "--"))
    (define-key km [scribble-customize]
      '(menu-item "Customize..." scribble-customize
                  :help "Set Emacs customization options for Scribble"))
    (define-key km [scribble-toggle-markup-hiding]
      '(menu-item "Hide Markup" scribble-toggle-markup-hiding
                  :button (:toggle . scribble-hide-markup)
                  :help "Hide @bold{...}-style markup, showing only styled text"))
    (define-key km [scribble-wrap-region]
      '(menu-item "Wrap Region in Form..." scribble-wrap-region
                  :help "Wrap the region in @form{...}"))
    km))

(defvar scribble-minor-mode-map
  (let ((km (make-sparse-keymap)))
    (define-key km (kbd "C-c C-w") #'scribble-wrap-region)
    (define-key km (kbd "C-c C-x C-m") #'scribble-toggle-markup-hiding)
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
        (unless (memq 'invisible font-lock-extra-managed-props)
          (setq-local font-lock-extra-managed-props
                      (cons 'invisible font-lock-extra-managed-props)))
        (scribble--apply-markup-hiding)
        (add-hook 'post-command-hook #'scribble--reveal-post-command nil t)
        (font-lock-add-keywords nil scribble--semantic-font-lock-keywords
                                'append))
    (font-lock-remove-keywords nil scribble--semantic-font-lock-keywords)
    (remove-hook 'post-command-hook #'scribble--reveal-post-command t)
    (scribble--update-reveal t)
    (remove-from-invisibility-spec 'scribble-markup)
    ;; Clear our `invisible' props while font-lock still manages them.
    (save-restriction
      (widen)
      (font-lock-unfontify-region (point-min) (point-max)))
    (setq-local font-lock-extra-managed-props
                (remq 'invisible font-lock-extra-managed-props))
    (kill-local-variable 'outline-regexp)
    (kill-local-variable 'outline-level))
  (font-lock-flush))

;;------------------------------------------------------------------- Auto-Mode

;;;###autoload
(unless (assoc "\\.scrbl\\'" auto-mode-alist)
  (push '("\\.scrbl\\'" . racket-hash-lang-mode) auto-mode-alist))

;;--------------------------------------------------------------------- Provide

(provide 'scribble)

;;; scribble.el ends here
