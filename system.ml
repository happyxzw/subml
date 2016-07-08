exception Stopped

let handle_stop : bool -> unit =
  let open Sys in function
  | true  -> set_signal sigint (Signal_handle (fun i -> raise Stopped))
  | false -> set_signal sigint Signal_default