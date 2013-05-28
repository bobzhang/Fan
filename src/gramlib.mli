
open FAst
  
val setup_op_parser : FAst.exp Gram.t -> (string -> bool) -> unit

val infix_kwds_filter :
  (FToken.t * 'b) XStream.t ->  (FToken.t * 'b) XStream.t
