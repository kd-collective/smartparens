(require 'smartparens)
(require 'evil)

(defmacro sp-test--show-pairs (initial init-form &rest forms)
  (declare (indent 2))
  `(let ((sp-pairs
          '((t .
               ((:open "\"" :close "\"" :actions (insert wrap autoskip navigate))
                (:open "'" :close "'" :actions (insert wrap autoskip navigate))
                (:open "$" :close "$" :actions (insert wrap autoskip navigate))
                (:open "(" :close ")" :actions (insert wrap autoskip navigate))
                (:open "[" :close "]" :actions (insert wrap autoskip navigate))
                (:open "{" :close "}" :actions (insert wrap autoskip navigate))))))
         (sp-show-pair-overlays nil))
     (unwind-protect
         (sp-test-with-temp-buffer ,initial
             ,init-form
           (show-smartparens-mode 1)
           (smartparens-mode 1)
           (shut-up (sp-show--pair-function))
           ,@forms)
       (sp-show--pair-delete-overlays))))

(defun sp-test--show-pairs-assert (result)
  (let ((op-beg (plist-get result :op-beg))
        (op-len (or (plist-get result :op-len) 1))
        (cl-beg (plist-get result :cl-beg))
        (cl-len (or (plist-get result :cl-len) 1))
        (op (nth 0 sp-show-pair-overlays))
        (cl (nth 2 sp-show-pair-overlays)))
    (if (and (not op-beg) (not cl-beg))
        (should (eq sp-show-pair-overlays nil))
      (if (not op-beg)
          (should (null op))
        (should (not (null op)))
        (should (= (overlay-start op) op-beg))
        (should (= (overlay-end op) (+ op-beg op-len))))
      (if (not cl-beg)
          (should (null cl))
        (should (not (null cl)))
        (should (= (overlay-start cl) cl-beg))
        (should (= (overlay-end cl) (+ cl-beg cl-len)))))))

(ert-deftest sp-test-show-mode-point-at-nonpairable-stringlike-delimiter-textmode ()
  (sp-test--show-pairs "\"asdasd'| asdasd asd\"" (text-mode)
    (sp-test--show-pairs-assert nil)))

(sp-ert-deftest sp-test-show-mode-point-elisp
  :let ((sp-show-pair-from-inside nil))
  (sp-test--show-pairs "|(foo bar)" (emacs-lisp-mode)
    (sp-test--show-pairs-assert (list :op-beg 1 :cl-beg 9)))
  (sp-test--show-pairs "(foo bar)|" (emacs-lisp-mode)
    (sp-test--show-pairs-assert (list :op-beg 1 :cl-beg 9)))

  (sp-test--show-pairs "(|foo bar)" (emacs-lisp-mode)
    (sp-test--show-pairs-assert nil))
  (sp-test--show-pairs "(foo bar|)" (emacs-lisp-mode)
    (sp-test--show-pairs-assert nil))

  (sp-test--show-pairs "\"()|\"" (emacs-lisp-mode)
    (sp-test--show-pairs-assert (list :op-beg 2 :cl-beg 3)))
  (sp-test--show-pairs "\"()\"|" (emacs-lisp-mode)
    (sp-test--show-pairs-assert (list :op-beg 1 :cl-beg 4))))

(sp-ert-deftest sp-test-show-mode-point-elisp-from-inside-t
  :let ((sp-show-pair-from-inside t))
  (sp-test--show-pairs "(|foo bar)" (emacs-lisp-mode)
    (sp-test--show-pairs-assert (list :op-beg 1 :cl-beg 9)))
  (sp-test--show-pairs "(foo bar|)" (emacs-lisp-mode)
    (sp-test--show-pairs-assert (list :op-beg 1 :cl-beg 9))))

(sp-ert-deftest sp-test-show-mode-latex-multiple-nested-sexps
  (sp-test--show-pairs "|$({})$" (latex-mode)
    (sp-test--show-pairs-assert (list :op-beg 1 :cl-beg 6)))
  (sp-test--show-pairs "$|({})$" (latex-mode)
    (sp-test--show-pairs-assert (list :op-beg 2 :cl-beg 5)))
  (sp-test--show-pairs "$(|{})$" (latex-mode)
    (sp-test--show-pairs-assert (list :op-beg 3 :cl-beg 4)))
  (sp-test--show-pairs "$({|})$" (latex-mode)
    (sp-test--show-pairs-assert nil))
  (sp-test--show-pairs "$({}|)$" (latex-mode)
    (sp-test--show-pairs-assert (list :op-beg 3 :cl-beg 4)))
  (sp-test--show-pairs "$({})|$" (latex-mode)
    (sp-test--show-pairs-assert (list :op-beg 2 :cl-beg 5)))
  (sp-test--show-pairs "$({})$|" (latex-mode)
    (sp-test--show-pairs-assert (list :op-beg 1 :cl-beg 6))))

(sp-ert-deftest sp-test-show-mode-latex-multiple-nested-sexps-from-inside-t
  :let ((sp-show-pair-from-inside t))
  (sp-test--show-pairs "|$({})$" (latex-mode)
    (sp-test--show-pairs-assert (list :op-beg 1 :cl-beg 6)))
  (sp-test--show-pairs "$|({})$" (latex-mode)
    (sp-test--show-pairs-assert (list :op-beg 2 :cl-beg 5)))
  (sp-test--show-pairs "$(|{})$" (latex-mode)
    (sp-test--show-pairs-assert (list :op-beg 3 :cl-beg 4)))
  (sp-test--show-pairs "$({|})$" (latex-mode)
    (sp-test--show-pairs-assert (list :op-beg 3 :cl-beg 4)))
  (sp-test--show-pairs "$({}|)$" (latex-mode)
    (sp-test--show-pairs-assert (list :op-beg 3 :cl-beg 4)))
  (sp-test--show-pairs "$({})|$" (latex-mode)
    (sp-test--show-pairs-assert (list :op-beg 2 :cl-beg 5)))
  (sp-test--show-pairs "$({})$|" (latex-mode)
    (sp-test--show-pairs-assert (list :op-beg 1 :cl-beg 6))))

(ert-deftest sp-test-show-mode-point-at-end-in-sexp-evil ()
  (let ((sp-pairs '((t . ((:open "(" :close ")" :actions (insert wrap autoskip navigate))))))
        (sp-show-pair-overlays nil))
    (unwind-protect
        (sp-test-with-temp-elisp-buffer "(foo bar|)"
          (evil-local-mode)
          (show-smartparens-mode 1)
          (sp-show--pair-function)
          (should (not (eq sp-show-pair-overlays nil))))
      (sp-show--pair-delete-overlays))))
