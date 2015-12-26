open Pa_ocaml_prelude
open Decap
open Bindlib
open Util
open Ast
open Multi_print
open Eval
open Typing
open Trace
open Print_trace

#define LOCATE locate

(* Some combinators. *)
let list_sep elt sep = parser
  | EMPTY                        -> []
  | e:elt es:{_:STR(sep) e:elt}* -> e::es

let list_sep' elt sep = parser
  | e:elt es:{_:STR(sep) e:elt}* -> e::es

let parser string_char =
  | "\\\"" -> "\""
  | "\\\\" -> "\\"
  | "\\n"  -> "\n"
  | "\\t"  -> "\t"
  | c:ANY  -> if c = '\\' || c = '"' || c = '\r' then give_up "";
              String.make 1 c

let string_lit =
  let slit = parser "\"" cs:string_char* "\"" -> String.concat "" cs in
  change_layout slit no_blank

(* Keyword management. *)
let keywords = Hashtbl.create 20

let is_keyword : string -> bool = Hashtbl.mem keywords

let check_not_keyword : string -> unit = fun s ->
  if is_keyword s then
    give_up ("\""^s^"\" is a reserved identifier...")

let new_keyword : string -> unit grammar = fun s ->
  let ls = String.length s in
  if ls < 1 then
    raise (Invalid_argument "invalid keyword");
  if Hashtbl.mem keywords s then
    raise (Invalid_argument "keyword already defied");
  Hashtbl.add keywords s s;
  let f str pos =
    let str = ref str in
    let pos = ref pos in
    for i = 0 to ls - 1 do
      let (c,str',pos') = Input.read !str !pos in
      if c <> s.[i] then
        give_up ("The keyword "^s^" was expected...");
      str := str'; pos := pos'
    done;
    let (c,_,_) = Input.read !str !pos in
    match c with
    | 'a'..'z' | 'A'..'Z' | '0'..'9' | '_' | '\'' ->
        give_up ("The keyword "^s^" was expected...")
    | _                                           -> ((), !str, !pos)
  in
  black_box f (Charset.singleton s.[0]) None s

(* Parser level AST. *)
type pkind = pkind' position
and pkind' =
  | PFunc of pkind * pkind
  | PTVar of string * pkind list
  | PFAll of string * pkind
  | PExis of string * pkind
  | PMu   of string * pkind
  | PNu   of string * pkind
  | PProd of (string * pkind) list
  | PSum  of (string * pkind option) list
  | PHole

type pterm = pterm' position
and pterm' =
  | PLAbs of (strpos * pkind option) list * pterm
  | PCoer of pterm * pkind
  | PAppl of pterm * pterm
  | PLVar of string
  | PPrnt of string
  | PCstr of string * pterm option
  | PProj of pterm * string
  | PCase of pterm * (string * (strpos * pkind option) option * pterm) list
  | PReco of (string * pterm) list
  | PFixY of (strpos * pkind option) * pterm

(* t ; u => (fun (x : unit) -> u) t *)
let sequence pos t u =
     in_pos pos (
       PAppl(in_pos pos (
	 PLAbs([in_pos pos "_",Some (in_pos pos (
	   PProd []))] ,u)), t))

(* Basic tokens. *)
let case_kw = new_keyword "case"
let rec_kw  = new_keyword "rec"
let let_kw  = new_keyword "let"
let val_kw  = new_keyword "val"
let of_kw   = new_keyword "of"
let in_kw   = new_keyword "in"
let fix_kw  = new_keyword "fix"
let fun_kw  = new_keyword "fun"

let unfold_kw  = new_keyword "unfold"
let clear_kw   = new_keyword "clear"
let parse_kw   = new_keyword "parse"
let quit_kw    = new_keyword "quit"
let exit_kw    = new_keyword "exit"
let eval_kw    = new_keyword "eval"
let set_kw     = new_keyword "set"
let include_kw = new_keyword "include"
let check_kw   = new_keyword "check"
let latex_kw   = new_keyword "latex"

let parser arrow  : unit grammar = "→" | "->"
let parser forall : unit grammar = "∀" | "/\\"
let parser exists : unit grammar = "∃" | "\\/"
let parser mu     : unit grammar = "μ" | "!"
let parser nu     : unit grammar = "ν" | "?"
let parser lambda : unit grammar = "λ" | fun_kw
let parser dot    : unit grammar = "." | "->" | "→" | "↦"
let parser hole   : unit grammar = "?"

let parser ident = id:''[a-zA-Z][a-zA-Z0-9_']*'' -> check_not_keyword id; id
let parser lident = id:''[a-z][a-zA-Z0-9_']*'' -> check_not_keyword id; id
let parser uident = id:''[A-Z][a-zA-Z0-9_']*'' -> check_not_keyword id; id

(****************************************************************************
 *                         A parser for kinds (types)                       *
 ****************************************************************************)

type pkind_prio = KQuant | KFunc | KAtom

let parser kind p =
  | a:(kind KAtom) arrow b:(kind KFunc) when p = KFunc
      -> in_pos _loc (PFunc(a,b))
  | id:ident l:{"(" l:kind_list ")"}?[[]] when p = KAtom
      -> in_pos _loc (PTVar(id,l))
  | forall id:ident a:(kind KQuant) when p = KQuant
      -> in_pos _loc (PFAll(id,a))
  | exists id:ident a:(kind KQuant) when p = KQuant
      -> in_pos _loc (PExis(id,a))
  | mu id:ident a:(kind KQuant) when p = KQuant
      -> in_pos _loc (PMu(id,a))
  | nu id:ident a:(kind KQuant) when p = KQuant
      -> in_pos _loc (PNu(id,a))
  | "{" fs:prod_items "}" when p = KAtom
      -> in_pos _loc (PProd(fs))
  | "[" fs:sum_items "]" when p = KAtom
      -> in_pos _loc (PSum(fs))
  | hole when p = KAtom
      -> in_pos _loc PHole

  | "(" a:(kind KQuant) ")" when p = KAtom
  | a:(kind KAtom) when p = KFunc
  | a:(kind KFunc)  when p = KQuant

and kind_list  = l:(list_sep (kind KQuant) ",")
and sum_item   = id:ident a:{_:of_kw a:(kind KQuant)}?
and sum_items  = l:(list_sep sum_item "|")
and prod_item  = id:ident ":" a:(kind KQuant)
and prod_items = l:(list_sep prod_item ";")

let kind = kind KQuant

let parser kind_def =
  | id:ident args:{"(" ids:(list_sep' ident ",") ")"}?[[]] "=" k:kind


(****************************************************************************
 *                          A parser for expressions                        *
 ****************************************************************************)

type pterm_prio = TFunc | TColo | TAppl | TAtom

let parser var =
  | id:lident                    -> (in_pos _loc_id id, None)
  | "(" id:lident ":" k:kind ")" -> (in_pos _loc_id id, Some k)

let parser term p =
  | lambda xs:var+ dot t:(term TFunc) when p = TFunc ->
      in_pos _loc (PLAbs(xs,t))
  | t:(term TAppl) u:(term TAtom) when p = TAppl ->
      in_pos _loc (PAppl(t,u))
  | t:(term TAppl) ";" u:(term TColo) when p = TColo ->
     sequence _loc t u
  | "print(" - s:string_lit - ")" when p = TAtom ->
      in_pos _loc (PPrnt(s))
  | c:uident uo:(term TAtom)? when p = TAtom ->
      in_pos _loc (PCstr(c,uo))
  | t:(term TAtom) "." l:ident when p = TAtom ->
      in_pos _loc (PProj(t,l))
  | case_kw t:(term TFunc) of_kw "|"?
    ps:(list_sep pattern "|") when p = TFunc ->
      in_pos _loc (PCase(t,ps))
  | "{" fs:(list_sep field ";") ";"? "}" when p = TAtom ->
      in_pos _loc (PReco(fs))
  | t:(term TAtom) ":" k:kind when p = TAtom ->
      in_pos _loc (PCoer(t,k))
  | id:lident when p = TAtom ->
      in_pos _loc (PLVar(id))
  | fix_kw x:var dot u:(term TFunc) when p = TFunc ->
      in_pos _loc (PFixY(x,u))

  | "(" t:(term TFunc) ")" when p = TAtom
  | t:(term TAtom) when p = TAppl
  | t:(term TAppl) when p = TColo
  | t:(term TColo) when p = TFunc

and pattern  = c:uident x:var? _:arrow t:(term TFunc) -> (c, x, t)
and field    = l:ident "=" t:(term TFunc)

let term = term TFunc

(****************************************************************************
 *                           Desugaring functions                           *
 ****************************************************************************)

exception Unsugar_error of Location.t * string
let unsugar_error l s =
  raise (Unsugar_error (l,s))

let unsugar_kind : (string * kbox) list -> pkind -> kbox =
  fun env pk ->
  let rec unsugar env pk =
    match pk.elt with
    | PFunc(a,b) ->
        func (unsugar env a) (unsugar env b)
    | PTVar(s,ks) ->
        begin
          try
            let k = List.assoc s env in
            if ks <> [] then
              begin
                let msg = Printf.sprintf "%s does note expect arguments." s in
                unsugar_error pk.pos msg
              end
            else k
          with Not_found ->
            begin
              let ks = Array.of_list ks in
              try
                let ks = Array.map (unsugar env) ks in
                let td = Hashtbl.find typ_env s in
                if td.tdef_arity <> Array.length ks then
                  begin
                    let msg =
                      Printf.sprintf
                        "%s expect %i arguments but received %i." s
                        td.tdef_arity (Array.length ks)
                    in
                    unsugar_error pk.pos msg
                  end;
                tdef td ks
              with Not_found ->
                begin
                  let msg = Printf.sprintf "Unboud variable %s." s in
                  unsugar_error pk.pos msg
                end
            end
        end
    | PFAll(x,k) ->
       let f xk = unsugar ((x,box_of_var xk) :: env) k in
       fall x f
    | PExis(x,k) ->
       let f xk = unsugar ((x,box_of_var xk) :: env) k in
       exis x f
    | PMu(x,k) ->
       fixm x (fun xk -> unsugar ((x,box_of_var xk) :: env) k)
    | PNu(x,k) ->
       fixn x (fun xk -> unsugar ((x,box_of_var xk) :: env) k)
    | PProd(fs)  ->
       prod (List.map (fun (l,k) -> (l, unsugar env k)) fs)
    | PSum(cs)   ->
       dsum (List.map (fun (c,k) -> (c, unsugar_top env k)) cs)
    | PHole      -> box (new_uvar ())
  and unsugar_top env ko =
    match ko with
    | None   -> prod []
    | Some k -> unsugar env k
  in unsugar env pk

let unsugar_term : (string * tbox) list -> pterm ->
                   tbox * (string * (term variable * pos list)) list =
  fun env pt ->
  let unbound = ref [] in
  let rec unsugar env pt =
    match pt.elt with
    | PLAbs(vs,t) ->
        let rec aux env = function
          | (x,ko)::xs ->
              let ko =
                match ko with
                | None   -> None
                | Some k -> Some (unsugar_kind [] k)
              in
              let f xt = aux ((x.elt,xt)::env) xs in
              labs pt.pos ko x f
          | [] -> unsugar env t
        in
        aux env vs
    | PCoer(t,k) ->
        coer pt.pos (unsugar env t) (unsugar_kind [] k)
    | PAppl(t,u) ->
        appl pt.pos (unsugar env t) (unsugar env u)
    | PLVar(x) ->
        begin
          try List.assoc x env with Not_found ->
          try
            let vd = Hashtbl.find val_env x in
            vdef pt.pos vd
          with Not_found ->
            begin
              try
                let (v, ps) = List.assoc x !unbound in
                unbound := List.remove_assoc x !unbound;
                unbound := (x, (v, pt.pos :: ps)) :: !unbound;
                lvar pt.pos v
              with Not_found ->
                begin
                  let v = new_lvar' x in
                  unbound := (x, (v, [pt.pos])) :: !unbound;
                  lvar pt.pos v
                end
            end
        end
    | PPrnt(s) ->
        prnt pt.pos s
    | PCstr(c,uo) ->
        let u =
          match uo with
          | None   -> reco dummy_position []
          | Some u -> unsugar env u
        in
        cons pt.pos c u
    | PProj(t,l) ->
        proj pt.pos (unsugar env t) l
    | PCase(t,cs) ->
       let f (c,x,t) =
	 (c, unsugar env (match x with
	 | None   -> dummy_pos (PLAbs([dummy_pos "_", Some(dummy_pos (PProd([])))], t))
	 | Some x -> dummy_pos (PLAbs([x],t))))
        in
        case pt.pos (unsugar env t) (List.map f cs)
    | PReco(fs) ->
        reco pt.pos (List.map (fun (l,t) -> (l, unsugar env t)) fs)
    | PFixY((x,ko),t) ->
       let ko =
         match ko with
         | None   -> None
         | Some k -> Some (unsugar_kind [] k)
       in
       let f xt = unsugar ((x.elt,xt)::env) t in
       fixy pt.pos ko x f
  in
  let t = unsugar env pt in
  (t, !unbound)

(****************************************************************************
 *                      High level parsing functions                        *
 ****************************************************************************)

exception Finish

let top_level_blank = blank_regexp ''[ \t\n\r]*''

let comment_char = black_box
  (fun str pos ->
    let (c, str', pos') = Input.read str pos in
    match c with
    | '\255' -> give_up "Unclosed comment."
    | '*'    ->
        let (c', _, _) = Input.read str' pos' in
        if c' = ')' then
          give_up "Not the place to close a comment."
        else
          ((), str', pos')
    | _      -> ((), str', pos')
  ) Charset.full_charset None "ANY"

let comment = change_layout (parser "(*" _:comment_char** "*)") no_blank

let parser blank_parser = _:comment**

let file_blank = blank_grammar blank_parser top_level_blank

let parser enabled =
  | "on"  -> true
  | "off" -> false

let latex_ch = ref stdout

let open_latex fn =
  if !latex_ch <> stdout then close_out !latex_ch;
  latex_ch := open_out fn

let parser opt_flag =
  | "verbose" b:enabled -> verbose := b
  | "latex" b:enabled -> Multi_print.print_mode := if b then Latex else Ascii
  | "texfile" fn:string_lit -> open_latex fn
  | "print_term_in_subtyping" b:enabled -> Print.print_term_in_subtyping := b

let read_file = ref (fun _ -> assert false)

let parser latex_atom =
  | "#" "witnesses" "#"     -> Latex_trace.Witnesses
  | "#" u:"!"? k:kind "#" -> Latex_trace.Kind (u<>None, unbox (unsugar_kind [] k))
  | "@" u:"!"? t:term "@" -> Latex_trace.Term (u<>None, unbox (fst (unsugar_term [] t)))
  | t:''[^}{@#]+''        -> Latex_trace.Text t
  | l:latex_text          -> l
  | "#?" a:kind {"⊂" | "⊆" | "<"} b:kind "#" ->
     let a = unbox (unsugar_kind [] a) in
     let b = unbox (unsugar_kind [] b) in
     generic_subtype a b;
     let prf = collect_subtyping_proof () in
     Latex_trace.SProof prf
  | "#:" id:lident "#"    -> let t = Hashtbl.find val_env id in
			     Latex_trace.Kind (false, t.ttype)
  | "##" id:lident "#"    -> let t = Hashtbl.find val_env id in
			     Latex_trace.TProof t.proof


and latex_text = "{" l:latex_atom* "}" -> Latex_trace.List l

let parser latex_name_aux =
    | t:''[^{}]+''              -> Latex_trace.Text t
    | "{" l:latex_name_aux* "}" -> Latex_trace.List l

and latex_name = "{" t:latex_name_aux* "}" -> Latex_trace.to_string (Latex_trace.List t)

let parser command =
  (* Type definition command. *)
  | type_kw tex:latex_name? (name,args,k):kind_def ->
        let arg_names = Array.of_list args in
        let f args =
          let env = ref [] in
          Array.iteri (fun i k -> env := (arg_names.(i), k) :: !env) args;
          unsugar_kind !env k
        in
        let b = mbind mk_free_tvar arg_names f in
        let td =
          { tdef_name  = name
	  ; tdef_tex_name = (match tex with None -> "\\mathrm{"^name^"}" | Some s -> s)
          ; tdef_arity = Array.length arg_names
          ; tdef_value = unbox b }
        in
        Printf.fprintf stdout "%a\n%!" (print_kind_def false) td;
        Hashtbl.add typ_env name td
  (* Unfold a type definition. *)
  | unfold_kw k:kind ->
        let k = unbox (unsugar_kind [] k) in
        Printf.fprintf stdout "%a\n%!" (print_kind true) k
  (* Parse a term. *)
  | parse_kw t:term ->
        let (t, unbs) = unsugar_term [] t in
        let t = unbox t in
        Printf.fprintf stdout "%a\n%!" (print_term false) t
  (* Evaluate a term. *)
  | eval_kw t:term ->
        let (t, unbs) = unsugar_term [] t in
        let t = unbox t in
        let t = eval t in
        Printf.fprintf stdout "%a\n%!" (print_term false) t
  (* Typed value definition. *)
  | val_kw r:rec_kw? tex:latex_name? id:lident ":" k:kind "=" t:term ->
       let t =
	 if r = None then t
	 else in_pos _loc_t (PFixY((in_pos _loc_id id, Some k), t)) in
       let (t, unbs) = unsugar_term [] t in
        if unbs <> [] then
          begin
            List.iter (fun (s,_) -> Printf.eprintf "Unbound: %s\n%!" s) unbs;
            failwith "Unbound variable."
          end;
        let t = unbox t in
        let k = unbox (unsugar_kind [] k) in
        let prf =
	  try
	    type_check t k;
	    let prf = collect_typing_proof () in
	    if !verbose then print_typing_proof prf;
	    prf
	  with
	    e -> trace_backtrace (); raise e
	in
        reset_all ();
        let t = eval t in
        Hashtbl.add val_env id
	  { name = id
	  ; tex_name = (match tex with None -> "\\mathrm{"^id^"}" | Some s -> s)
	  ; value = t
	  ; ttype = k
	  ; proof = prf
	  };
        Printf.fprintf stdout "%s : %a\n%!" id (print_kind false) k
  (* Check subtyping. *)
  | check_kw n:{"not" -> false}?[true] a:kind {"⊂" | "⊆" | "<"} b:kind ->
        let a = unbox (unsugar_kind [] a) in
        let b = unbox (unsugar_kind [] b) in
        begin
          try
	    generic_subtype a b;
	    let prf = collect_subtyping_proof () in
	    if !verbose || not n then (
	      Printf.eprintf "MUST FAIL\n%!";
	      print_subtyping_proof prf;
	      exit 1
	    );
	    reset_ordinals ();
	    Printf.eprintf "check: OK\n%!"
          with
          | Subtype_error s when n ->
	     Printf.eprintf "CHECK FAILED: OK %s\n%!" s;
	    trace_backtrace ();
	    exit 1;
          | Subtype_error s ->
	     Printf.eprintf "check not: OK %s\n%!" s;
	     trace_state := [];
 	     reset_ordinals ();
          | e ->
	     Printf.eprintf "UNCAUGHT EXCEPTION: %s\n%!" (Printexc.to_string e);
	     trace_backtrace ();
	     exit 1;

        end
  | latex_kw t:latex_text ->
     Latex_trace.output !latex_ch t
  (* Include a file. *)
  | _:include_kw fn:string_lit ->
      !read_file fn
  (* Set a flag. *)
  | _:set_kw f:opt_flag

let parser toplevel =
  (* Regular commands. *)
  | command
  (* Clear the screen. *)
  | clear_kw ->
      ignore (Sys.command "clear")
  (* Exit the program. *)
  | {quit_kw | exit_kw} ->
      raise Finish

let toplevel_of_string : string -> unit = fun s ->
  let parse = parse_string toplevel top_level_blank in
  Decap.handle_exception parse s

let parser file_contents =
  | cs:command** -> ()

let eval_file fn =
  Printf.printf "## Loading file %S\n%!" fn;
  let parse = parse_file file_contents file_blank in
  Decap.handle_exception parse fn;
  Printf.printf "## file Loaded %S\n%!" fn

let _ = read_file := eval_file
