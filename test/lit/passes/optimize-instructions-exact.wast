;; NOTE: Assertions have been generated by update_lit_checks.py and should not be edited.

;; Check that optimizations on casts involving exact reference types work
;; correctly.

;; RUN: wasm-opt %s -all --optimize-instructions -S -o - | filecheck %s

(module
 ;; CHECK:      (type $struct (struct))
 (type $struct (struct))
 ;; CHECK:      (func $cast-to-exact (type $1) (param $0 anyref) (result (ref (exact $struct)))
 ;; CHECK-NEXT:  (ref.cast (ref (exact $struct))
 ;; CHECK-NEXT:   (local.get $0)
 ;; CHECK-NEXT:  )
 ;; CHECK-NEXT: )
 (func $cast-to-exact (param anyref) (result (ref (exact $struct)))
  ;; This will not be changed, but should not trigger an assertion.
  (ref.cast (ref (exact $struct))
   (local.get 0)
  )
 )
)
