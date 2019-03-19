;;; phpenv.el --- Emacs integration for phpenv

;;; License:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;; M-x global-phpenv-mode toggle the configuration done by phenv.el

;; M-x phpenv-use-global prepares the current Emacs session to use
;; the global php configured with phpenv.

;; M-x phpenv-use allows you to switch the current session to the php
;; implementation of your choice.

;; helper function used in variable definitions
(defcustom phpenv-installation-dir (or (getenv "PHPENV_ROOT")
                                       (concat (getenv "HOME") "/.phpenv/"))
  "The path to the directory where phpenv was installed."
  :group 'phpenv
  :type 'directory)

(defun phpenv--expand-path (&rest segments)
  (let ((path (mapconcat 'identity segments "/"))
        (installation-dir (replace-regexp-in-string "/$" "" phpenv-installation-dir)))
    (expand-file-name (concat installation-dir "/" path))))

(defcustom phpenv-interactive-completion-function
  (if ido-mode 'ido-completing-read 'completing-read)
  "The function which is used by phpenv.el to interactivly complete user input"
  :group 'phpenv
  :type 'function)

(defcustom phpenv-show-active-php-in-modeline t
  "Toggles wether phpenv-mode shows the active php in the modeline."
  :group 'phpenv
  :type 'boolean)

(defcustom phpenv-modeline-function 'phpenv--modeline-with-face
  "Function to specify the phpenv representation in the modeline."
  :group 'phpenv
  :type 'function)

(defvar phpenv-executable (phpenv--expand-path "bin" "phpenv")
  "path to the phpenv executable")

(defvar phpenv-php-shim (phpenv--expand-path "shims" "php")
  "path to the php shim executable")

(defvar phpenv-global-version-file (phpenv--expand-path "version")
  "path to the global version configuration file of phpenv")

(defvar phpenv-version-environment-variable "PHPENV_VERSION"
  "name of the environment variable to configure the phpenv version")

(defvar phpenv-binary-paths (list (cons 'shims-path (phpenv--expand-path "shims"))
                                  (cons 'bin-path (phpenv--expand-path "bin")))
  "these are added to PATH and exec-path when phpenv is setup")

(defface php-active-php-face
    '((t (:weight bold :foreground "Red")))
  "The face used to highlight the current php on the modeline.")

(defvar phpenv--initialized nil
  "indicates if the current Emacs session has been configured to use phpenv")

(defvar phpenv--modestring nil
  "text phpenv-mode will display in the modeline.")
(put 'phpenv--modestring 'risky-local-variable t)

;;;###autoload
(defun phpenv-use-global ()
  "activate phpenv global php"
  (interactive)
  (phpenv-use (phpenv--global-php-version)))

;;;###autoload
(defun phpenv-use-corresponding ()
  "search for .php-version and activate the corresponding php"
  (interactive)
  (let ((version-file-path (or (phpenv--locate-file ".php-version")
                               (phpenv--locate-file ".phpenv-version"))))
    (if version-file-path (phpenv-use (phpenv--read-version-from-file version-file-path))
      (message "[phpenv] could not locate .php-version or .phpenv-version"))))

;;;###autoload
(defun phpenv-use (php-version)
  "choose what php you want to activate"
  (interactive
   (let ((picked-php (phpenv--completing-read "PHP version: " (phpenv/list))))
     (list picked-php)))
  (phpenv--activate php-version)
  (message (concat "[phpenv] using " php-version)))

(defun phpenv/list ()
  (append '("system")
          (split-string (phpenv--call-process "versions" "--bare") "\n")))

(defun phpenv--setup ()
  (when (not phpenv--initialized)
    (dolist (path-config phpenv-binary-paths)
      (let ((bin-path (cdr path-config)))
        (setenv "PATH" (concat bin-path ":" (getenv "PATH")))
        (add-to-list 'exec-path bin-path)))
    (setq eshell-path-env (getenv "PATH"))
    (setq phpenv--initialized t)
    (phpenv--update-mode-line)))

(defun phpenv--teardown ()
  (when phpenv--initialized
    (dolist (path-config phpenv-binary-paths)
      (let ((bin-path (cdr path-config)))
        (setenv "PATH" (replace-regexp-in-string (regexp-quote (concat bin-path ":")) "" (getenv "PATH")))
        (setq exec-path (remove bin-path exec-path))))
    (setq eshell-path-env (getenv "PATH"))
    (setq phpenv--initialized nil)))

(defun phpenv--activate (php-version)
  (setenv phpenv-version-environment-variable php-version)
  (phpenv--update-mode-line))

(defun phpenv--completing-read (prompt options)
  (funcall phpenv-interactive-completion-function prompt options))

(defun phpenv--global-php-version ()
  (if (file-exists-p phpenv-global-version-file)
      (phpenv--read-version-from-file phpenv-global-version-file)
    "system"))

(defun phpenv--read-version-from-file (path)
  (with-temp-buffer
    (insert-file-contents path)
    (phpenv--replace-trailing-whitespace (buffer-substring-no-properties (point-min) (point-max)))))

(defun phpenv--locate-file (file-name)
  "searches the directory tree for an given file. Returns nil if the file was not found."
  (let ((directory (locate-dominating-file default-directory file-name)))
    (when directory (concat directory file-name))))

(defun phpenv--call-process (&rest args)
  (with-temp-buffer
    (let* ((success (apply 'call-process phpenv-executable nil t nil
                           (delete nil args)))
           (raw-output (buffer-substring-no-properties
                        (point-min) (point-max)))
           (output (phpenv--replace-trailing-whitespace raw-output)))
      (if (= 0 success)
          output
        (message output)))))

(defun phpenv--replace-trailing-whitespace (text)
  (replace-regexp-in-string "[[:space:]\n]+\\'" "" text))

(defun phpenv--update-mode-line ()
  (setq phpenv--modestring (funcall phpenv-modeline-function
                                    (phpenv--active-php-version))))

(defun phpenv--modeline-with-face (current-php)
  (append '(" [")
          (list (propertize current-php 'face 'phpenv-active-php-face))
          '("]")))

(defun phpenv--modeline-plain (current-php)
  (list " [" current-php "]"))

(defun phpenv--active-php-version ()
  (or (getenv phpenv-version-environment-variable) (phpenv--global-php-version)))

;;;###autoload
(define-minor-mode global-phpenv-mode
    "use phpenv to configure the php version used by your Emacs."
  :global t
  (if global-phpenv-mode
      (progn
        (when phpenv-show-active-php-in-modeline
          (unless (memq 'phpenv--modestring global-mode-string)
            (setq global-mode-string (append (or global-mode-string '(""))
                                             '(phpenv--modestring)))))
        (phpenv--setup))
    (setq global-mode-string (delq 'phpenv--modestring global-mode-string))
    (phpenv--teardown)))

(provide 'phpenv)

;;; phpenv.el ends here
