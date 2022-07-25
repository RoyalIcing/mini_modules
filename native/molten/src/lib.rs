use deno_core;
use deno_core::JsRuntime;
use deno_core::v8::Handle;
// use deno_core::ModuleLoader;
// use std::str;
// use deno_core::Op;
// use deno_core::ZeroCopyBuf;
// use deno_core::{CoreIsolate, StartupData};

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

rustler::init!("Elixir.Molten", [add, js]);
