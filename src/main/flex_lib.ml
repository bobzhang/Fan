  
%import{

Lexing_util:
  lexing_store
  ;

Format:
  fprintf
   std_formatter
   ; 
};;



let from_string  {FLoc.loc_start;_} str =
  let lb = Lexing.from_string str in begin 
    lb.lex_abs_pos <- loc_start.pos_cnum;
    lb.lex_curr_p <- loc_start;
    Fan_lex.from_lexbuf lb
  end

let from_stream  {FLoc.loc_start;_} strm =
  let lb = Lexing.from_function (lexing_store strm) in begin
    lb.lex_abs_pos <- loc_start.pos_cnum;
    lb.lex_curr_p <- loc_start;
    Fan_lex.from_lexbuf  lb
  end


(* remove trailing `EOI*)  
let rec clean  =  parser
  | (`EOI,loc)  -> %stream{ (`EOI,loc)}
  |  x; 'xs  -> %stream{ x; 'clean xs}
  |  -> %stream{} 

let rec strict_clean = parser
  | (`EOI,_)  -> %stream{}
  | x; 'xs  -> %stream{ x; 'strict_clean xs }
  |  -> %stream{} 

let debug_from_string  str =
  let loc = FLoc.string_loc  in
  let stream = from_string loc str  in
  stream
  |> clean
  |> Fstream.iter
      (fun (t,loc) -> fprintf std_formatter "%a@;%a@\n" Ftoken.print t FLoc.print loc)

let list_of_string ?(verbose=true) str =
  let result = ref [] in
  let loc = FLoc.string_loc  in
  let stream = from_string loc str  in
  begin 
    stream
    |> clean
    |> Fstream.iter
        (fun (t,loc) -> begin 
          result := (t,loc):: !result ;
          if verbose then 
            fprintf std_formatter "%a@;%a@\n" Ftoken.print t FLoc.print loc
        end) ;
   List.rev !result 
  end

let get_tokens s =
  List.map fst
    (list_of_string ~verbose:false s )
  
  
let debug_from_file  file =
  let loc = FLoc.mk file in
  let chan = open_in file in
  let stream = Fstream.of_channel  chan in
  from_stream  loc stream |> clean |>
  Fstream.iter @@
  fun (t,loc) ->
    fprintf std_formatter "%a@;%a@\n" Ftoken.print t FLoc.print loc


(* local variables: *)
(* compile-command: "cd ../main_annot && pmake flex_lib.cmo" *)
(* end: *)
