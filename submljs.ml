open Format
open Bindlib
open Util
open Ast
open Print
open Parser
open Raw
open Decap
open Typing
open Io

let _ = handle_stop true

let quit    = ref false
let prelude = ref true
let files   = ref ([] : string list)

let add_file fn = files := !files @ [fn]

let treat_exception fn a =
  let position2 ff (fname, lnum, cnum) =
    fprintf ff "File %S, line %d, characters %d-%d" fname lnum cnum cnum
  in
  try
    fn a; true
  with
  | End_of_file          -> true
  | Finish               -> true
  | Stopped              -> io.stderr "Stopped\n%!"; true
  | Unsugar_error(loc,msg)
                         -> io.stderr "%a:\n%s\n%!" print_position loc msg; false
  | Parse_error(fname,lnum,cnum,_,_)
                         -> io.stderr "%a:\nSyntax error\n%!" position2 (fname, lnum, cnum); false
  | Unbound(loc,s)       -> io.stderr "%a:\nUnbound: %s\n%!" print_position loc s; false
  | Type_error(loc, msg)
                         -> io.stderr "%a:\nType error: %s\n%!" print_position loc msg; false
  | e                    -> io.stderr "Uncaught fucking exception %s\n%!" (Printexc.to_string e); false

let js_object = Js.Unsafe.variable "Object"
let postMessage = Js.Unsafe.variable "postMessage"
let syncloadsubmlfile = Js.Unsafe.variable "syncloadsubmlfile"

let onmessage event =
  let filename = Js.to_string event##data##fname in
  let s = Js.to_string event##data##args in
  let b = treat_exception (parse_string ~filename file_contents blank) s in
  io.log "Editor content loaded\n%!";
  let result = if b then Js.string "OK" else Js.string "ERROR" in
  let response = jsnew js_object () in
  Js.Unsafe.set response (Js.string "typ") (Js.string "result");
  Js.Unsafe.set response (Js.string "fname") filename;
  Js.Unsafe.set response (Js.string "result") result;
  Js.Unsafe.call postMessage (Js.Unsafe.variable "self") [|Js.Unsafe.inject response|]

let _ = Js.Unsafe.set (Js.Unsafe.variable "self") (Js.string "onmessage") onmessage

let buf = Buffer.create 256
let fbuf = formatter_of_buffer buf

let output = fun chname format ->
  Buffer.clear buf;
  kfprintf (fun _fbuf ->
    let s = Js.string (Buffer.contents buf) in
    let response = jsnew js_object () in
    Js.Unsafe.set response (Js.string "typ") (Js.string chname);
    Js.Unsafe.set response (Js.string "result") s;
    ignore (Js.Unsafe.call postMessage (Js.Unsafe.variable "self") [|Js.Unsafe.inject response|]);
    Buffer.clear buf) fbuf format

let _ = io.stdout <- (fun format -> output "stdout" format)
let _ = io.log    <- (fun format -> output "log"    format)
let _ = io.stderr <- (fun format -> output "stderr" format)

let _ = io.files  <- (fun filename  ->
  let args = [|Js.Unsafe.inject (Js.string filename)|] in
  let res = Js.Unsafe.fun_call  syncloadsubmlfile args in
  let s = Js.to_string res in
  Input.buffer_from_string ~filename s)

let _ =
  let s = io.files "lib/prelude.typ" in
  ignore (treat_exception (parse_buffer file_contents blank) s);
  io.log "File \"lib/prelude.typ\" loaded\n%!"
