type T = μX [ L | N of X * X ]

?val rec peigne : T → T = fun t →
  case t of
  | L → L
  | N(l,r) →
    (case r of
    | L → N(peigne l,L)
    | N(rl,rr) →
       peigne (N(N(l,rl),rr)))

?val rec 2 peigne : T → T = fun t →
  case t of
  | L → L
  | N(l,r) →
    (case r of
    | L → N(peigne l,L)
    | N(rl,rr) →
       peigne (N(N(l,rl),rr)))

?val rec 3 peigne : T → T = fun t →
  case t of
  | L → L
  | N(l,r) →
    (case r of
    | L → N(peigne l,L)
    | N(rl,rr) →
       peigne (N(N(l,rl),rr)))

?val rec 4 peigne : T → T = fun t →
  case t of
  | L → L
  | N(l,r) →
    (case r of
    | L → N(peigne l,L)
    | N(rl,rr) →
       peigne (N(N(l,rl),rr)))

(* NOTE: kept because was looping in the previous version of subml *)

!val rec 3 peigne : T → T = fun t → (* still loops with 4 !*)
  case t of
  | L → L
  | N(l,r) →
    (case r of
    | L → N(peigne l,L)
    | N(rl,rr) →
       peigne N(N(l,rl),rr)) (*<- here two arguments*)


(* Hughes, Pareto and Sabry Paradox *)

type N = μX [ Z | S of X]
type S(α,A) = να X {} → A × X

val guard2 : ∀α∀A (S(α+1,N) → S(∞,N)) → S(α,N) → S(∞,N) =
  fun g xs → g (g (fun u →  (Z,xs)))

!val rec f : ∀α∀A (S(α,N) → S(∞,N)) → S(α,N) = fun g →
  guard2 g (f (guard2 g))

!val rec 2 f : ∀α∀A (S(α,N) → S(∞,N)) → S(α,N) = fun g →
  guard2 g (f (guard2 g))

!val rec 3 f : ∀α∀A (S(α,N) → S(∞,N)) → S(α,N) = fun g →
  guard2 g (f (guard2 g))

!val rec f : ∀α∀A (S(α+1,N) → S(∞,N)) → S(α+1,N) = fun g →
  guard2 g (f (guard2 g))

!val rec 2 f : ∀α∀A (S(α+1,N) → S(∞,N)) → S(α+1,N) = fun g →
  guard2 g (f (guard2 g))

!val rec 3 f : ∀α∀A (S(α+1,N) → S(∞,N)) → S(α+1,N) = fun g →
  guard2 g (f (guard2 g))

(* Cody Roux Paradox *)

type O(α) = μα X [ Z | S of X | L of (N → X) | M of X × X ]

val pred : ∀α (N → O(α+2)) → N → O(α+1) = fun f n → case f (S n) of
  | Z → Z
  | S x → x
  | L g → g n
  | M(x,y) → x

!val rec deep : ∀α O(α) → N = fun o →
  case o of
  | M(x,y) →
    (case x of
    | L f →
      (case y of
      | S y →
        (case y of
        | S y →
          (case y of
          | S _ → deep (M (L (pred f), f (S (S (S Z))) : N))
          | _ → Z:N)
        | _ → Z:N)
      | _ → Z:N)
    | _ → Z:N)
  | _ → Z:N

!val rec 2 deep : ∀α O(α) → N = fun o →
  case o of
  | M(x,y) →
    (case x of
    | L f →
      (case y of
      | S y →
        (case y of
        | S y →
          (case y of
          | S _ → deep (M (L (pred f), f (S (S (S Z))) : N))
          | _ → Z:N)
        | _ → Z:N)
      | _ → Z:N)
    | _ → Z:N)
  | _ → Z:N

!val rec 3 deep : ∀α O(α) → N = fun o →
  case o of
  | M(x,y) →
    (case x of
    | L f →
      (case y of
      | S y →
        (case y of
        | S y →
          (case y of
          | S _ → deep (M (L (pred f), f (S (S (S Z))) : N))
          | _ → Z:N)
        | _ → Z:N)
      | _ → Z:N)
    | _ → Z:N)
  | _ → Z:N

(* Examples from Abel2007 *)
type NS(α) = μα X [Z | S of X]
type N = NS(∞)

type A(α) = (N → NS(α)) → N

val shift : ∀α (N → NS(α+2)) → N → NS(α+1) = fun g n →
  case g (S n) of Z → Z | S p → p

!val rec loop : ∀α A(α) = fun g → loop (shift g)
!val rec 2 loop : ∀α A(α) = fun g → loop (shift g)
!val rec 3 loop : ∀α A(α) = fun g → loop (shift g)

(* and this one is not semi-continuous and shoud work *)
val rec loopnot : ∀α NS(α) → (N → NS(α)) → NS(α) = fun n g →
  case n of Z → Z
          | S n → S (loopnot n (shift g))

val pred : ∀α (NS(α+1) → NS(α)) = fun n →
  case n of Z   → abort
          | S p → p

type Hungry(α,A) = μα X (A → X)

(* Subml loops ... But seems incorrect,
   because α is not positive and we
   can not use (fun n →  ...) : Hungry(α,NS(β+1))
   without α > 0 *)
(*val rec s : ∀α∀β Hungry(α,NS(β)) → Hungry(α,NS(β+1)) =
  fun h →
     let α, β such that h : Hungry(α,NS(β)) in
     fun n →
       s (h ((pred n) : NS(β))*)

!val rec s2 : ∀α∀β Hungry(α+1,NS(β)) → Hungry(α+1,NS(β+1)) =
  fun h →
     let α, β such that h : Hungry(α+1,NS(β)) in
     fun n →
       s2 (h ((pred n) : NS(β))

(* Trying with ν we go further *)
type Hungry2(α,A) = να X (A → X)

val rec s : ∀α∀β Hungry2(α,NS(β)) → Hungry2(α,NS(β+1)) =
  fun h n →
     let β such that n : NS(β+1) in
     s (h (pred n))

val rec p : ∀α∀β Hungry2(α,NS(β+1)) → Hungry2(α,NS(β)) =
  fun h n →
     let β such that n : NS(β+1) in
     p (h (S n))

val rec h : ∀α NS(α) → Hungry2(α,NS(α)) =
  fun _ n → s (h (pred n))

!val rec tr : Hungry2(∞,N) → ∀X X =
   fun h → tr (p (h (S Z)))

!val rec 2 tr : Hungry2(∞,N) → ∀X X =
   fun h → tr (p (h (S Z)))

!val rec 3 tr : Hungry2(∞,N) → ∀X X =
   fun h → tr (p (h (S Z)))
