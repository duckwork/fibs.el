;;; fibs.el --- Play backgammon with FIBS in Emacs -*- lexical-binding: t; -*-

;;; Commentary:

;; FIBS (The First Internet Backgammon Server) is a popular server for playing
;; backgammon online.  Its interface is driven through telnet, which Emacs has
;; included in its distribution.  This package includes a number of niceties for
;; making playing backgammon on FIBS easier.

;;; Code:

(require 'telnet)
(require 'comint)

;;; Customization options

(defgroup fibs nil
  "Customizations for FIBS, the First Internet Backgammon Server."
  :group 'games)

(defcustom fibs-server "fibs.com"
  "The server to connect to FIBS with."
  :type 'string)

(defcustom fibs-port 4321
  "The port to connect to FIBS with."
  :type 'number)

(defcustom fibs-autologin nil
  "Whether to autologin to FIBS."
  :type 'boolean)

(defcustom fibs-user nil
  "The user for FIBS."
  :type 'string)

(defcustom fibs-password nil
  "The password for `fibs-user'."
  :type 'string)

;;; Variables

(defvar fibs--process nil
  "The process connected to FIBS.")

(defvar fibs--buffer nil
  "The buffer connected to the FIBS process.")

;;; Functions

(defalias 'fibs-send 'telnet-simple-send)

;;;###autoload
(defun fibs-connect (host &optional port)
  "Open a network connection to HOST and PORT.
Return the buffer created."
  ;; I'm basically re-writing `telnet' here because it's stupid.
  (interactive (list (read-string "Open connection to host: "
                                  nil nil fibs-server)
                     (cond ((null current-prefix-arg) nil)
                           ((consp current-prefix-arg) (read-string "Port: "
                                                                    nil nil
                                                                    fibs-port))
                           (t (prefix-numeric-value current-prefix-arg)))))
  (let* ((comint-delimiter-argument-list '(?\  ?\t))
         (properties (alist-get host telnet-host-properties))
         (telnet-program (if properties (car properties) telnet-program))
         (hname (if port (format "%s:%s" host port) host))
         (name (format "%s-%s" telnet-program (comint-arguments hname 0 nil)))
         (buffer (get-buffer name))
         (telnet-options (when (cdr properties) (cons "-l" (cdr properties)))))
    ;; Clean up zombies
    (when (not (or (process-live-p fibs--process)
                   (buffer-live-p fibs--buffer)
                   (eq fibs--process (get-buffer-process fibs--buffer))))
      (fibs-kill))
    (setq fibs--buffer (apply #'make-comint-in-buffer name "*FIBS*"
                              telnet-program nil telnet-options))
    (unless fibs--process
      (setq fibs--process (get-buffer-process fibs--buffer))
      (with-current-buffer fibs--buffer
        (set-process-filter fibs--process (if fibs-password
                                              #'fibs--initial-filter
                                            #'telnet-initial-filter))
        ;; Don't sent `open' til telnet is ready for it.
        (accept-process-output fibs--process)
        (erase-buffer)
        (process-send-string fibs--process (format "open %s%s%s\n"
                                                   host (if port " " "")
                                                   (or port "")))
        (fibs-mode)
        (setq-local telnet-connect-command (list 'telnet host port))
        (setq comint-input-sender #'fibs-send)
        (setq telnet-count telnet-initial-count)))))

(defun fibs--initial-filter (proc string)
  "Process filter for FIBS buffers."
  ;; Rewritten from `telnet-initial-filter'.  I don't need to check for a
  ;; password from the user.  (At least right now.  I might want to change the
  ;; logic here.)
  (save-current-buffer
    (set-buffer (process-buffer proc))
    (let ((case-fold-search t))
      (cond ((string-match-p "No such host" string)
             (kill-buffer (process-buffer proc))
             (error "No such host"))
            ((and (string-match-p "login:" string)
                  fibs-autologin fibs-user)
             (fibs-send fibs--process fibs-user))
            ((and (string-match-p "password:" string)
                  fibs-autologin fibs-password)
             (fibs-send fibs--process fibs-password)
             (set-process-filter proc #'telnet-filter))
            (t (telnet-check-software-type-initialize string)
               (telnet-filter proc string)
               (cond ((> telnet-count telnet-maximum-count)
                      (set-process-filter proc #'telnet-filter))
                     (t (setq telnet-count (1+ telnet-count)))))))))

;;;###autoload
(defun fibs ()
  "Connect to the FIBS server."
  (interactive)
  (fibs-connect fibs-server fibs-port)
  (switch-to-buffer fibs--buffer))

(defun fibs-kill ()
  "Kill everything associated with fibs."
  (interactive)
  (let ((kill-buffer-query-functions nil))
    (condition-case nil
        (kill-process fibs--process)
      (t (setq fibs--process nil)))
    (condition-case nil
        (with-current-buffer fibs--buffer
          (remove-hook 'kill-buffer-hook #'fibs-kill t)
          (kill-buffer fibs--buffer))
      (t (setq fibs--buffer nil)))))

(define-derived-mode fibs-mode telnet-mode "FIBS"
  "This mode is for connecting to the First Internet Backgammon Server."
  (add-hook 'kill-buffer-hook #'fibs-kill nil t))

(provide 'fibs)
;;; fibs.el ends here
