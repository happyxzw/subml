open Ast

type sub_proof =
  { sterm : term;
    left : kind;
    right : kind;
    mutable strees : sub_proof list }

type typ_proof =
  { tterm : term;
    typ : kind;
    mutable strees : sub_proof list;
    mutable ttrees : typ_proof list;
  }

type trace_state =
  | Typing of typ_proof
  | SubTyping of sub_proof
  | EndTyping of typ_proof
  | EndSubTyping of sub_proof

let trace_state = ref []

let trace_typing t k =
  let prf = {
    tterm = t;
    typ = k;
    strees = [];
    ttrees = [];
  } in
  match !trace_state with
  | Typing (p)::_ as l ->
     p.ttrees <- prf :: p.ttrees;
     trace_state := Typing prf :: l
  | [] ->
     trace_state := Typing prf :: []
  | _ -> assert false

let trace_subtyping t k1 k2 =
  let prf = {
    sterm = t;
    left = k1;
    right = k2;
    strees = [];
  } in
  match !trace_state with
  | Typing (p)::_ as l ->
     p.strees <- prf :: p.strees;
     trace_state := SubTyping prf :: l
  | SubTyping (p)::_ as l ->
     p.strees <- prf :: p.strees;
     trace_state := SubTyping prf :: l
  | _ -> assert false

let trace_pop () =
  match !trace_state with
  | [Typing prf] -> trace_state := [EndTyping prf]
  | [SubTyping prf] -> trace_state := [EndSubTyping prf]
  | _::s -> trace_state := s
  | [] -> assert false

let collect_typing_proof () =
  match !trace_state with
  | [EndTyping prf] -> trace_state := []; prf
  | _ -> assert false

let collect_subtyping_proof () =
  match !trace_state with
  | [EndSubTyping prf] -> trace_state := [] ; prf
  | _ -> assert false

(*
    if verbose then
      Printf.eprintf "Sub: %a ∈ %a ⊆ %a\n%!"
        print_term t (print_kind false) a (print_kind false) b;
    try
    if verbose then
      Printf.fprintf stderr "Typ: %a : %a\n%!"
        print_term t (print_kind false) c;
*)
