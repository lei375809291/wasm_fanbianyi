;; NOTE: Assertions have been generated by update_lit_checks.py --all-items and should not be edited.

;; Test that new-style nominal types are parsed correctly.
;; TODO: Remove --nominal below once nominal types are parsed as nominal by default.

;; RUN: foreach %s %t wasm-opt --nominal -all -S -o - | filecheck %s
;; RUN: foreach %s %t wasm-opt --nominal -all --roundtrip -S -o - | filecheck %s

;; void function type
(module
  ;; CHECK:      (type $sub (func) (extends $super))
  (type $sub (func_subtype $super))

  ;; CHECK:      (type $super (func))
  (type $super (func_subtype func))

  ;; CHECK:      (global $g (ref null $super) (ref.null $sub))
  (global $g (ref null $super) (ref.null $sub))
)

;; function type with params and results
(module
  ;; CHECK:      (type $sub (func (param i32) (result i32)) (extends $super))
  (type $sub (func_subtype (param i32) (result i32) $super))

  ;; CHECK:      (type $super (func (param i32) (result i32)))
  (type $super (func_subtype (param i32) (result i32) func))

  ;; CHECK:      (global $g (ref null $super) (ref.null $sub))
  (global $g (ref null $super) (ref.null $sub))
)

;; empty struct type
(module
  ;; CHECK:      (type $sub (struct ) (extends $super))
  (type $sub (struct_subtype $super))

  ;; CHECK:      (type $super (struct ))
  (type $super (struct_subtype data))

  ;; CHECK:      (global $g (ref null $super) (ref.null $sub))
  (global $g (ref null $super) (ref.null $sub))
)

;; struct type with fields
(module
  ;; CHECK:      (type $sub (struct (field i32) (field i64)) (extends $super))
  (type $sub (struct_subtype i32 (field i64) $super))

  ;; CHECK:      (type $super (struct (field i32) (field i64)))
  (type $super (struct_subtype (field i32) i64 data))

  ;; CHECK:      (global $g (ref null $super) (ref.null $sub))
  (global $g (ref null $super) (ref.null $sub))
)

;; array type
(module
  ;; CHECK:      (type $sub (array i8) (extends $super))
  (type $sub (array_subtype i8 $super))

  ;; CHECK:      (type $super (array i8))
  (type $super (array_subtype i8 data))

  ;; CHECK:      (global $g (ref null $super) (ref.null $sub))
  (global $g (ref null $super) (ref.null $sub))
)
