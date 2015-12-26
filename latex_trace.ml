open Ast
open Print
open Latex
open Trace

type latex_output =
  | Kind of (bool * kind)
  | Term of (bool * term)
  | Text of string
  | List of latex_output list
  | SProof of sub_proof
  | TProof of typ_proof

let rec to_string = function
  | Text t -> t
  | List(l) -> "{" ^ String.concat "" (List.map to_string l) ^"}"
  | _ -> assert false

let print_rule_name ff rn =
  let open Printf in
  match rn with
  | NInd n -> fprintf ff "I_{%d}" n
  | NUseInd n -> fprintf ff "H_{%d}" n
  | NRefl -> fprintf ff "="
  | NArrow -> fprintf ff "\\to"
  | NSum -> fprintf ff "+"
  | NProd -> fprintf ff "\\times"
  | NAllLeft -> fprintf ff "\\forall_l"
  | NAllRight -> fprintf ff "\\forall_r"
  | NExistsLeft -> fprintf ff "\\exists_l"
  | NExistsRight -> fprintf ff "\\exists_r"
  | NMuLeft -> fprintf ff "\\mu_l"
  | NMuRight -> fprintf ff "\\mu_r"
  | NNuLeft -> fprintf ff "\\nu_l"
  | NNuRight -> fprintf ff "\\nu_r"
  | NUnknown -> fprintf ff "?"

let print_subtyping_proof, print_typing_proof =
  let rec fn ch (p:sub_proof) =
    let rn, strees = Print_trace.filter_rule p in
    List.iter (fn ch) strees;
    let cmd = match List.length strees with
      | 0 -> "\\AxiomC{}\n\\UnaryInfC"
      | 1 -> "\\UnaryInfC"
      | 2 -> "\\BinaryInfC"
      | 3 -> "\\TernaryInfC"
      | _ -> assert false
    in
    Printf.fprintf ch "\\RightLabel{$%a$}%s{$%a \\subset %a$}\n%!" print_rule_name rn cmd
      (print_kind false) p.left (print_kind false) p.right
            (*Printf.fprintf ch "%s{$%a \\in %a \\subset %a$}\n%!" cmd
	      (print_term false) p.sterm (print_kind false) p.left (print_kind false) p.right*)

  and gn ch (p:typ_proof) =
    let subs =
      (*List.filter (fun p -> not (lower_kind p.left p.right))*) p.strees
    in
    let cmd = match List.length subs + List.length p.ttrees with
      | 0 -> "\\AxiomC{}\n\\UnaryInfC"
      | 1 -> "\\UnaryInfC"
      | 2 -> "\\BinaryInfC"
      | 3 -> "\\TernaryInfC"
      | _ -> assert false
    in
    List.iter (fn ch) subs;
    List.iter (gn ch) p.ttrees;
    Printf.fprintf ch "%s{$%a : %a$}\n%!" cmd
      (print_term false) p.tterm (print_kind false) p.typ
  in
  (fun ch p -> fn ch p),
  (fun ch p -> gn ch p)

let rec output ch = function
  | Kind(unfold,k) -> print_kind unfold ch k
  | Term(unfold,t) -> print_term unfold ch t
  | Text(t)        -> Printf.fprintf ch "%s" t
  | List(l)        -> Printf.fprintf ch "{%a}" (fun ch -> List.iter (output ch)) l
  | SProof p       -> print_subtyping_proof ch p
  | TProof p       -> print_typing_proof ch p
