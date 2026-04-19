;;; init.el -*- lexical-binding: t; -*-

;; This file controls what Doom modules are enabled and what order they load
;; in. Remember to run 'doom sync' after modifying it!

(doom! :input
       ;;bidi              ; (tfel ot) thgir etirw uoy gnipleh
       ;;chinese
       ;;japanese
       ;;layout            ; auie,ctsrnm is the superior home row

       :completion
       (corfu +orderless)  ; Fast, modern completion
       vertico             ; Modern search interface replacing ivy/helm

       :ui
       doom              ; Theme
       doom-dashboard    ; Start screen
       hl-todo           ; Highlight TODO/FIXME/NOTE/DEPRECATED
       modeline          ; Status bar
       ophints           ; Visual hints
       (popup +defaults) ; Popup window handling
       (vc-gutter +pretty) ; Git indicators in the margin
       vi-tilde-fringe   ; End-of-file markers (~)
       workspaces        ; Workspace management
       zen               ; Distraction-free mode

       :editor
       (evil +everywhere); Vim bindings everywhere
       file-templates    ; Automatic snippets for new files
       fold              ; Code folding
       (format +onsave)  ; Auto-format on save
       snippets          ; Code templates
       multiple-cursors  ; Multiple editing cursors

       :emacs
       dired             ; File manager
       electric          ; Smart indentation
       undo              ; Advanced undo history (undo-tree)
       vc                ; Version control

       :term
       vterm             ; Fast embedded terminal; needs the emacs.nix system module

       :checkers
       syntax            ; Syntax checking (Flycheck)
       (spell +flyspell) ; Spell checking

       :tools
       (eval +overlay)   ; REPL and inline code evaluation
       lookup            ; Documentation (K)
       lsp               ; Language Server Protocol engine
       magit             ; Git interface
       pdf               ; PDF reader for research papers
       tree-sitter       ; Fast code parsing
       docker            ; Docker management

       :os
       (:if (featurep :system 'macos) macos)
       tty

       :lang
       emacs-lisp        ; Configure Emacs
       markdown          ; Documentation
       nix               ; NixOS
       (org +roam +dragndrop +present) ; Notes, agenda, and Zettelkasten
       sh                ; Scripting shell (Bash)
       (python +lsp +pyright) ; Data science and AI
       (rust +lsp)       ; High-performance embedded work
       (cc +lsp)         ; C/C++ (Arduino/ESP32)
       latex             ; Scientific formulas
       yaml              ; Config Docker/K8s
       json              ; Data

       :config
       (default +bindings +smartparens))
