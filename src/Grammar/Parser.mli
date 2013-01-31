open Structure

open FanToken
    
val add_loc: FanLoc.t -> 'b parse -> ('b*FanLoc.t) parse


val level_number: entry -> string -> int

val parser_of_tree: entry -> int * assoc -> Action.t LibUtil.LStack.t ->  tree -> Action.t parse
val parser_of_terminals: terminal list -> FanToken.t list  parse
val parser_of_symbol: entry ->  symbol -> int  -> Action.t parse
    

val start_parser_of_levels: entry -> level list -> int -> Action.t parse 
val start_parser_of_entry:  entry ->  int -> Action.t parse 

val continue_parser_of_levels: entry -> int -> level list -> int -> Action.t cont_parse 
val continue_parser_of_entry:  entry -> int -> Action.t cont_parse
