;;; flymake-actionlint.el --- Flymake backend for actionlint  -*- lexical-binding: t; -*-

;; Copyright (C) 2022  Taiki Sugawara

;; Author: Taiki Sugawara <buzz.taiki@gmail.com>
;; Keywords: convenience, processes, github-actions, flymake
;; URL: https://github.com/buzztaiki/flymake-actionlint
;; Version: 0.0.1
;; Package-Requires: ((emacs "26.1"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;; TODO: Should I add it to flymake-collection?


;;; Code:

(require 'flymake)

(defvar-local flymake-actionlint--proc nil)

(defgroup flymake-actionlint nil
  "Flymake backend for actionlint."
  :group 'flymake)


(defcustom flymake-actionlint-program "actionlint"
  "A actionlint program name."
  :group 'flymake-actionlint
  :type 'string)

(defun flymake-actionlint (report-fn &rest _args)
  "Flymake backend for actionlint.

REPORT-FN is Flymake's callback function."
  (unless (executable-find flymake-actionlint-program)
    (error "Cannot find a suitable actionlint"))
  (when (process-live-p flymake-actionlint--proc)
    (kill-process flymake-actionlint--proc))
  (let ((source (current-buffer)))
    (save-restriction
      (widen)
      (setq flymake-actionlint--proc
            (make-process
             :name "flymake-actionlint" :noquery t :connection-type 'pipe
             :buffer (generate-new-buffer " *flymake-actionlint*")
             :command (list flymake-actionlint-program "-")
             :sentinel
             (lambda (proc event) (flymake-actionlint--process-sentinel proc event source report-fn))))
      (save-restriction
        (widen)
        (process-send-region flymake-actionlint--proc (point-min) (point-max)))
      (process-send-eof flymake-actionlint--proc))))

(defun flymake-actionlint--process-sentinel (proc _event source report-fn)
  "Sentinel of the `flymake-actionlint' process PROC for buffer SOURCE.

REPORT-FN is Flymake's callback function."
  (when (eq 'exit (process-status proc))
    (unwind-protect
        (if (with-current-buffer source (eq proc flymake-actionlint--proc))
            (with-current-buffer (process-buffer proc)
              (goto-char (point-min))
              (funcall report-fn (flymake-actionlint--collect-diagnostics source)))
          (flymake-log :warning "Canceling obsolete check %s" proc))
      (kill-buffer (process-buffer proc)))))

(defun flymake-actionlint--collect-diagnostics (source)
  "Collect diagnostics for buffer SOURCE from actionlint output in current buffer."
  (let (diags)
    (while (not (eobp))
      (cond
       ;; <stdin>:25:13: got unexpected character '$' while lexing expression, expecting 'a'..'z', 'A'..'Z', '_', '0'..'9', ''', '}', '(', ')', '[', ']', '.', '!', '<', '>', '=', '&', '|', '*', ',', ' ' [expression]
       ((looking-at "^.+?:\\([0-9]+\\):\\([0-9]+\\): \\(.+\\)$")
        (pcase-let ((`(,beg . ,end) (flymake-diag-region source
                                                         (string-to-number (match-string 1))
                                                         (string-to-number (match-string 2)))))
          (push (flymake-make-diagnostic source beg end :error (match-string 3)) diags))))
      (forward-line 1))
    diags))

;;;###autoload
(defun flymake-actionlint-setup ()
  "Setup Flymake to use `flymake-actionlint' buffer locally."
  (add-hook 'flymake-diagnostic-functions #'flymake-actionlint nil t))


(provide 'flymake-actionlint)
;;; flymake-actionlint.el ends here
