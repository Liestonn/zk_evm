use std::str::FromStr;

use anyhow::Result;
use ethereum_types::U256;

use crate::bn254_arithmetic::{fp12_to_vec, frob_fp12, gen_fp12, gen_fp12_sparse, Fp12};
use crate::cpu::kernel::aggregator::KERNEL;
use crate::cpu::kernel::interpreter::{run_interpreter, Interpreter};
use crate::memory::segments::Segment;
use crate::witness::memory::MemoryAddress;

struct InterpreterInit {
    offset: String,
    stack: Vec<U256>,
    memory: Vec<(usize, Vec<U256>)>,
}

fn run_test_interpreter(init: InterpreterInit) -> Result<Vec<U256>> {
    let label = KERNEL.global_labels[&init.offset];
    let mut stack = init.stack;
    stack.reverse();
    let mut interpreter = Interpreter::new_with_kernel(label, stack);
    
    for (pointer, data) in init.memory {
        for (i, term) in data.iter().enumerate() {
            interpreter.generation_state.memory.set(
                MemoryAddress::new(0, Segment::KernelGeneral, pointer + i),
                *term,
            )
        }
    }

    interpreter.run()?;
    let mut output = interpreter.stack().to_vec();
    output.reverse();
    Ok(output)
}

fn get_address_from_label(lbl: &str) -> U256 {
    U256::from(KERNEL.global_labels[lbl])
}

fn make_mul_interpreter(f: Fp12, g: Fp12, mul_label: String) -> InterpreterInit {
    let in0 = U256::from(64);
    let in1 = U256::from(76);
    let out = U256::from(88);

    let stack = vec![
        in0,
        in1,
        out,
        get_address_from_label("return_fp12_on_stack"),
        out,
    ];

    let memory = vec![
        (64usize, fp12_to_vec(f)),
        (76, fp12_to_vec(g))
    ];

    InterpreterInit { offset: mul_label, stack: stack, memory: memory }

    // let mut stack = vec![in0];
    // stack.extend(fp12_to_vec(f));
    // stack.extend(vec![in1]);
    // stack.extend(fp12_to_vec(g));
    // stack.extend(vec![
    //     get_address_from_label(mul_label),
    //     in0,
    //     in1,
    //     out,
    //     get_address_from_label("return_fp12_on_stack"),
    //     out,
    // ]);
    // stack
}

#[test]
fn test_mul_fp12() -> Result<()> {
    let f: Fp12 = gen_fp12();
    let g: Fp12 = gen_fp12();
    let h: Fp12 = gen_fp12_sparse();

    let normal: InterpreterInit = make_mul_interpreter(f, g, "mul_fp12".to_string());
    let sparse: InterpreterInit = make_mul_interpreter(f, h, "mul_fp12_sparse".to_string());
    let square: InterpreterInit = make_mul_interpreter(f, f, "square_fp12_test".to_string());

    let out_normal: Vec<U256> = run_test_interpreter(normal).unwrap();
    let out_sparse: Vec<U256> = run_test_interpreter(sparse).unwrap();
    let out_square: Vec<U256> = run_test_interpreter(square).unwrap();

    let exp_normal: Vec<U256> = fp12_to_vec(f * g);
    let exp_sparse: Vec<U256> = fp12_to_vec(f * h);
    let exp_square: Vec<U256> = fp12_to_vec(f * f);

    assert_eq!(out_normal, exp_normal);
    assert_eq!(out_sparse, exp_sparse);
    assert_eq!(out_square, exp_square);

    Ok(())
}

// #[test]
// fn test_frob_fp12() -> Result<()> {
//     let ptr = U256::from(100);
//     let f: Fp12 = gen_fp12();

//     let mut stack = vec![ptr];
//     stack.extend(fp12_to_vec(f));
//     stack.extend(vec![ptr]);

//     let out_frob1: Vec<U256> = run_test_interpreter("test_frob_fp12_1", stack.clone());
//     let out_frob2: Vec<U256> = run_test_interpreter("test_frob_fp12_2", stack.clone());
//     let out_frob3: Vec<U256> = run_test_interpreter("test_frob_fp12_3", stack.clone());
//     let out_frob6: Vec<U256> = run_test_interpreter("test_frob_fp12_6", stack);

//     let exp_frob1: Vec<U256> = fp12_to_vec(frob_fp12(1, f));
//     let exp_frob2: Vec<U256> = fp12_to_vec(frob_fp12(2, f));
//     let exp_frob3: Vec<U256> = fp12_to_vec(frob_fp12(3, f));
//     let exp_frob6: Vec<U256> = fp12_to_vec(frob_fp12(6, f));

//     assert_eq!(out_frob1, exp_frob1);
//     assert_eq!(out_frob2, exp_frob2);
//     assert_eq!(out_frob3, exp_frob3);
//     assert_eq!(out_frob6, exp_frob6);

//     Ok(())
// }

// #[test]
// fn test_inv_fp12() -> Result<()> {
//     let ptr = U256::from(200);
//     let inv = U256::from(300);

//     let f: Fp12 = gen_fp12();
//     let mut stack = vec![ptr];
//     stack.extend(fp12_to_vec(f));
//     stack.extend(vec![ptr, inv, U256::from_str("0xdeadbeef").unwrap()]);

//     let output: Vec<U256> = run_test_interpreter("test_inv_fp12", stack);

//     assert_eq!(output, vec![]);

//     Ok(())
// }

// #[test]
// fn test_power() -> Result<()> {
//     let ptr = U256::from(300);
//     let out = U256::from(400);

//     let f: Fp12 = gen_fp12();

//     let mut stack = vec![ptr];
//     stack.extend(fp12_to_vec(f));
//     stack.extend(vec![
//         ptr,
//         out,
//         get_address_from_label("return_fp12_on_stack"),
//         out,
//     ]);

//     let output: Vec<U256> = run_test_interpreter("test_pow", stack);
//     let expected: Vec<U256> = fp12_to_vec(power(f));

//     assert_eq!(output, expected);

//     Ok(())
// }

// fn make_tate_stack(p: Curve, q: TwistedCurve) -> Vec<U256> {
//     let ptr = U256::from(300);
//     let out = U256::from(400);

//     let p_: Vec<U256> = p.into_iter().collect();
//     let q_: Vec<U256> = q.into_iter().flatten().collect();

//     let mut stack = vec![ptr];
//     stack.extend(p_);
//     stack.extend(q_);
//     stack.extend(vec![
//         ptr,
//         out,
//         get_address_from_label("return_fp12_on_stack"),
//         out,
//     ]);
//     stack
// }

// #[test]
// fn test_miller() -> Result<()> {
//     let p: Curve = curve_generator();
//     let q: TwistedCurve = twisted_curve_generator();

//     let stack = make_tate_stack(p, q);
//     let output = run_test_interpreter("test_miller", stack);
//     let expected = fp12_to_vec(miller_loop(p, q));

//     assert_eq!(output, expected);

//     Ok(())
// }

// #[test]
// fn test_tate() -> Result<()> {
//     let p: Curve = curve_generator();
//     let q: TwistedCurve = twisted_curve_generator();

//     let stack = make_tate_stack(p, q);
//     let output = run_test_interpreter("test_tate", stack);
//     let expected = fp12_to_vec(tate(p, q));

//     assert_eq!(output, expected);

//     Ok(())
// }
