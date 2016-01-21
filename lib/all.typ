include "lib/prelude.typ"

(* Standard library. *)
include "lib/nat.typ"
include "lib/list.typ"
include "lib/applist.typ"
include "lib/set.typ"

(* Church encoding. *)
include "lib/church/bool.typ"
include "lib/church/nat.typ"
include "lib/church/data.typ"

(* Test files. *)
include "lib/dotproj.typ"
include "lib/tree.typ"
include "lib/polyrec.typ"

(* Subtyping tests. *)
include "lib/tests.typ"

(* Mixed induction and coinduction. *)
include "lib/munu/munu2.typ"
include "lib/munu/munu3.typ"
