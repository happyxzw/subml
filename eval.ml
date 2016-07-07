open Bindlib
open Ast
open Format

let rec eval : term -> term = fun t0 ->
  match t0.elt with
  | TCoer(t,_) -> eval t
  | TVari(_)   -> t0
  | TAbst(_,_) -> t0
  | TKAbs(f)   -> eval (subst f (KProd []))
  | TOAbs(f)   -> eval (subst f (OTInt(-1)))
  | TAppl(t,u) ->
      begin
        let u' = eval u in
        let rec fn t =
          let t' = eval t in
          match t'.elt with
          | TAbst(_,b) -> eval (subst b u')
          | TFixY(_,f) -> fn (subst f t')
          | t          -> dummy_pos (TAppl(t',u'))
        in fn t
      end
  | TReco(l)   -> in_pos t0.pos (TReco (List.map (fun (s,t) -> (s, eval t)) l))
  | TProj(t,l) ->
      begin
        let t' = eval t in
        match t'.elt with
        | TReco(fs) ->
            begin
              try eval (List.assoc l fs)
              with Not_found -> dummy_pos (TProj(t',l))
            end
        | t         -> dummy_pos (TProj(t',l))
      end
  | TCons(s,t) -> in_pos t0.pos (TCons(s, eval t))
  | TCase(t,l) ->
      begin
        let t' = eval t in
        match t'.elt with
        | TCons(c,v) ->
            begin
              try eval (dummy_pos (TAppl(List.assoc c l, v)))
              with Not_found -> dummy_pos (TCase(t',l))
            end
        | t          -> dummy_pos (TCase(t',l))
      end
  | TDefi(v)   -> eval v.value
  | TPrnt(s)   -> printf "%s%!" s; in_pos t0.pos (TReco [])
  | TFixY(_)   -> t0
  | TCnst(_)   -> invalid_arg "Constant during evaluation."
  | TTInt(_)   -> invalid_arg "Integer tag during evaluation."
