open Bindlib
open Format
open Ast
open Position
open Compare

let rec print_list pelem sep ff = function
  | []    -> ()
  | [e]   -> pelem ff e
  | e::es -> fprintf ff "%a%s%a" pelem e sep (print_list pelem sep) es

let rec print_array pelem sep ff ls =
  print_list pelem sep ff (Array.to_list ls)

let is_tuple ls =
  let n = List.length ls in
  try
    for i = 1 to n do
      if not (List.mem_assoc (string_of_int i) ls) then raise Exit;
    done;
    true
  with
    Exit -> false

(* managment of a table to name ordinals and epsilon when printing *)
let ordinal_count = ref 0
let ordinal_tbl = ref []
let epsilon_term_tbl = ref[]
let epsilon_type_tbl = ref[]

let reset_epsilon_tbls () =
  ordinal_count := 0;
  ordinal_tbl := [];
  epsilon_term_tbl := [];
  epsilon_type_tbl := []

let search_type_tbl u f is_exists =
  try
    (* use the fact that f is liskely to be enough as a key.
       this is just for printing after all … *)
    let (name,index,_,_) = assoc_kkind f !epsilon_type_tbl in
    (name, index)
  with not_found ->
    let base = binder_name f in
    let fn acc (_,(base',i,u,is_exists)) =
      if base = base' then max acc i else acc
    in
    let max = List.fold_left fn (-1) !epsilon_type_tbl
    in
    let index = max + 1 in
    epsilon_type_tbl := (f,(base,index,u,is_exists)) :: !epsilon_type_tbl;
    (base, index)

let search_term_tbl f a b =
  try
    let (name,index,_,_) = assoc_tterm f !epsilon_term_tbl in
    (name, index)
  with not_found ->
    let base = binder_name f in
    let fn acc (_,(base',i,_,_)) =
      if base = base' then max acc i else acc
    in
    let max = List.fold_left fn (-1) !epsilon_term_tbl in
    let index = max + 1 in
    epsilon_term_tbl := (f,(base,index,a,b)) :: !epsilon_term_tbl;
    (base, index)

let search_ordinal_tbl o =
  try
    assoc_ordinal o !ordinal_tbl
  with
    Not_found ->
      let n = !ordinal_count in incr ordinal_count;
      ordinal_tbl := (o,n)::!ordinal_tbl;
      n

let rec full_iter fn ptr =
  let rec gn old nouv = function
    | l when l == old ->
       if !ptr != nouv then gn nouv !ptr !ptr else ()
    | x::l -> fn x; gn old nouv l
    | [] -> assert false
  in
  gn [] !ptr !ptr


(****************************************************************************
 *                           Printing of a type                             *
 ****************************************************************************)

let rec print_ordinal unfold ff o =
  let o = orepr o in
  match o with
  | OConv   -> pp_print_string ff "∞"
  | _       ->
    let n = search_ordinal_tbl o in
    match orepr o with
    | OLess(o,w) as o0 when unfold ->
       begin
         match w with
         | In(t,a) -> (* TODO: print the int *)
            fprintf ff "ϵ(<%a,%a∈%a)" (print_ordinal false) o
              (print_term false) t (print_kind false false) (subst a o0)
         | NotIn(t,a) ->  (* TODO: print the int *)
            fprintf ff "ϵ(<%a,%a∉%a)" (print_ordinal false) o
              (print_term false) t (print_kind false false) (subst a o0)
         | Gen(t,r,f) -> (* FIXME *)
            let os = Array.init (mbinder_arity f)
              (fun i -> free_of (new_ovari ("o_"^string_of_int i))) in
            let (k1,k2) = msubst f os in
            fprintf ff "ϵ(%a,%a)" (print_kind false false) k1 (print_kind false false) k2
       end
    | OLess(o,_) -> fprintf ff "κ%d" n
    | OSucc(o) ->
       fprintf ff "s(%a)" (print_ordinal false) o
    | OVari(x) -> fprintf ff "%s" (name_of x)
    | OConv -> fprintf ff "∞"
    | OUVar(u,os) ->
       let print_upper ff = function
         | (_,None) -> ()
         | (_,Some o) -> fprintf ff "<%a" (print_ordinal false) (msubst o os)
       in
       let print_lower ff = function
         | (None,_) -> ()
         | (Some o,_) -> fprintf ff "%a≤" (print_ordinal false) (msubst o os)
       in
       if os = [||] then
         fprintf ff "%a?%i%a" print_lower u.uvar_state u.uvar_key print_upper u.uvar_state
       else
         fprintf ff "%a?%i(%a)%a" print_lower u.uvar_state u.uvar_key
           (print_list print_index_ordinal ", ") (Array.to_list os)
           print_upper u.uvar_state

and print_index_ordinal ff = function
  | OConv -> fprintf ff "∞"
  | o -> fprintf ff "%a" (print_ordinal false) o

and print_kind unfold wrap ff t =
  let pkind = print_kind unfold false in
  let pordi = print_ordinal unfold in
  let pkindw = print_kind unfold true in
  let t = if unfold then repr t else !ftry_fold_def (repr t) in
  match t with
  | KVari(x) ->
      pp_print_string ff (name_of x)
  | KFunc(a,b) ->
     if wrap then pp_print_string ff "(";
     fprintf ff "%a → %a" pkindw a pkind b;
     if wrap then pp_print_string ff ")"
  | KProd(fs) ->
     if is_tuple fs && List.length fs > 0 then begin
       if wrap then pp_print_string ff "(";
       for i = 1 to List.length fs do
         if i >= 2 then fprintf ff " × ";
         fprintf ff "%a" pkindw (List.assoc (string_of_int i) fs)
       done;
       if wrap then pp_print_string ff ")"
     end else begin
       let pfield ff (l,a) = fprintf ff "%s : %a" l pkind a in
       fprintf ff "{%a}" (print_list pfield "; ") fs
     end
  | KDSum(cs) ->
      let pvariant ff (c,a) =
        if a = KProd [] then pp_print_string ff c
        else fprintf ff "%s of %a" c pkind a
      in
      fprintf ff "[%a]" (print_list pvariant " | ") cs
  | KKAll(f)  ->
      let x = new_kvari (binder_name f) in
      fprintf ff "∀%s %a" (name_of x) pkind (subst f (free_of x))
  | KKExi(f)  ->
      let x = new_kvari (binder_name f) in
      fprintf ff "∃%s %a" (name_of x) pkind (subst f (free_of x))
  | KOAll(f)  ->
      let x = new_ovari (binder_name f) in
      fprintf ff "∀%s %a" (name_of x) pkind (subst f (free_of x))
  | KOExi(f)  ->
      let x = new_ovari (binder_name f) in
      fprintf ff "∃%s %a" (name_of x) pkind (subst f (free_of x))
  | KFixM(o,b) ->
      let x = new_kvari (binder_name b) in
      let a = subst b (free_of x) in
      fprintf ff "μ%a%s %a" print_index_ordinal o (name_of x) pkindw a
  | KFixN(o,b) ->
      let x = new_kvari (binder_name b) in
      let a = subst b (free_of x) in
      fprintf ff "ν%a%s %a" print_index_ordinal o (name_of x) pkindw a
  | KDefi(td,os,ks) ->
      if unfold then
        print_kind unfold wrap ff (msubst (msubst td.tdef_value os) ks)
      else if Array.length ks = 0 && Array.length os = 0 then
        pp_print_string ff td.tdef_name
      else if Array.length os = 0 then
        fprintf ff "%s(%a)" td.tdef_name (print_array pkind ", ") ks
      else if Array.length ks = 0 then
        fprintf ff "%s(%a)" td.tdef_name (print_array pordi ", ") os
      else
        fprintf ff "%s(%a, %a)" td.tdef_name (print_array pordi ", ") os
          (print_array pkind ", ") ks
  | KUCst(u,f,_)
  | KECst(u,f,_) ->
     let is_exists = match t with KECst(_) -> true | _ -> false in
     let name, index =search_type_tbl u f is_exists in
     fprintf ff "%s_%d" name index
  | KUVar(u,os) ->
     if os = [||] then
       fprintf ff "?%i" u.uvar_key
     else
       fprintf ff "?%i(%a)" u.uvar_key
         (print_list print_index_ordinal ", ") (Array.to_list os)
  | KMRec(p,a) -> fprintf ff "%a && {%a}" pkind a
     (print_list (fun ff o -> pordi ff o) ", ") (Subset.unsafe_get p)
  | KNRec(p,a) -> fprintf ff "%a || {%a}" pkind a
     (print_list (fun ff o -> pordi ff o) ", ") (Subset.unsafe_get p)

(*
and print_state ff s os = match !s with
  | Free -> ()
  | Prod(fs) ->
     if is_tuple fs && List.length fs > 0 then begin
       pp_print_string ff "(";
       for i = 1 to List.length fs do
         if i >= 2 then fprintf ff " × ";
         fprintf ff "%a" (print_kind false true) (List.assoc (string_of_int i) fs)
       done;
       pp_print_string ff ")"
     end else begin
       let pfield ff (l,a) = fprintf ff "%s : %a" l (print_kind false true) a in
       fprintf ff "{%a}" (print_list pfield "; ") fs
     end
  | Sum(cs) ->
      let pvariant ff (c,a) =
        if a = KProd [] then pp_print_string ff c
        else fprintf ff "%s of %a" c (print_kind false true) a
      in
      fprintf ff "[%a]" (print_list pvariant " | ") cs
*)
and print_occur ff = function
  | All    -> pp_print_string ff "?"
  | Pos    -> pp_print_string ff "+"
  | Neg    -> pp_print_string ff "-"
  | Non    -> pp_print_string ff "="
  | Reg(_) -> pp_print_string ff "R"

and pkind_def unfold ff kd =
  fprintf ff "type %s" kd.tdef_name;
  let pkind = print_kind unfold false in
  let onames = mbinder_names kd.tdef_value in
  let os = new_mvar mk_free_ovari onames in
  let k = msubst kd.tdef_value (Array.map free_of os) in
  let knames = mbinder_names k in
  let ks = new_mvar mk_free_kvari knames in
  let k = msubst k (Array.map free_of ks) in
  assert(Array.length knames = Array.length kd.tdef_kvariance);
  assert(Array.length onames = Array.length kd.tdef_ovariance);
  let onames = Array.mapi (fun i n -> (n, kd.tdef_ovariance.(i))) onames in
  let knames = Array.mapi (fun i n -> (n, kd.tdef_kvariance.(i))) knames in
  let print_elt ff (n,v) = fprintf ff "%s%a" n print_occur v in
  let parray = print_array print_elt "," in
  if Array.length knames = 0 && Array.length onames = 0 then
    fprintf ff " = %a" pkind k
  else if Array.length onames = 0 then
    fprintf ff "(%a) = %a" parray knames pkind k
  else if Array.length knames = 0 then
    fprintf ff "(%a) = %a" parray onames pkind k
  else
    fprintf ff "(%a,%a) = %a" parray onames parray knames pkind k

(****************************************************************************
 *                           Printing of a term                             *
 ****************************************************************************)
 and position ff pos =
  let open Position in
  fprintf ff "File %S, line %d, characters %d-%d"
    pos.filename pos.line_start pos.col_start pos.col_end

and print_term ?(in_proj=false) unfold ff t =
  let print_term = print_term unfold in
  let pkind = print_kind false false in
  let not_def t = match t.elt with TDefi _ -> false | _ -> true in
  if not in_proj && not unfold && t.pos <> dummy_position && not_def t then
    fprintf ff "[%a]" position t.pos
  else match t.elt with
  | TCoer(t,a) ->
      fprintf ff "(%a : %a)" print_term t pkind a
  | TVari(x) ->
      pp_print_string ff (name_of x)
  | TAbst(ao,b) ->
      let x = binder_name b in
      let t = subst b (free_of (new_tvari x)) in
      begin
        match ao with
        | None   -> fprintf ff "λ%s %a" x print_term t
        | Some a -> fprintf ff "λ(%s : %a) %a" x pkind a print_term t
      end
  | TKAbs(f) ->
     let x = binder_name f in
     let t = subst f (free_of (new_kvari (binder_name f))) in
     fprintf ff "Λ%s %a" x print_term t
  | TOAbs(f) ->
     let x = binder_name f in
     let t = subst f (free_of (new_ovari (binder_name f))) in
     fprintf ff "Λ%s %a" x print_term t
  | TAppl(t,u) ->
      fprintf ff "(%a) %a" print_term t print_term u
  | TReco(fs) ->
      let pfield ff (l,t) = fprintf ff "%s = %a" l print_term t in
      fprintf ff "{%a}" (print_list pfield "; ") fs
  | TProj(t,l) ->
      fprintf ff "%a.%s" print_term t l
  | TCons(c,t) ->
     (match t.elt with
     | TReco([]) -> fprintf ff "%s" c
     | _         -> fprintf ff "%s %a" c print_term t)
  | TCase(t,l,d) ->
     let pvariant ff (c,b) =
       match b.elt with
       | TAbst(_,f) ->
           let x = binder_name f in
           let t = subst f (free_of (new_tvari x)) in
           fprintf ff "| %s[%s] → %a" c x print_term t
       | _          ->
           fprintf ff "| %s → %a" c print_term b
     in
     let pdefault ff = function
       | None -> ()
       | Some({elt = TAbst(_,f)}) ->
           let x = binder_name f in
           let t = subst f (free_of (new_tvari x)) in
           fprintf ff "| %s → %a" x print_term t
       | Some b           ->
          fprintf ff "| _ → %a" print_term b (* FIXME: assert false ? *)
     in
     fprintf ff "case %a of %a%a" print_term t (print_list pvariant "; ") l pdefault d
  | TDefi(v) ->
     if unfold then
       print_term ff v.orig_value
     else
       pp_print_string ff v.name
  | TPrnt(s) ->
      fprintf ff "print(%S)" s
  | TFixY(_,_,f) ->
      let x = binder_name f in
      let t = subst f (free_of (new_tvari x)) in
      fprintf ff "fix %s → %a" x print_term t
  | TCnst(f,a,b,_) ->
     let name, index = search_term_tbl f a b in
     fprintf ff "%s_%d" name index

(****************************************************************************
 *                             Proof generation                             *
 ****************************************************************************)

let term_to_string unfold t =
  print_term unfold str_formatter t;
  flush_str_formatter ()

let kind_to_string unfold k =
  print_kind unfold false str_formatter k;
  flush_str_formatter ()

let rec typ2proof : typ_prf -> string Proof.proof = fun (t,k,r) ->
  let open Proof in
  let t2s = term_to_string true and k2s = kind_to_string false in
  let c = sprintf "%s : %s" (t2s t) (k2s k) in
  match r with
  | Typ_Coer(p1,p2)   -> binaryN "⊆" c (sub2proof p1) (typ2proof p2)
  | Typ_KAbs(p)       -> unaryN "Λ" c (typ2proof p)
  | Typ_OAbs(p)       -> unaryN "Λo" c (typ2proof p)
  | Typ_Defi(p)       -> hyp ""
  | Typ_Prnt(p)       -> unaryN "print" c (sub2proof p)
  | Typ_Cnst(p)       -> unaryN "=" c (sub2proof p)
  | Typ_Func_i(p1,p2) -> binaryN "→i" c (sub2proof p1) (typ2proof p2)
  | Typ_Func_e(p1,p2) -> binaryN "→e" c (typ2proof p1) (typ2proof p2)
  | Typ_Prod_i(p,ps)  -> n_aryN "×i" c (sub2proof p :: List.map typ2proof ps)
  | Typ_Prod_e(p)     -> unaryN "×e" c (typ2proof p)
  | Typ_DSum_i(p1,p2) -> binaryN "+i" c (sub2proof p1) (typ2proof p2)
  | Typ_DSum_e(p,ps,_)-> n_aryN "+e" c (typ2proof p :: List.map typ2proof ps) (* FIXME *)
  | Typ_YH(n,p)       ->
     let name = sprintf "$H_%s$" (Sct.strInd n) in
     unaryN name c (sub2proof p)
  | Typ_TFix{contents=(n,p)}     ->
     (* TODO: proof may be duplicated, print with sharing*)
     let name = sprintf "$I_%s$" (Sct.strInd n) in
     unaryN name c (typ2proof p)
  | Typ_Hole          -> axiomN "AXIOM" c
  | Typ_Error msg     -> axiomN (sprintf "ERROR(%s)" msg) c

and     sub2proof : sub_prf -> string Proof.proof = fun (t,a,b,ir,r) ->
  let open Proof in
  let t2s = term_to_string true and k2s = kind_to_string false in
  let c = sprintf "%s ∈ %s ⊆ %s" (t2s t) (k2s a) (k2s b) in
  match r with
  | Sub_Delay(pr)     -> sub2proof !pr
  | Sub_Lower         -> axiomN "=" c
  | Sub_Func(p1,p2)   -> binaryN "→" c (sub2proof p1) (sub2proof p2)
  | Sub_Prod(ps)      -> n_aryN "χ" c (List.map (fun (l,p) -> sub2proof p) ps)
  | Sub_DSum(ps)      -> n_aryN "+" c (List.map (fun (l,p) -> sub2proof p) ps)
  | Sub_DPrj_l(p1,p2) -> binaryN "πl" c (typ2proof p1) (sub2proof p2)
  | Sub_DPrj_r(p1,p2) -> binaryN "πr" c (typ2proof p1) (sub2proof p2)
  | Sub_With_l(p)     -> unaryN "wl" c (sub2proof p)
  | Sub_With_r(p)     -> unaryN "wr" c (sub2proof p)
  | Sub_KAll_r(p)     -> unaryN "∀r" c (sub2proof p)
  | Sub_KAll_l(p)     -> unaryN "∀l" c (sub2proof p)
  | Sub_KExi_l(p)     -> unaryN "∃l" c (sub2proof p)
  | Sub_KExi_r(p)     -> unaryN "∃r" c (sub2proof p)
  | Sub_OAll_r(p)     -> unaryN "∀or" c (sub2proof p)
  | Sub_OAll_l(p)     -> unaryN "∀ol" c (sub2proof p)
  | Sub_OExi_l(p)     -> unaryN "∃ol" c (sub2proof p)
  | Sub_OExi_r(p)     -> unaryN "∃or" c (sub2proof p)
  | Sub_FixM_r(p)     -> unaryN "μr" c (sub2proof p)
  | Sub_FixN_l(p)     -> unaryN "νl" c (sub2proof p)
  | Sub_FixM_l(p)     -> unaryN "μl" c (sub2proof p)
  | Sub_FixN_r(p)     -> unaryN "νr" c (sub2proof p)
  | Sub_And_l(p)      -> unaryN "∧l" c (sub2proof p)
  | Sub_And_r(p)      -> unaryN "∧r" c (sub2proof p)
  | Sub_Or_l(p)       -> unaryN "∨l" c (sub2proof p)
  | Sub_Or_r(p)       -> unaryN "∨r" c (sub2proof p)
  | Sub_Ind(n)        -> axiomN (sprintf "$H_%s$" (Sct.strInd n)) c
  | Sub_Error(msg)    -> axiomN (sprintf "ERROR(%s)" msg) c

let print_typing_proof    ch p = Proof.output ch (typ2proof p)
let print_subtyping_proof ch p = Proof.output ch (sub2proof p)


(****************************************************************************
 *                          Interface functions                             *
 ****************************************************************************)

let print_term unfold ff t =
  print_term unfold ff t; pp_print_flush ff ()

let print_kind unfold ff t =
  print_kind unfold false ff t; pp_print_flush ff ()

let _ = fprint_kind := print_kind; fprint_term := print_term

let print_kind_def unfold ff kd =
  pkind_def unfold ff kd; pp_print_flush ff ()

let print_ordinal unfold ff o =
  print_ordinal unfold ff o; pp_print_flush ff ()

let print_position ff o =
  position ff o; pp_print_flush ff ()

let print_epsilon_tbls ff =
  full_iter (fun (f,(name,index,a,b)) ->
    let x = new_tvari (binder_name f) in
    let t = subst f (free_of x) in
    fprintf ff "%s_%d = ϵ(%s ∈ %a, %a ∉ %a)\n" name index (name_of x)
      (print_kind false) a (print_term false) t (print_kind false) b)
      epsilon_term_tbl;
  full_iter (fun (f,(name,index,u,is_exists)) ->
    let x = new_kvari (binder_name f) in
    let k = subst f (free_of x) in
    let symbol = if is_exists then "∈" else "∉" in
      fprintf ff "%s_%d = ϵ(%s, %a %s %a)\n" name index
      (name_of x) (print_term false) u symbol (print_kind false) k) epsilon_type_tbl;
  full_iter (fun (o,n) ->
    fprintf ff "%a = %a\n" (print_ordinal false) o (print_ordinal true) o) ordinal_tbl

exception Find_tdef of type_def

let find_tdef : kind -> type_def = fun t ->
  try
    let fn _ d =
      if d.tdef_oarity = 0 && d.tdef_karity = 0 then
        let k = msubst (msubst d.tdef_value [||]) [||] in
        if strict_eq_kind k t then raise (Find_tdef d)
    in
    Hashtbl.iter fn typ_env;
    raise Not_found
  with
    Find_tdef(t) -> t

let _ = fprint_ordinal := print_ordinal
