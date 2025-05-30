;; NOTE: Assertions have been generated by update_lit_checks.py --all-items and should not be edited.
;; NOTE: This test was ported using port_passes_tests_to_lit.py and could be cleaned up.

;; RUN: foreach %s %t wasm-opt --asyncify --pass-arg=asyncify-addlist@foo -S --pass-arg=asyncify-propagate-addlist -o - | filecheck %s

(module
  ;; CHECK:      (type $0 (func))

  ;; CHECK:      (type $1 (func (param i32)))

  ;; CHECK:      (type $2 (func (result i32)))

  ;; CHECK:      (import "env" "import" (func $import))
  (import "env" "import" (func $import))

  (memory 1 2)
  ;; CHECK:      (global $__asyncify_state (mut i32) (i32.const 0))

  ;; CHECK:      (global $__asyncify_data (mut i32) (i32.const 0))

  ;; CHECK:      (memory $0 1 2)

  ;; CHECK:      (export "asyncify_start_unwind" (func $asyncify_start_unwind))

  ;; CHECK:      (export "asyncify_stop_unwind" (func $asyncify_stop_unwind))

  ;; CHECK:      (export "asyncify_start_rewind" (func $asyncify_start_rewind))

  ;; CHECK:      (export "asyncify_stop_rewind" (func $asyncify_stop_rewind))

  ;; CHECK:      (export "asyncify_get_state" (func $asyncify_get_state))

  ;; CHECK:      (func $foo
  ;; CHECK-NEXT:  (local $0 i32)
  ;; CHECK-NEXT:  (local $1 i32)
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (i32.eq
  ;; CHECK-NEXT:    (global.get $__asyncify_state)
  ;; CHECK-NEXT:    (i32.const 2)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:   (then
  ;; CHECK-NEXT:    (nop)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (local.tee $0
  ;; CHECK-NEXT:   (block $__asyncify_unwind
  ;; CHECK-NEXT:    (block
  ;; CHECK-NEXT:     (block
  ;; CHECK-NEXT:      (if
  ;; CHECK-NEXT:       (i32.eq
  ;; CHECK-NEXT:        (global.get $__asyncify_state)
  ;; CHECK-NEXT:        (i32.const 2)
  ;; CHECK-NEXT:       )
  ;; CHECK-NEXT:       (then
  ;; CHECK-NEXT:        (i32.store
  ;; CHECK-NEXT:         (global.get $__asyncify_data)
  ;; CHECK-NEXT:         (i32.add
  ;; CHECK-NEXT:          (i32.load
  ;; CHECK-NEXT:           (global.get $__asyncify_data)
  ;; CHECK-NEXT:          )
  ;; CHECK-NEXT:          (i32.const -4)
  ;; CHECK-NEXT:         )
  ;; CHECK-NEXT:        )
  ;; CHECK-NEXT:        (local.set $1
  ;; CHECK-NEXT:         (i32.load
  ;; CHECK-NEXT:          (i32.load
  ;; CHECK-NEXT:           (global.get $__asyncify_data)
  ;; CHECK-NEXT:          )
  ;; CHECK-NEXT:         )
  ;; CHECK-NEXT:        )
  ;; CHECK-NEXT:       )
  ;; CHECK-NEXT:      )
  ;; CHECK-NEXT:      (if
  ;; CHECK-NEXT:       (i32.eq
  ;; CHECK-NEXT:        (global.get $__asyncify_state)
  ;; CHECK-NEXT:        (i32.const 0)
  ;; CHECK-NEXT:       )
  ;; CHECK-NEXT:       (then
  ;; CHECK-NEXT:        (call $nothing)
  ;; CHECK-NEXT:       )
  ;; CHECK-NEXT:      )
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:     (return)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (block
  ;; CHECK-NEXT:   (i32.store
  ;; CHECK-NEXT:    (i32.load
  ;; CHECK-NEXT:     (global.get $__asyncify_data)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (local.get $0)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:   (i32.store
  ;; CHECK-NEXT:    (global.get $__asyncify_data)
  ;; CHECK-NEXT:    (i32.add
  ;; CHECK-NEXT:     (i32.load
  ;; CHECK-NEXT:      (global.get $__asyncify_data)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:     (i32.const 4)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT: )
  (func $foo ;; doesn't look like it needs instrumentation, but in add list
    (call $nothing)
  )
  ;; CHECK:      (func $bar
  ;; CHECK-NEXT:  (call $nothing)
  ;; CHECK-NEXT: )
  (func $bar ;; doesn't look like it needs instrumentation, and not in add list
    (call $nothing)
  )
  ;; CHECK:      (func $nothing
  ;; CHECK-NEXT: )
  (func $nothing
  )
  ;; CHECK:      (func $call_foo
  ;; CHECK-NEXT:  (local $0 i32)
  ;; CHECK-NEXT:  (local $1 i32)
  ;; CHECK-NEXT:  (if
  ;; CHECK-NEXT:   (i32.eq
  ;; CHECK-NEXT:    (global.get $__asyncify_state)
  ;; CHECK-NEXT:    (i32.const 2)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:   (then
  ;; CHECK-NEXT:    (nop)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (local.set $0
  ;; CHECK-NEXT:   (block $__asyncify_unwind (result i32)
  ;; CHECK-NEXT:    (block
  ;; CHECK-NEXT:     (block
  ;; CHECK-NEXT:      (if
  ;; CHECK-NEXT:       (i32.eq
  ;; CHECK-NEXT:        (global.get $__asyncify_state)
  ;; CHECK-NEXT:        (i32.const 2)
  ;; CHECK-NEXT:       )
  ;; CHECK-NEXT:       (then
  ;; CHECK-NEXT:        (i32.store
  ;; CHECK-NEXT:         (global.get $__asyncify_data)
  ;; CHECK-NEXT:         (i32.add
  ;; CHECK-NEXT:          (i32.load
  ;; CHECK-NEXT:           (global.get $__asyncify_data)
  ;; CHECK-NEXT:          )
  ;; CHECK-NEXT:          (i32.const -4)
  ;; CHECK-NEXT:         )
  ;; CHECK-NEXT:        )
  ;; CHECK-NEXT:        (local.set $1
  ;; CHECK-NEXT:         (i32.load
  ;; CHECK-NEXT:          (i32.load
  ;; CHECK-NEXT:           (global.get $__asyncify_data)
  ;; CHECK-NEXT:          )
  ;; CHECK-NEXT:         )
  ;; CHECK-NEXT:        )
  ;; CHECK-NEXT:       )
  ;; CHECK-NEXT:      )
  ;; CHECK-NEXT:      (if
  ;; CHECK-NEXT:       (i32.or
  ;; CHECK-NEXT:        (i32.eq
  ;; CHECK-NEXT:         (global.get $__asyncify_state)
  ;; CHECK-NEXT:         (i32.const 0)
  ;; CHECK-NEXT:        )
  ;; CHECK-NEXT:        (i32.eq
  ;; CHECK-NEXT:         (local.get $1)
  ;; CHECK-NEXT:         (i32.const 0)
  ;; CHECK-NEXT:        )
  ;; CHECK-NEXT:       )
  ;; CHECK-NEXT:       (then
  ;; CHECK-NEXT:        (call $foo)
  ;; CHECK-NEXT:        (if
  ;; CHECK-NEXT:         (i32.eq
  ;; CHECK-NEXT:          (global.get $__asyncify_state)
  ;; CHECK-NEXT:          (i32.const 1)
  ;; CHECK-NEXT:         )
  ;; CHECK-NEXT:         (then
  ;; CHECK-NEXT:          (br $__asyncify_unwind
  ;; CHECK-NEXT:           (i32.const 0)
  ;; CHECK-NEXT:          )
  ;; CHECK-NEXT:         )
  ;; CHECK-NEXT:        )
  ;; CHECK-NEXT:       )
  ;; CHECK-NEXT:      )
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:     (return)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (block
  ;; CHECK-NEXT:   (i32.store
  ;; CHECK-NEXT:    (i32.load
  ;; CHECK-NEXT:     (global.get $__asyncify_data)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:    (local.get $0)
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:   (i32.store
  ;; CHECK-NEXT:    (global.get $__asyncify_data)
  ;; CHECK-NEXT:    (i32.add
  ;; CHECK-NEXT:     (i32.load
  ;; CHECK-NEXT:      (global.get $__asyncify_data)
  ;; CHECK-NEXT:     )
  ;; CHECK-NEXT:     (i32.const 4)
  ;; CHECK-NEXT:    )
  ;; CHECK-NEXT:   )
  ;; CHECK-NEXT:  )
  ;; CHECK-NEXT:  (nop)
  ;; CHECK-NEXT: )
  (func $call_foo ;; doesn't look like it needs instrumentation, but propagated from add list
    (call $foo)
  )
)

;; CHECK:      (func $asyncify_start_unwind (param $0 i32)
;; CHECK-NEXT:  (global.set $__asyncify_state
;; CHECK-NEXT:   (i32.const 1)
;; CHECK-NEXT:  )
;; CHECK-NEXT:  (global.set $__asyncify_data
;; CHECK-NEXT:   (local.get $0)
;; CHECK-NEXT:  )
;; CHECK-NEXT:  (if
;; CHECK-NEXT:   (i32.gt_u
;; CHECK-NEXT:    (i32.load
;; CHECK-NEXT:     (global.get $__asyncify_data)
;; CHECK-NEXT:    )
;; CHECK-NEXT:    (i32.load offset=4
;; CHECK-NEXT:     (global.get $__asyncify_data)
;; CHECK-NEXT:    )
;; CHECK-NEXT:   )
;; CHECK-NEXT:   (then
;; CHECK-NEXT:    (unreachable)
;; CHECK-NEXT:   )
;; CHECK-NEXT:  )
;; CHECK-NEXT: )

;; CHECK:      (func $asyncify_stop_unwind
;; CHECK-NEXT:  (global.set $__asyncify_state
;; CHECK-NEXT:   (i32.const 0)
;; CHECK-NEXT:  )
;; CHECK-NEXT:  (if
;; CHECK-NEXT:   (i32.gt_u
;; CHECK-NEXT:    (i32.load
;; CHECK-NEXT:     (global.get $__asyncify_data)
;; CHECK-NEXT:    )
;; CHECK-NEXT:    (i32.load offset=4
;; CHECK-NEXT:     (global.get $__asyncify_data)
;; CHECK-NEXT:    )
;; CHECK-NEXT:   )
;; CHECK-NEXT:   (then
;; CHECK-NEXT:    (unreachable)
;; CHECK-NEXT:   )
;; CHECK-NEXT:  )
;; CHECK-NEXT: )

;; CHECK:      (func $asyncify_start_rewind (param $0 i32)
;; CHECK-NEXT:  (global.set $__asyncify_state
;; CHECK-NEXT:   (i32.const 2)
;; CHECK-NEXT:  )
;; CHECK-NEXT:  (global.set $__asyncify_data
;; CHECK-NEXT:   (local.get $0)
;; CHECK-NEXT:  )
;; CHECK-NEXT:  (if
;; CHECK-NEXT:   (i32.gt_u
;; CHECK-NEXT:    (i32.load
;; CHECK-NEXT:     (global.get $__asyncify_data)
;; CHECK-NEXT:    )
;; CHECK-NEXT:    (i32.load offset=4
;; CHECK-NEXT:     (global.get $__asyncify_data)
;; CHECK-NEXT:    )
;; CHECK-NEXT:   )
;; CHECK-NEXT:   (then
;; CHECK-NEXT:    (unreachable)
;; CHECK-NEXT:   )
;; CHECK-NEXT:  )
;; CHECK-NEXT: )

;; CHECK:      (func $asyncify_stop_rewind
;; CHECK-NEXT:  (global.set $__asyncify_state
;; CHECK-NEXT:   (i32.const 0)
;; CHECK-NEXT:  )
;; CHECK-NEXT:  (if
;; CHECK-NEXT:   (i32.gt_u
;; CHECK-NEXT:    (i32.load
;; CHECK-NEXT:     (global.get $__asyncify_data)
;; CHECK-NEXT:    )
;; CHECK-NEXT:    (i32.load offset=4
;; CHECK-NEXT:     (global.get $__asyncify_data)
;; CHECK-NEXT:    )
;; CHECK-NEXT:   )
;; CHECK-NEXT:   (then
;; CHECK-NEXT:    (unreachable)
;; CHECK-NEXT:   )
;; CHECK-NEXT:  )
;; CHECK-NEXT: )

;; CHECK:      (func $asyncify_get_state (result i32)
;; CHECK-NEXT:  (global.get $__asyncify_state)
;; CHECK-NEXT: )
