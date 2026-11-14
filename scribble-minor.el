;; -*- lexical-binding: t; -*-
;; $Id: scribble.el,v 1.49 2015/11/03 17:54:56 user Exp $
;; Package-Requires: ((emacs "28.1") (transient "0.3.7") (racket-mode "20250528"))

;; This minor mode is inspired by the original scribble-mode by Neil Van Dyke (see https://www.neilvandyke.org/scribble-emacs/).

(defconst scribble-minor-mode-title   "Racket Scribble Emacs Minor Mode")
(defconst scribble-minor-mode-version "0.1")

;;-------------------------------------------------------------------- Requires

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

(defun scribble--source-file ()
  (or buffer-file-name (user-error "Buffer is not visiting a file")))

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
  "Run raco scribble on the current file with ARGS from `scribble-compile'."
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
  "View the output of compiling the current file with ARGS.
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

;;;###autoload (autoload 'scribble-compile "scribble-minor" nil t)
(transient-define-prefix scribble-compile ()
  "Compile the current Scribble file with raco scribble."
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
   ("c" "Compile"     scribble-compile-run)
   ("v" "View output" scribble-view)])

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
    (define-key km [scribble-toggle-markup-hiding]
      '(menu-item "Hide Markup" scribble-toggle-markup-hiding
                  :button (:toggle . scribble-hide-markup)
                  :help "Hide @bold{...}-style markup, showing only styled text"))
    (define-key km [scribble-compile]
      '(menu-item "Compile..." scribble-compile
                  :help "Compile to HTML, PDF, ... with raco scribble"))
    (define-key km [scribble-view]
      '(menu-item "View Output" scribble-view
                  :help "View the output of the last compile"))
    (define-key km [scribble-wrap-region]
      '(menu-item "Wrap Region in Form..." scribble-wrap-region
                  :help "Wrap the region in @form{...}"))
    km))

(defvar scribble-minor-mode-map
  (let ((km (make-sparse-keymap)))
    (define-key km (kbd "C-c C-b") #'scribble-compile)
    (define-key km (kbd "C-c C-v") #'scribble-view)
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


;;;###autoload
(add-to-list 'auto-mode-alist '("\\.scrbl\\'" . racket-hash-lang-mode))

(provide 'scribble-minor)

;;; scribble-minor.el ends here
