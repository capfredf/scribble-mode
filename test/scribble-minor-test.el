;;; scribble-minor-test.el --- Tests for scribble-minor  -*- lexical-binding: t; -*-

;; Run with:  make test
;; or:        emacs -Q --batch -L . -l test/scribble-minor-test.el \
;;                  -f ert-run-tests-batch-and-exit

;;; Commentary:

;; Font-lock tests run in `scribble-test-mode', a stand-in for
;; `racket-hash-lang-mode' (which needs a live Racket back end): like
;; hash-lang it uses `font-lock-defaults' (nil t), and its syntax table
;; pairs {} [] () and treats "..." as strings.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'scribble-minor)

;;; Helpers

(defvar scribble-test-mode-syntax-table
  (let ((st (make-syntax-table)))
    (modify-syntax-entry ?{ "(}" st)
    (modify-syntax-entry ?} "){" st)
    (modify-syntax-entry ?\[ "(]" st)
    (modify-syntax-entry ?\] ")[" st)
    (modify-syntax-entry ?\( "()" st)
    (modify-syntax-entry ?\) ")(" st)
    (modify-syntax-entry ?\" "\"" st)
    (modify-syntax-entry ?@ "'" st)
    st))

(define-derived-mode scribble-test-mode prog-mode "Scribble-Test"
  "Stand-in for `racket-hash-lang-mode' in tests."
  (setq-local font-lock-defaults '(nil t)))

(defmacro scribble-test-with-buffer (text &rest body)
  "Run BODY in a fontified `scribble-test-mode' buffer holding TEXT."
  (declare (indent 1) (debug t))
  `(with-temp-buffer
     (scribble-test-mode)
     (insert ,text)
     (font-lock-mode 1)
     (scribble-minor-mode 1)
     (font-lock-ensure)
     (goto-char (point-min))
     ,@body))

(defun scribble-test-pos (needle &optional nth)
  "Position of the start of the NTH (default 1st) occurrence of NEEDLE."
  (save-excursion
    (goto-char (point-min))
    (search-forward needle nil nil (or nth 1))
    (match-beginning 0)))

(defun scribble-test-faces-at (pos)
  (ensure-list (get-text-property pos 'face)))

(defun scribble-test-has-face (needle face &optional nth)
  "Non-nil when every char of NEEDLE (its NTH occurrence) has FACE."
  (let ((beg (scribble-test-pos needle nth)))
    (cl-loop for p from beg below (+ beg (length needle))
             always (memq face (scribble-test-faces-at p)))))

(defun scribble-test-lacks-face (needle face &optional nth)
  "Non-nil when no char of NEEDLE (its NTH occurrence) has FACE."
  (let ((beg (scribble-test-pos needle nth)))
    (cl-loop for p from beg below (+ beg (length needle))
             never (memq face (scribble-test-faces-at p)))))

;;; Activation

(ert-deftest scribble-test-module-language-regexp ()
  (dolist (lang '("rhombus/scribble" "rhombus/scribble/manual"
                  "scribble/manual/lang" "scribble/base/reader"))
    (should (string-match-p scribble-minor-mode-module-language-regexp lang)))
  (dolist (lang '("racket/base" "scribblex" "rhombus" "at-exp/racket"
                  "my/scribble"))
    (should-not (string-match-p scribble-minor-mode-module-language-regexp
                                lang))))

(ert-deftest scribble-test-maybe-enable ()
  (with-temp-buffer
    (scribble-test-mode)
    (scribble-minor-mode-maybe-enable nil)
    (should-not scribble-minor-mode)
    (scribble-minor-mode-maybe-enable "racket/base")
    (should-not scribble-minor-mode)
    (scribble-minor-mode-maybe-enable "rhombus/scribble")
    (should scribble-minor-mode)
    ;; Never disables on a later non-Scribble lang.
    (scribble-minor-mode-maybe-enable "racket/base")
    (should scribble-minor-mode)))

(ert-deftest scribble-test-auto-mode ()
  (should (eq (assoc-default "doc.scrbl" auto-mode-alist #'string-match-p)
              'racket-hash-lang-mode)))

;;; Font-lock

(ert-deftest scribble-test-bold-body ()
  (scribble-test-with-buffer "x @bold{word} y"
    (should (scribble-test-has-face "word" 'scribble-bold-face))
    (should (scribble-test-lacks-face "@bold{" 'scribble-bold-face))
    (should (scribble-test-lacks-face "}" 'scribble-bold-face))
    (should (scribble-test-lacks-face " y" 'scribble-bold-face))))

(ert-deftest scribble-test-italic-and-emph ()
  (scribble-test-with-buffer "@italic{slanted} @emph{stressed}"
    (should (scribble-test-has-face "slanted" 'scribble-italic-face))
    (should (scribble-test-has-face "stressed" 'scribble-emph-face))))

(ert-deftest scribble-test-racket-bracket-args ()
  (scribble-test-with-buffer "@section[#:tag \"intro\"]{Introduction}"
    (should (scribble-test-has-face "Introduction"
                                    'scribble-section-heading-face))
    (should (scribble-test-lacks-face "#:tag" 'scribble-section-heading-face))))

(ert-deftest scribble-test-rhombus-paren-args ()
  (scribble-test-with-buffer "@section(~tag: \"intro\"){Introduction}"
    (should (scribble-test-has-face "Introduction"
                                    'scribble-section-heading-face))
    (should (scribble-test-lacks-face "~tag" 'scribble-section-heading-face))))

(ert-deftest scribble-test-rhombus-paren-args-nested ()
  ;; Nested parens and a ")" inside a string don't end the args early.
  (scribble-test-with-buffer "@subsection(~tag: f(\"a)b\"), ~x: [1]){Nested}"
    (should (scribble-test-has-face "Nested"
                                    'scribble-subsection-heading-face))))

(ert-deftest scribble-test-multiple-arg-groups ()
  (scribble-test-with-buffer "@title[#:style 'toc](~x: 1){My Doc}"
    (should (scribble-test-has-face "My Doc" 'scribble-title-face))))

(ert-deftest scribble-test-args-without-body ()
  ;; "@section(x)" with no {body} gets no face, and doesn't swallow the
  ;; following form.
  (scribble-test-with-buffer "@section(x) and @bold{strong}"
    (should (scribble-test-lacks-face "and" 'scribble-section-heading-face))
    (should (scribble-test-lacks-face "strong" 'scribble-section-heading-face))
    (should (scribble-test-has-face "strong" 'scribble-bold-face))))

(ert-deftest scribble-test-nested-braces ()
  (scribble-test-with-buffer "@bold{a{b}c} d"
    (should (scribble-test-has-face "a{b}c" 'scribble-bold-face))
    (should (scribble-test-lacks-face " d" 'scribble-bold-face))))

(ert-deftest scribble-test-nested-forms ()
  (scribble-test-with-buffer "@bold{x @italic{y} z}"
    (should (scribble-test-has-face "x" 'scribble-bold-face))
    (should (scribble-test-has-face "y" 'scribble-bold-face))
    (should (scribble-test-has-face "y" 'scribble-italic-face))
    (should (scribble-test-lacks-face "x" 'scribble-italic-face))
    (should (scribble-test-has-face "z" 'scribble-bold-face))))

(ert-deftest scribble-test-name-boundary ()
  (scribble-test-with-buffer "@bolder{x} @bold-ish{y}"
    (should (scribble-test-lacks-face "x" 'scribble-bold-face))
    (should (scribble-test-lacks-face "y" 'scribble-bold-face))))

(ert-deftest scribble-test-unbalanced ()
  (scribble-test-with-buffer "@bold{never closed\nmore text"
    (should (scribble-test-lacks-face "never" 'scribble-bold-face))))

(ert-deftest scribble-test-face-prepended ()
  ;; Our face is layered over an existing token face, not replacing it.
  (with-temp-buffer
    (scribble-test-mode)
    (insert "@bold{word}")
    (font-lock-mode 1)
    (scribble-minor-mode 1)
    (font-lock-add-keywords nil '(("word" 0 'font-lock-string-face)))
    (font-lock-flush)
    (font-lock-ensure)
    (let ((faces (scribble-test-faces-at (scribble-test-pos "word"))))
      (should (memq 'scribble-bold-face faces))
      (should (memq 'font-lock-string-face faces)))))

(ert-deftest scribble-test-disable-removes-faces ()
  (scribble-test-with-buffer "@bold{word}"
    (should (scribble-test-has-face "word" 'scribble-bold-face))
    (scribble-minor-mode -1)
    (font-lock-ensure)
    (should (scribble-test-lacks-face "word" 'scribble-bold-face))))

;;; Partial refontification
;;
;; `racket-hash-lang-mode' refontifies just the changed text (jit-lock
;; marks only the changed chars, and its fontify-region function skips
;; `font-lock-extend-region-functions'), so a region often starts in the
;; middle of a form.  `scribble-test-refontify' does what its
;; `racket--hash-lang-tokens+fontify' does on such a region.

(defun scribble-test-refontify (beg end)
  "Refontify just BEG..END, as `racket-hash-lang-mode' does."
  (with-silent-modifications
    (save-excursion
      (font-lock-unfontify-region beg end)
      (font-lock-fontify-keywords-region beg end))))

(defun scribble-test-refontify-needle (needle &optional from to)
  "Refontify NEEDLE's chars FROM (default 0) to TO (default its length)."
  (let ((beg (scribble-test-pos needle)))
    (scribble-test-refontify (+ beg (or from 0))
                             (+ beg (or to (length needle))))))

(defun scribble-test-face-once (needle face)
  "Non-nil when every char of NEEDLE has FACE exactly once."
  (let ((beg (scribble-test-pos needle)))
    (cl-loop for p from beg below (+ beg (length needle))
             always (= 1 (cl-count face (scribble-test-faces-at p))))))

(ert-deftest scribble-test-refontify-mid-body ()
  ;; The original flicker: typing inside @section{...} lost the face.
  (scribble-test-with-buffer "@section{Hello world}"
    (scribble-test-refontify-needle "world" 1 3)
    (should (scribble-test-face-once "Hello world"
                                     'scribble-section-heading-face))))

(ert-deftest scribble-test-refontify-typing ()
  (scribble-test-with-buffer "intro @section{Hello} outro"
    (goto-char (+ (scribble-test-pos "Hello") 3))
    (insert "X")                        ; no props inherited
    (scribble-test-refontify (1- (point)) (point))
    (should (scribble-test-face-once "HelXlo" 'scribble-section-heading-face))
    (should (scribble-test-lacks-face "outro" 'scribble-section-heading-face))))

(ert-deftest scribble-test-refontify-from-name ()
  (scribble-test-with-buffer "@section{Hello}"
    (scribble-test-refontify (scribble-test-pos "tion")
                             (+ (scribble-test-pos "Hello") 3))
    (should (scribble-test-face-once "Hello" 'scribble-section-heading-face))
    (should (scribble-test-lacks-face "@section{" 'scribble-section-heading-face))))

(ert-deftest scribble-test-refontify-from-args ()
  (scribble-test-with-buffer "@section[#:tag \"intro\"]{Hello}"
    (scribble-test-refontify (scribble-test-pos "tag")
                             (+ (scribble-test-pos "Hello") 2))
    (should (scribble-test-face-once "Hello" 'scribble-section-heading-face))
    (should (scribble-test-lacks-face "intro" 'scribble-section-heading-face))))

(ert-deftest scribble-test-refontify-multiline-body ()
  (scribble-test-with-buffer "@bold{first\nsecond}"
    (scribble-test-refontify-needle "second" 2 4)
    (should (scribble-test-face-once "first\nsecond" 'scribble-bold-face))))

(ert-deftest scribble-test-refontify-multiline-args ()
  (scribble-test-with-buffer "@section(~tag:\n  \"t\"){Hello}"
    (scribble-test-refontify-needle "Hello" 1 3)
    (should (scribble-test-face-once "Hello" 'scribble-section-heading-face))))

(ert-deftest scribble-test-refontify-nested ()
  (scribble-test-with-buffer "@section{outer @bold{inner} tail}"
    (scribble-test-refontify-needle "inner" 1 3)
    (should (scribble-test-face-once "inner" 'scribble-section-heading-face))
    (should (scribble-test-face-once "inner" 'scribble-bold-face))
    (should (scribble-test-face-once "outer @bold{inner} tail"
                                     'scribble-section-heading-face))
    (should (scribble-test-lacks-face "outer" 'scribble-bold-face))
    (should (scribble-test-lacks-face "tail" 'scribble-bold-face))))

(ert-deftest scribble-test-refontify-no-duplicates ()
  ;; Overlapping refontifications never stack the face.
  (scribble-test-with-buffer "@section{Hello world} after"
    (scribble-test-refontify-needle "Hello" 1 2)
    (scribble-test-refontify-needle "Hello world" 3 8)
    (scribble-test-refontify (scribble-test-pos "world") (point-max))
    (should (scribble-test-face-once "Hello world"
                                     'scribble-section-heading-face))
    (should (scribble-test-lacks-face "after" 'scribble-section-heading-face))))

(ert-deftest scribble-test-refontify-after-form ()
  (scribble-test-with-buffer "@bold{a} b @bold{c}"
    (scribble-test-refontify-needle " b ")
    (should (scribble-test-lacks-face " b " 'scribble-bold-face))
    (should (scribble-test-face-once "a" 'scribble-bold-face))
    (should (scribble-test-face-once "c" 'scribble-bold-face))))

(ert-deftest scribble-test-refontify-unbalanced ()
  (scribble-test-with-buffer "@section{never closed\nmore"
    (scribble-test-refontify-needle "closed" 1 3)
    (should (scribble-test-lacks-face "never closed"
                                      'scribble-section-heading-face))))

;;; Imenu and outline

(ert-deftest scribble-test-imenu ()
  (scribble-test-with-buffer
      (concat "@section{One}\n"
              "@subsection[#:tag \"t\"]{Two}\n"
              "@section(~tag: \"x\"){Three}\n")
    (let ((names (mapcar #'car (funcall imenu-create-index-function))))
      (should (equal (sort names #'string<) '("One" "Three" "Two"))))))

(ert-deftest scribble-test-outline-level ()
  (scribble-test-with-buffer
      "@title{T}\n@section{S}\n@subsection{SS}\n@subsubsection{SSS}\n"
    (should (equal outline-regexp scribble-outline-regexp))
    (let (levels)
      (while (re-search-forward outline-regexp nil t)
        (save-excursion
          (goto-char (match-beginning 0))
          (push (funcall outline-level) levels)))
      (should (equal (nreverse levels) '(1 2 3 4))))))

;;; Editing

(ert-deftest scribble-test-wrap-region ()
  (with-temp-buffer
    (insert "hello world")
    (transient-mark-mode 1)
    (set-mark 7)
    (goto-char 12)
    (activate-mark)
    (scribble-wrap-region "bold")
    (should (equal (buffer-string) "hello @bold{world}"))))

(ert-deftest scribble-test-wrap-no-region ()
  (with-temp-buffer
    (insert "x ")
    (scribble-wrap-region "emph")
    (should (equal (buffer-string) "x @emph{}"))
    (should (eq (char-after) ?}))))

;;; Compile arguments

(ert-deftest scribble-test-expand-args ()
  (should (equal (scribble--expand-args
                  '("--html" "--dest=/tmp/out" "++style=a=b.css" "--quiet"))
                 '("--html" "--dest" "/tmp/out" "++style" "a=b.css" "--quiet"))))

(ert-deftest scribble-test-output-file ()
  (with-temp-buffer
    (setq buffer-file-name "/docs/guide.scrbl")
    (should (equal (scribble--output-file '("--typst-pdf")) "/docs/guide.pdf"))
    (should (equal (scribble--output-file '("--htmls")) "/docs/guide/index.html"))
    (should (equal (scribble--output-file '("--markdown")) "/docs/guide.md"))
    (should (equal (scribble--output-file '()) "/docs/guide.html"))
    (should (equal (scribble--output-file '("--pdf" "--dest=/out"))
                   "/out/guide.pdf"))
    (should (equal (scribble--output-file '("--latex" "--dest-name=book"))
                   "/docs/book.tex"))
    (setq buffer-file-name nil)))

(ert-deftest scribble-test-compile-args-defaults ()
  (with-temp-buffer
    (let ((transient-values nil)
          (transient-current-command nil))
      (should (equal (scribble--compile-args) '("--typst-pdf")))
      (let ((transient-values '((scribble-compile "--html"))))
        (should (equal (scribble--compile-args) '("--html"))))
      (setq scribble--last-compile-args '("--markdown"))
      (should (equal (scribble--compile-args) '("--markdown"))))))

;;; Watch (needs raco)

(defun scribble-test-wait-for (pred proc &optional secs)
  (let ((deadline (+ (float-time) (or secs 60))))
    (while (and (not (funcall pred)) (< (float-time) deadline))
      (accept-process-output proc 0.2))
    (funcall pred)))

(ert-deftest scribble-test-watch ()
  :tags '(:expensive)
  (skip-unless (executable-find scribble-raco-program))
  (let* ((dir (make-temp-file "scribble-test" t))
         (src (expand-file-name "doc.scrbl" dir))
         (out (expand-file-name "doc.html" dir))
         (log-name (scribble--watch-buffer-name src)))
    (unwind-protect
        (progn
          (with-temp-file src
            (insert "#lang scribble/manual\n@title{Hi}\nHello.\n"))
          (with-current-buffer (find-file-noselect src)
            (cl-letf (((symbol-function 'display-buffer) #'ignore))
              (scribble-watch '("--html")))
            (let ((proc scribble--watch-process))
              (should (process-live-p proc))
              (should (eq (process-buffer proc) (get-buffer log-name)))
              (should (scribble-test-wait-for
                       (lambda () (file-exists-p out)) proc))
              ;; Edits trigger a re-render.
              (delete-file out)
              (with-temp-file src
                (insert "#lang scribble/manual\n@title{Hi}\nChanged.\n"))
              (should (scribble-test-wait-for
                       (lambda () (file-exists-p out)) proc))
              (scribble-watch-stop)
              (should (scribble-test-wait-for
                       (lambda () (not (process-live-p proc))) nil 5))
              (should-not scribble--watch-process))
            (with-current-buffer log-name
              (should (derived-mode-p 'scribble-watch-log-mode))
              (should (string-match-p "raco scribble --watch --html doc.scrbl"
                                      (buffer-string)))
              (should (string-match-p "\\[scribble-watch killed"
                                      (buffer-string))))
            ;; Killing the source buffer stops a running watcher.
            (cl-letf (((symbol-function 'display-buffer) #'ignore))
              (scribble-watch '("--html")))
            (let ((proc scribble--watch-process))
              (kill-buffer)
              (should (scribble-test-wait-for
                       (lambda () (not (process-live-p proc))) nil 5)))))
      (when (get-buffer log-name) (kill-buffer log-name))
      (delete-directory dir t))))

(provide 'scribble-minor-test)
;;; scribble-minor-test.el ends here
