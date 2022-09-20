%macro jump(dst)
    push $dst
    jump
%endmacro

%macro jumpi(dst)
    push $dst
    jumpi
%endmacro

%macro pop2
    %rep 2
        pop
    %endrep
%endmacro

%macro pop3
    %rep 3
        pop
    %endrep
%endmacro

%macro pop4
    %rep 4
        pop
    %endrep
%endmacro

%macro pop5
    %rep 5
        pop
    %endrep
%endmacro

%macro pop6
    %rep 6
        pop
    %endrep
%endmacro

%macro pop7
    %rep 7
        pop
    %endrep
%endmacro

%macro and_const(c)
    // stack: input, ...
    PUSH $c
    AND
    // stack: input & c, ...
%endmacro

%macro add_const(c)
    // stack: input, ...
    PUSH $c
    ADD
    // stack: input + c, ...
%endmacro

// Slightly inefficient as we need to swap the inputs.
// Consider avoiding this in performance-critical code.
%macro sub_const(c)
    // stack: input, ...
    PUSH $c
    // stack: c, input, ...
    SWAP1
    // stack: input, c, ...
    SUB
    // stack: input - c, ...
%endmacro

%macro mul_const(c)
    // stack: input, ...
    PUSH $c
    MUL
    // stack: input * c, ...
%endmacro

// Slightly inefficient as we need to swap the inputs.
// Consider avoiding this in performance-critical code.
%macro div_const(c)
    // stack: input, ...
    PUSH $c
    // stack: c, input, ...
    SWAP1
    // stack: input, c, ...
    DIV
    // stack: input / c, ...
%endmacro

// Slightly inefficient as we need to swap the inputs.
// Consider avoiding this in performance-critical code.
%macro mod_const(c)
    // stack: input, ...
    PUSH $c
    // stack: c, input, ...
    SWAP1
    // stack: input, c, ...
    MOD
    // stack: input % c, ...
%endmacro

%macro shl_const(c)
    // stack: input, ...
    PUSH $c
    SHL
    // stack: input << c, ...
%endmacro

%macro shr_const(c)
    // stack: input, ...
    PUSH $c
    SHR
    // stack: input >> c, ...
%endmacro

%macro eq_const(c)
    // stack: input, ...
    PUSH $c
    EQ
    // stack: input == c, ...
%endmacro

%macro lt_const(c)
    // stack: input, ...
    PUSH $c
    // stack: c, input, ...
    GT // Check it backwards: (input < c) == (c > input)
    // stack: input <= c, ...
%endmacro

%macro le_const(c)
    // stack: input, ...
    PUSH $c
    // stack: c, input, ...
    LT ISZERO // Check it backwards: (input <= c) == !(c < input)
    // stack: input <= c, ...
%endmacro

%macro gt_const(c)
    // stack: input, ...
    PUSH $c
    // stack: c, input, ...
    LT // Check it backwards: (input > c) == (c < input)
    // stack: input >= c, ...
%endmacro

%macro ge_const(c)
    // stack: input, ...
    PUSH $c
    // stack: c, input, ...
    GT ISZERO // Check it backwards: (input >= c) == !(c > input)
    // stack: input >= c, ...
%endmacro

%macro and_const(c)
    // stack: x
    PUSH $c
    AND
    // stack: c & x
%endmacro

%macro consume_gas_const(c)
    PUSH $c
    CONSUME_GAS
%endmacro

// If pred is zero, yields z; otherwise, yields nz
%macro select
    // stack: pred, nz, z
    iszero
    // stack: pred == 0, nz, z
    dup1
    // stack: pred == 0, pred == 0, nz, z
    iszero
    // stack: pred != 0, pred == 0, nz, z
    swap3
    // stack: z, pred == 0, nz, pred != 0
    mul
    // stack: (pred == 0) * z, nz, pred != 0
    swap2
    // stack: pred != 0, nz, (pred == 0) * z
    mul
    // stack: (pred != 0) * nz, (pred == 0) * z
    add
    // stack: (pred != 0) * nz + (pred == 0) * z
%endmacro

// If pred, yields z; otherwise, yields nz
// Assumes pred is boolean (either 0 or 1).
%macro select_bool
    // stack: pred, nz, z
    dup1
    // stack: pred, pred, nz, z
    iszero
    // stack: notpred, pred, nz, z
    swap3
    // stack: z, pred, nz, notpred
    mul
    // stack: pred * z, nz, notpred
    swap2
    // stack: notpred, nz, pred * z
    mul
    // stack: notpred * nz, pred * z
    add
    // stack: notpred * nz + pred * z
%endmacro

%macro square
    // stack: x
    dup1
    // stack: x, x
    mul
    // stack: x^2
%endmacro

%macro min
    // stack: x, y
    DUP2
    DUP2
    // stack: x, y, x, y
    LT
    // stack: x < y, x, y
    %select_bool
    // stack: min
%endmacro

%macro max
    // stack: x, y
    DUP2
    DUP2
    // stack: x, y, x, y
    GT
    // stack: x > y, x, y
    %select_bool
    // stack: max
%endmacro

%macro u32
    %and_const(0xffffffff)
%endmacro

%macro not_32
    // stack: x
    PUSH 0xffffffff
    // stack: 0xffffffff, x
    SUB
    // stack: 0xffffffff - x
%endmacro

%macro add3_32
    // stack: x, y, z
    ADD
    // stack: x+y, z
    ADD
    // stack: x+y+z
    %u32
%endmacro


// given u32 bytestring abcd return dcba
%macro flip_bytes_u32
    // stack: abcd
    DUP1
    %and_const(0xFF)
    // stack: d, abcd
    PUSH 0xFF
    DUP1
    SWAP2
    // stack: abcd, d, 0xFF, d
    SUB
    DIV
    // stack: abc, d
    DUP1
    %and_const(0xFF)
    // stack: c, abcd, d
    PUSH 0xFF
    DUP1
    SWAP2
    // stack: abc, c, 0xFF, c, d
    SUB
    DIV
    // stack: ab, c, d
    DUP1
    %and_const(0xFF)
    // stack: b, ab, c, d
    PUSH 0xFF
    DUP1
    SWAP2
    // stack: ab, b, 0xFF, b, c, d
    SUB
    DIV
    // stack: a, b, c, d
    SWAP1
    %mul_const(0x100)
    ADD
    // stack: ba, c, d
    SWAP1
    %mul_const(0x10000)
    ADD
    // stack: cba, d
    SWAP1
    %mul_const(0x1000000)
    ADD
    // stack: dcba
%endmacro
