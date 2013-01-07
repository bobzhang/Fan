open Ast
type key = string 
type expander = expr -> expr 
let macro_expanders: (key,expander) Hashtbl.t = Hashtbl.create 40
let register_macro (k,f) = Hashtbl.replace macro_expanders k f
let rec fib =
  function
  | 0|1 -> 1
  | n when n > 0 -> (fib (n - 1)) + (fib (n - 2))
  | _ -> invalid_arg "fib"
let fibm y =
  match y with
  | `Int (_loc,x) -> `Int (_loc, (string_of_int (fib (int_of_string x))))
  | x ->
      let _loc = FanAst.loc_of_expr x in
      `ExApp (_loc, (`Id (_loc, (`Lid (_loc, "fib")))), x)
let _ = register_macro ("FIB", fibm)
open LibUtil
let generate_fibs =
  function
  | `Int (_loc,x) ->
      let j = int_of_string x in
      let res =
        zfold_left ~until:j ~acc:(`Nil _loc)
          (fun acc  i  ->
             `Sem
               (_loc, acc,
                 (`ExApp
                    (_loc, (`Id (_loc, (`Lid (_loc, "print_int")))),
                      (`ExApp
                         (_loc, (`Id (_loc, (`Uid (_loc, "FIB")))),
                           (`Int (_loc, (string_of_int i))))))))) in
      `Sequence (_loc, res)
  | e -> e
let _ = register_macro ("GFIB", generate_fibs)
let macro_expander =
  object (self)
    inherit  FanAst.map as super
    method! expr =
      function
      | `ExApp (_loc,`Id (_,`Uid (_,a)),y) ->
          ((try
              let f = Hashtbl.find macro_expanders a in
              fun ()  -> self#expr (f y)
            with
            | Not_found  ->
                (fun ()  ->
                   `ExApp
                     (_loc, (`Id (_loc, (`Uid (_loc, a)))), (self#expr y)))))
            ()
      | e -> super#expr e
  end