;; NOTE: Assertions have been generated by update_lit_checks.py --all-items and should not be edited.
;; NOTE: This test was ported using port_passes_tests_to_lit.py and could be cleaned up.

;; RUN: foreach %s %t wasm-opt --simplify-globals -all -S -o - | filecheck %s

(module
 ;; CHECK:      (type $A (func))
 (type $A (func))

 ;; CHECK:      (global $global$0 funcref (ref.func $func))
 (global $global$0 (mut funcref) (ref.func $func))

 ;; CHECK:      (elem declare func $func)

 ;; CHECK:      (func $func (type $A)
 ;; CHECK-NEXT:  (drop
 ;; CHECK-NEXT:   (ref.cast (ref (exact $A))
 ;; CHECK-NEXT:    (ref.func $func)
 ;; CHECK-NEXT:   )
 ;; CHECK-NEXT:  )
 ;; CHECK-NEXT: )
 (func $func
  (drop
   (ref.cast (ref null $A)
    ;; This global can be replaced with a ref.func of $func. That has a more
    ;; refined type, so we should refinalize (if we do not, then the ref.cast
    ;; will fail to validate as it must become a non-nullable cast).
    (global.get $global$0)
   )
  )
 )
)

(module
 ;; CHECK:      (type $struct (struct))
 (type $struct (struct ))

 ;; CHECK:      (type $1 (func (result anyref)))

 ;; CHECK:      (global $a (ref $struct) (struct.new_default $struct))
 (global $a (ref $struct) (struct.new_default $struct))
 ;; CHECK:      (global $b (ref $struct) (global.get $a))
 (global $b (ref $struct) (global.get $a))
 ;; CHECK:      (global $c (ref null $struct) (global.get $a))
 (global $c (ref null $struct) (global.get $a))

 ;; CHECK:      (func $get-c (type $1) (result anyref)
 ;; CHECK-NEXT:  (global.get $c)
 ;; CHECK-NEXT: )
 (func $get-c (result anyref)
  ;; $c has a less-refined type than the other two. We do not switch this to
  ;; get from either $a or $b because of that, but we could if we also
  ;; refinalized TODO
  (global.get $c)
 )
)

