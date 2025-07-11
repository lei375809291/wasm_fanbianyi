;; NOTE: Assertions have been generated by update_lit_checks.py --all-items and should not be edited.

;; (remove-unused-names allows the pass to see that blocks flow values)
;; RUN: wasm-opt %s -all --remove-unused-names --heap2local -S -o - | filecheck %s

(module
  (rec
    ;; CHECK:      (rec
    ;; CHECK-NEXT:  (type $described (descriptor $descriptor (struct (field i32))))
    (type $described (descriptor $descriptor (struct (field i32))))
    ;; CHECK:       (type $descriptor (describes $described (struct (field i64))))
    (type $descriptor (describes $described (struct (field i64))))

    ;; CHECK:       (type $super (sub (descriptor $super.desc (struct))))
    (type $super (sub (descriptor $super.desc (struct))))
    ;; CHECK:       (type $super.desc (sub (describes $super (struct))))
    (type $super.desc (sub (describes $super (struct))))

    ;; CHECK:       (type $sub (sub $super (descriptor $sub.desc (struct))))
    (type $sub (sub $super (descriptor $sub.desc (struct))))
    ;; CHECK:       (type $sub.desc (sub $super.desc (describes $sub (struct))))
    (type $sub.desc (sub $super.desc (describes $sub (struct))))

    ;; CHECK:       (type $no-desc (struct))
    (type $no-desc (struct))

    ;; CHECK:       (type $chain-described (descriptor $chain-middle (struct)))
    (type $chain-described (descriptor $chain-middle (struct)))
    ;; CHECK:       (type $chain-middle (describes $chain-described (descriptor $chain-descriptor (struct))))
    (type $chain-middle (describes $chain-described (descriptor $chain-descriptor (struct))))
    ;; CHECK:       (type $chain-descriptor (describes $chain-middle (struct)))
    (type $chain-descriptor (describes $chain-middle (struct)))
  )

  ;; CHECK:      (type $10 (func))

  ;; CHECK:      (type $11 (func (param (ref null (exact $super.desc)))))

  ;; CHECK:      (type $12 (func (result (ref null $super.desc))))

  ;; CHECK:      (type $13 (func (param (ref null (exact $super)))))

  ;; CHECK:      (type $14 (func (param (ref null (exact $chain-descriptor)))))

  ;; CHECK:      (global $desc (ref null (exact $descriptor)) (ref.null none))
  (global $desc (ref null (exact $descriptor)) (ref.null none))

  ;; CHECK:      (func $dropped (type $10)
  ;; CHECK-NEXT:  (local $0 i32)
  ;; CHECK-NEXT:  (local $1 (ref null (exact $descriptor)))
  ;; CHECK-NEXT:  (local $2 i32)
  ;; CHECK-NEXT:  (local $3 (ref null (exact $descriptor)))
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block (result nullref)
  ;; CHECK-NEXT:    (local.set $2
  ;; CHECK-NEXT:     (i32.const 1)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (local.set $3
  ;; CHECK-NEXT:     (ref.as_non_null
  ;; CHECK-NEXT:      (global.get $desc)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (local.set $0
  ;; CHECK-NEXT:     (local.get $2)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (local.set $1
  ;; CHECK-NEXT:     (local.get $3)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (ref.null none)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $dropped
    (drop
      (struct.new $described
        (i32.const 1)
        (global.get $desc)
      )
    )
  )

  ;; CHECK:      (func $dropped-default (type $10)
  ;; CHECK-NEXT:  (local $0 i32)
  ;; CHECK-NEXT:  (local $1 (ref null (exact $descriptor)))
  ;; CHECK-NEXT:  (local $2 (ref null (exact $descriptor)))
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block (result nullref)
  ;; CHECK-NEXT:    (local.set $2
  ;; CHECK-NEXT:     (ref.as_non_null
  ;; CHECK-NEXT:      (global.get $desc)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (local.set $0
  ;; CHECK-NEXT:     (i32.const 0)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (local.set $1
  ;; CHECK-NEXT:     (local.get $2)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (ref.null none)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $dropped-default
    (drop
      (struct.new_default $described
        (global.get $desc)
      )
    )
  )

  ;; CHECK:      (func $dropped-alloc-desc (type $10)
  ;; CHECK-NEXT:  (local $0 i32)
  ;; CHECK-NEXT:  (local $1 (ref (exact $descriptor)))
  ;; CHECK-NEXT:  (local $2 i32)
  ;; CHECK-NEXT:  (local $3 (ref (exact $descriptor)))
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block (result nullref)
  ;; CHECK-NEXT:    (local.set $2
  ;; CHECK-NEXT:     (i32.const 1)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (local.set $3
  ;; CHECK-NEXT:     (struct.new $descriptor
  ;; CHECK-NEXT:      (i64.const 2)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (local.set $0
  ;; CHECK-NEXT:     (local.get $2)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (local.set $1
  ;; CHECK-NEXT:     (local.get $3)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (ref.null none)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $dropped-alloc-desc
    (drop
      (struct.new $described
        (i32.const 1)
        (struct.new $descriptor
          (i64.const 2)
        )
      )
    )
  )

  ;; CHECK:      (func $dropped-default-alloc-desc (type $10)
  ;; CHECK-NEXT:  (local $0 i32)
  ;; CHECK-NEXT:  (local $1 (ref (exact $descriptor)))
  ;; CHECK-NEXT:  (local $2 (ref (exact $descriptor)))
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block (result nullref)
  ;; CHECK-NEXT:    (local.set $2
  ;; CHECK-NEXT:     (struct.new $descriptor
  ;; CHECK-NEXT:      (i64.const 2)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (local.set $0
  ;; CHECK-NEXT:     (i32.const 0)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (local.set $1
  ;; CHECK-NEXT:     (local.get $2)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (ref.null none)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $dropped-default-alloc-desc
    (drop
      (struct.new_default $described
        (struct.new $descriptor
          (i64.const 2)
        )
      )
    )
  )

  ;; CHECK:      (func $get-desc (type $12) (result (ref null $super.desc))
  ;; CHECK-NEXT:  (local $0 (ref (exact $super.desc)))
  ;; CHECK-NEXT:  (local $1 (ref (exact $super.desc)))
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block (result nullref)
  ;; CHECK-NEXT:    (local.set $1
  ;; CHECK-NEXT:     (struct.new_default $super.desc)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (local.set $0
  ;; CHECK-NEXT:     (local.get $1)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (ref.null none)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (local.get $0)
  ;; CHECK-NEXT: )
  (func $get-desc (result (ref null $super.desc))
    (ref.get_desc $super
      (struct.new $super
        (struct.new $super.desc)
      )
    )
  )

  ;; CHECK:      (func $get-desc-refinalize (type $12) (result (ref null $super.desc))
  ;; CHECK-NEXT:  (local $0 (ref (exact $sub.desc)))
  ;; CHECK-NEXT:  (local $1 (ref (exact $sub.desc)))
  ;; CHECK-NEXT:  (block (result (ref (exact $sub.desc)))
  ;; CHECK-NEXT:   (drop
  ;; CHECK-NEXT:    (block (result nullref)
  ;; CHECK-NEXT:     (block (result nullref)
  ;; CHECK-NEXT:      (local.set $1
  ;; CHECK-NEXT:       (struct.new_default $sub.desc)
  ;; CHECK-NEXT:      )
  ;; CHECK-NEXT:      (local.set $0
  ;; CHECK-NEXT:       (local.get $1)
  ;; CHECK-NEXT:      )
  ;; CHECK-NEXT:      (ref.null none)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:   (local.get $0)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $get-desc-refinalize (result (ref null $super.desc))
    ;; This block should be refinalized.
    (block (result (ref null $super.desc))
      (ref.get_desc $super
        (block (result (ref null $super))
          (struct.new $sub
            (struct.new $sub.desc)
          )
        )
      )
    )
  )

  ;; CHECK:      (func $cast-desc-success (type $10)
  ;; CHECK-NEXT:  (local $desc (ref null (exact $super.desc)))
  ;; CHECK-NEXT:  (local $1 (ref null (exact $super.desc)))
  ;; CHECK-NEXT:  (local $2 (ref null (exact $super.desc)))
  ;; CHECK-NEXT:  (local.set $desc
  ;; CHECK-NEXT:   (struct.new_default $super.desc)
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block (result nullref)
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (block (result nullref)
  ;; CHECK-NEXT:      (local.set $2
  ;; CHECK-NEXT:       (ref.as_non_null
  ;; CHECK-NEXT:        (local.get $desc)
  ;; CHECK-NEXT:       )
  ;; CHECK-NEXT:      )
  ;; CHECK-NEXT:      (local.set $1
  ;; CHECK-NEXT:       (local.get $2)
  ;; CHECK-NEXT:      )
  ;; CHECK-NEXT:      (ref.null none)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (if (result nullref)
  ;; CHECK-NEXT:     (ref.eq
  ;; CHECK-NEXT:      (local.get $desc)
  ;; CHECK-NEXT:      (local.get $1)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:     (then
  ;; CHECK-NEXT:      (ref.null none)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:     (else
  ;; CHECK-NEXT:      (unreachable)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $cast-desc-success
    (local $desc (ref null (exact $super.desc)))
    (local.set $desc
      (struct.new $super.desc)
    )
    (drop
      (ref.cast_desc (ref (exact $super))
        (struct.new $super
          (local.get $desc)
        )
        (local.get $desc)
      )
    )
  )

  ;; CHECK:      (func $cast-desc-fail (type $11) (param $desc (ref null (exact $super.desc)))
  ;; CHECK-NEXT:  (local $1 (ref (exact $super.desc)))
  ;; CHECK-NEXT:  (local $2 (ref (exact $super.desc)))
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block (result nullref)
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (block (result nullref)
  ;; CHECK-NEXT:      (local.set $2
  ;; CHECK-NEXT:       (struct.new_default $super.desc)
  ;; CHECK-NEXT:      )
  ;; CHECK-NEXT:      (local.set $1
  ;; CHECK-NEXT:       (local.get $2)
  ;; CHECK-NEXT:      )
  ;; CHECK-NEXT:      (ref.null none)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (if (result nullref)
  ;; CHECK-NEXT:     (ref.eq
  ;; CHECK-NEXT:      (local.get $desc)
  ;; CHECK-NEXT:      (local.get $1)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:     (then
  ;; CHECK-NEXT:      (ref.null none)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:     (else
  ;; CHECK-NEXT:      (unreachable)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $cast-desc-fail (param $desc (ref null (exact $super.desc)))
    (drop
      (ref.cast_desc (ref (exact $super))
        (struct.new $super
          (struct.new $super.desc)
        )
        (local.get $desc)
      )
    )
  )

  ;; CHECK:      (func $cast-desc-fail-reverse (type $11) (param $desc (ref null (exact $super.desc)))
  ;; CHECK-NEXT:  (local $1 (ref null (exact $super.desc)))
  ;; CHECK-NEXT:  (local $2 (ref null (exact $super.desc)))
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block (result nullref)
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (block (result nullref)
  ;; CHECK-NEXT:      (local.set $2
  ;; CHECK-NEXT:       (ref.as_non_null
  ;; CHECK-NEXT:        (local.get $desc)
  ;; CHECK-NEXT:       )
  ;; CHECK-NEXT:      )
  ;; CHECK-NEXT:      (local.set $1
  ;; CHECK-NEXT:       (local.get $2)
  ;; CHECK-NEXT:      )
  ;; CHECK-NEXT:      (ref.null none)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (if (result nullref)
  ;; CHECK-NEXT:     (ref.eq
  ;; CHECK-NEXT:      (block (result nullref)
  ;; CHECK-NEXT:       (ref.null none)
  ;; CHECK-NEXT:      )
  ;; CHECK-NEXT:      (local.get $1)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:     (then
  ;; CHECK-NEXT:      (ref.null none)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:     (else
  ;; CHECK-NEXT:      (unreachable)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $cast-desc-fail-reverse (param $desc (ref null (exact $super.desc)))
    ;; Same as above, but change where the parameter is used.
    (drop
      (ref.cast_desc (ref (exact $super))
        (struct.new $super
          (local.get $desc)
        )
        (struct.new $super.desc)
      )
    )
  )

  ;; CHECK:      (func $cast-desc-fail-param (type $13) (param $ref (ref null (exact $super)))
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (local.get $ref)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (block (result nullref)
  ;; CHECK-NEXT:      (ref.null none)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $cast-desc-fail-param (param $ref (ref null (exact $super)))
    ;; Now cast the parameter. We know it can't have the locally allocated
    ;; descriptor, so the cast fails.
    (drop
      (ref.cast_desc (ref (exact $super))
        (local.get $ref)
        (struct.new $super.desc)
      )
    )
  )

  ;; CHECK:      (func $cast-no-desc (type $11) (param $desc (ref null (exact $super.desc)))
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (block (result nullref)
  ;; CHECK-NEXT:      (ref.null none)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (local.get $desc)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $cast-no-desc (param $desc (ref null (exact $super.desc)))
    ;; The allocation does not have a descriptor, so we know the cast must fail.
    (drop
      (ref.cast_desc (ref (exact $super))
        (struct.new $no-desc)
        (local.get $desc)
      )
    )
  )

  ;; CHECK:      (func $cast-desc-and-ref (type $14) (param $desc (ref null (exact $chain-descriptor)))
  ;; CHECK-NEXT:  (local $middle (ref null (exact $chain-middle)))
  ;; CHECK-NEXT:  (local $2 (ref null (exact $chain-descriptor)))
  ;; CHECK-NEXT:  (local $3 (ref null (exact $chain-descriptor)))
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block (result nullref)
  ;; CHECK-NEXT:    (local.set $3
  ;; CHECK-NEXT:     (ref.as_non_null
  ;; CHECK-NEXT:      (local.get $desc)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (local.set $2
  ;; CHECK-NEXT:     (local.get $3)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (ref.null none)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (drop
  ;; CHECK-NEXT:   (block
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (ref.null none)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (drop
  ;; CHECK-NEXT:     (ref.null none)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (unreachable)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT: )
  (func $cast-desc-and-ref (param $desc (ref null (exact $chain-descriptor)))
    ;; The same allocation flows into both the descriptor and the reference. The
    ;; cast must fail because a value cannot be its own descriptor. We make sure
    ;; the descriptor itself has a descriptor so it is not handled by the same
    ;; logic as the previous test.
    (local $middle (ref null (exact $chain-middle)))
    (local.set $middle
      (struct.new $chain-middle
        (local.get $desc)
      )
    )
    (drop
      (ref.cast_desc (ref (exact $chain-described))
        (local.get $middle)
        (local.get $middle)
      )
    )
  )
)
