

(** Basic module contains utility functions to manipulate Ast
   This module is mainly provided to generate code. For simplicity,
   we don't take care of Location. *)
open AstN
  
exception Unhandled of ctyp
exception Finished of exp
val unit_literal : [> `Uid of string ]
val x : ?off:int -> int -> string
val xid : ?off:int -> int -> [> `Lid of string ]
val allx : ?off:int -> int -> string
val allxid : ?off:int -> int -> [> `Lid of string ]
val conversion_table : (string, string) Hashtbl.t
  
