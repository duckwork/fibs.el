;;; fibs.el --- Play backgammon with FIBS in Emacs -*- lexical-binding: t; -*-

;;; Commentary:

;; FIBS (The First Internet Backgammon Server) is a popular server for playing
;; backgammon online.  Its interface is driven through telnet, which Emacs has
;; included in its distribution.  This package includes a number of niceties for
;; making playing backgammon on FIBS easier.

;;; Code:

(require 'telnet)

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

;;; Functions

;;;###autoload
(defun fibs ()
  "Connect to the FIBS server."
  (interactive)
  (telnet fibs-server fibs-port))

(provide 'fibs)
;;; fibs.el ends here
