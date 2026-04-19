;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; --- IDENTITY ---
(setq user-full-name "Romeo Cavazza"
      user-mail-address "ton.email@exemple.com")

;; --- APPEARANCE ---
;; Use the Nerd Font installed through NixOS.
(setq doom-font (font-spec :family "JetBrainsMono Nerd Font" :size 14 :weight 'medium)
      doom-variable-pitch-font (font-spec :family "JetBrainsMono Nerd Font" :size 14))

;; Visual theme.
(setq doom-theme 'doom-one)

;; Show relative line numbers, Vim-style.
(setq display-line-numbers-type 'relative)

;; --- ORG MODE ---
(setq org-directory "~/org/")

;; --- AI CONFIGURATION (GPTEL + OLLAMA) ---
(use-package! gptel
  :config
  ;; Use the symbol form, not the string form.
  (setq! gptel-model 'mistral
         gptel-backend (gptel-make-ollama "Ollama"
                         :host "localhost:11434"
                         :stream t
                         :models '(mistral llama3 gemma:2b))))

;; Shortcut to open an AI chat: SPC o c.
(map! :leader
      (:prefix ("o" . "open")
       :desc "Open AI Chat" "c" #'gptel))

;; --- PERFORMANCE ---
;; Improve LSP responsiveness.
(setq lsp-idle-delay 0.500)
