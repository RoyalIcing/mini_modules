// use std::fmt;

use deno_core;
use deno_core::v8::Handle;
use deno_core::JsRuntime;

extern crate swc_common;
extern crate swc_ecma_parser;
use swc_common::sync::Lrc;
use swc_common::{
    // errors::{ColorConfig, Handler},
    FileName,
    SourceMap,
};
use swc_ecma_parser::{lexer::Lexer, Parser, StringInput, Syntax};

use rustler::{Encoder, Env, Term};
mod atoms {
    rustler::atoms! {
        // html5ever_nif_result,

        ok,
        error,
        nif_panic,
    }
}

#[rustler::nif]
fn add(a: i64, b: i64) -> i64 {
    a + b
}

#[rustler::nif(schedule = "DirtyCpu")]
fn js(source: String) -> String {
    // let mut isolate = CoreIsolate::new(StartupData::None, false);
    // let ret = isolate.execute("<anon>", source);
    // return ret;
    let mut runtime = JsRuntime::new(Default::default());
    // let isolate = runtime.v8_isolate();
    let global = runtime.execute_script("<usage>", &source).unwrap();
    unsafe {
        let value = global.get_unchecked();
        let mut handle_scope = runtime.handle_scope();
        let s = value.to_rust_string_lossy(&mut handle_scope);

        return s;
    }
}

fn parse_js_result(source: String) -> Result<String, String> {
    let cm: Lrc<SourceMap> = Default::default();

    // Real usage
    // let fm = cm
    //     .load_file(Path::new("test.js"))
    //     .expect("failed to load test.js");
    let fm = cm.new_source_file(FileName::Custom("test.js".into()), source.into());
    let lexer = Lexer::new(
        // We want to parse ecmascript
        Syntax::Es(Default::default()),
        // EsVersion defaults to es5
        Default::default(),
        StringInput::from(&*fm),
        None,
    );

    let mut parser = Parser::new_from(lexer);

    // let handler = Handler::with_tty_emitter(ColorConfig::Auto, true, false, Some(cm.clone()));
    /*for e in parser.take_errors() {
        e.into_diagnostic(&handler).emit();
    }*/

    // let module = parser.parse_module().map_err(|e| {
    //     return format!("{:?}", e);
    //     // Unrecoverable fatal error occurred
    //     //e.into_diagnostic(&handler).emit()
    // });
    return parser
        .parse_module()
        .map_err(|e| {
            return format!("{:?}", e);
        })
        .and_then(|module| {
            serde_json::to_string(&module).map_err(|e| {
                return e.to_string();
            })
        });
    // .expect("failed to parser module");

    // let j = serde_json::to_string(&module).map_err(|e| {
    //     return e.to_string();
    // });
    // return j;
}

// #[rustler::nif(schedule = "DirtyCpu")]
// fn parse_js<'a>(env: Env<'a>, source: String) -> Term<'a> {
//     let result = parse_js_result(source);
//     return match result {
//         Ok(v) => (atoms::ok(), v).encode(env),
//         Err(e) => (atoms::error(), e).encode(env),
//     };
// }
#[rustler::nif(schedule = "DirtyCpu")]
fn parse_js(source: String) -> Result<String, String> {
    return parse_js_result(source);
}

rustler::init!("Elixir.Molten", [add, js, parse_js]);
