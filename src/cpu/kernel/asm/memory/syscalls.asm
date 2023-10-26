global sys_mload:
    // stack: kexit_info, offset
    DUP2 %ensure_reasonable_offset
    // stack: kexit_info, offset
    %charge_gas_const(@GAS_VERYLOW)
    // stack: kexit_info, offset
    DUP2 %add_const(32)
    // stack: expanded_num_bytes, kexit_info, offset
    %update_mem_bytes
    // stack: kexit_info, offset
    %stack(kexit_info, offset) -> (offset, 32, kexit_info)
    PUSH @SEGMENT_MAIN_MEMORY
    GET_CONTEXT
    // stack: addr: 3, len, kexit_info
    MLOAD_32BYTES
    %stack (value, kexit_info) -> (kexit_info, value)
    EXIT_KERNEL

global sys_mstore:
    // stack: kexit_info, offset, value
    DUP2 %ensure_reasonable_offset
    // stack: kexit_info, offset, value
    %charge_gas_const(@GAS_VERYLOW)
    // stack: kexit_info, offset, value
    DUP2 %add_const(32)
    // stack: expanded_num_bytes, kexit_info, offset, value
    %update_mem_bytes
    // stack: kexit_info, offset, value
    %stack(kexit_info, offset, value) -> (offset, value, 32, kexit_info)
    PUSH @SEGMENT_MAIN_MEMORY
    GET_CONTEXT
    // stack: addr: 3, value, len, kexit_info
    MSTORE_32BYTES
    // stack: kexit_info
    EXIT_KERNEL

global sys_mstore8:
    // stack: kexit_info, offset, value
    DUP2 %ensure_reasonable_offset
    // stack: kexit_info, offset, value
    %charge_gas_const(@GAS_VERYLOW)
    // stack: kexit_info, offset, value
    DUP2 %increment
    // stack: expanded_num_bytes, kexit_info, offset, value
    %update_mem_bytes
    // stack: kexit_info, offset, value
    %stack (kexit_info, offset, value) -> (value, 0x100, offset, kexit_info)
    MOD SWAP1
    %mstore_current(@SEGMENT_MAIN_MEMORY)
    // stack: kexit_info
    EXIT_KERNEL

global sys_calldataload:
    // stack: kexit_info, i
    %charge_gas_const(@GAS_VERYLOW)
    // stack: kexit_info, i
    %mload_context_metadata(@CTX_METADATA_CALLDATA_SIZE)
    %stack (calldata_size, kexit_info, i) -> (calldata_size, i, kexit_info, i)
    LT %jumpi(calldataload_large_offset)
    %stack (kexit_info, i) -> (@SEGMENT_CALLDATA, i, 32, sys_calldataload_after_mload_packing, kexit_info)
    GET_CONTEXT
    // stack: ADDR: 3, 32, sys_calldataload_after_mload_packing, kexit_info
    %jump(mload_packing)
sys_calldataload_after_mload_packing:
    // stack: value, kexit_info
    SWAP1
    EXIT_KERNEL
    PANIC
calldataload_large_offset:
    %stack (kexit_info, i) -> (kexit_info, 0)
    EXIT_KERNEL

// Macro for {CALLDATA, RETURNDATA}COPY (W_copy in Yellow Paper).
%macro wcopy(segment, context_metadata_size)
    // stack: kexit_info, dest_offset, offset, size
    %wcopy_charge_gas

    %stack (kexit_info, dest_offset, offset, size) -> (dest_offset, size, kexit_info, dest_offset, offset, size)
    %add_or_fault
    // stack: expanded_num_bytes, kexit_info, dest_offset, offset, size, kexit_info
    DUP1 %ensure_reasonable_offset
    %update_mem_bytes
    // stack: kexit_info, dest_offset, offset, size, kexit_info
    DUP4 DUP4 %add_or_fault // Overflow check
    %mload_context_metadata($context_metadata_size) LT %jumpi(fault_exception) // Data len check

    %mload_context_metadata($context_metadata_size)
    // stack: total_size, kexit_info, dest_offset, offset, size
    DUP4
    // stack: offset, total_size, kexit_info, dest_offset, offset, size
    GT %jumpi(wcopy_large_offset)

    // stack: kexit_info, dest_offset, offset, size
    PUSH $segment
    PUSH wcopy_within_bounds
    JUMP
%endmacro

%macro wcopy_charge_gas
    // stack: kexit_info, dest_offset, offset, size
    PUSH @GAS_VERYLOW
    DUP5
    // stack: size, Gverylow, kexit_info, dest_offset, offset, size
    ISZERO %jumpi(wcopy_empty)
    // stack: Gverylow, kexit_info, dest_offset, offset, size
    DUP5 %num_bytes_to_num_words %mul_const(@GAS_COPY) ADD %charge_gas
%endmacro

wcopy_within_bounds:
    // stack: segment, kexit_info, dest_offset, offset, size
    GET_CONTEXT
    %stack (context, segment, kexit_info, dest_offset, offset, size) ->
        (context, @SEGMENT_MAIN_MEMORY, dest_offset, context, segment, offset, size, wcopy_after, kexit_info)
    %jump(memcpy_bytes)

wcopy_empty:
    // stack: Gverylow, kexit_info, dest_offset, offset, size
    %charge_gas
    %stack (kexit_info, dest_offset, offset, size) -> (kexit_info)
    EXIT_KERNEL

wcopy_large_offset:
    // offset is larger than the size of the {CALLDATA,CODE,RETURNDATA}. So we just have to write zeros.
    // stack: kexit_info, dest_offset, offset, size
    GET_CONTEXT
    %stack (context, kexit_info, dest_offset, offset, size) ->
        (context, @SEGMENT_MAIN_MEMORY, dest_offset, size, wcopy_after, kexit_info)
    %jump(memset)

wcopy_after:
    // stack: kexit_info
    EXIT_KERNEL

global sys_calldatacopy:
    %wcopy(@SEGMENT_CALLDATA, @CTX_METADATA_CALLDATA_SIZE)

global sys_codecopy:
    %codecopy(@SEGMENT_CODE, @CTX_METADATA_CODE_SIZE)

global sys_returndatacopy:
    %wcopy(@SEGMENT_RETURNDATA, @CTX_METADATA_RETURNDATA_SIZE)

%macro codecopy(segment, context_metadata_size)
    // stack: kexit_info, dest_offset, offset, size
    %wcopy_charge_gas

    %stack (kexit_info, dest_offset, offset, size) -> (dest_offset, size, kexit_info, dest_offset, offset, size)
    %add_or_fault
    // stack: expanded_num_bytes, kexit_info, dest_offset, offset, size, kexit_info
    DUP1 %ensure_reasonable_offset
    %update_mem_bytes

    %mload_context_metadata($context_metadata_size)
    // stack: total_size, kexit_info, dest_offset, offset, size
    DUP4
    // stack: offset, total_size, kexit_info, dest_offset, offset, size
    GT %jumpi(wcopy_large_offset)

    PUSH $segment
    %mload_context_metadata($context_metadata_size)
    // stack: total_size, segment, kexit_info, dest_offset, offset, size
    DUP6 DUP6 ADD
    // stack: offset + size, total_size, segment, kexit_info, dest_offset, offset, size
    LT %jumpi(wcopy_within_bounds)

    %mload_context_metadata($context_metadata_size)
    // stack: total_size, segment, kexit_info, dest_offset, offset, size
    DUP6 DUP6 ADD
    // stack: offset + size, total_size, segment, kexit_info, dest_offset, offset, size
    SUB // extra_size = offset + size - total_size
    // stack: extra_size, segment, kexit_info, dest_offset, offset, size
    DUP1 DUP7 SUB
    // stack: copy_size = size - extra_size, extra_size, segment, kexit_info, dest_offset, offset, size

    // Compute the new dest_offset after actual copies, at which we will start padding with zeroes.
    DUP1 DUP6 ADD
    // stack: new_dest_offset, copy_size, extra_size, segment, kexit_info, dest_offset, offset, size

    GET_CONTEXT
    %stack (context, new_dest_offset, copy_size, extra_size, segment, kexit_info, dest_offset, offset, size) ->
        (context, @SEGMENT_MAIN_MEMORY, dest_offset, context, segment, offset, copy_size, wcopy_large_offset, kexit_info, new_dest_offset, offset, extra_size)
    %jump(memcpy_bytes)
%endmacro
