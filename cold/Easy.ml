open Transform
open FSig
open Lib
let _loc = FanLoc.ghost
let gen_str_item ?module_name  ?(arity= 1)  ?(trail=
  `ExApp
    (_loc, (`Id (_loc, (`Lid (_loc, "failwith")))),
      (`Str (_loc, "arity >= 2 in other branches"))))
   ?cons_transform  ~id:(id : basic_id_transform)  ~names  ~mk_tuple 
  ~mk_record  mk_variant =
  let module M =
    struct
      let mk_variant = mk_variant
      let mk_tuple = mk_tuple
      let arity = arity
      let left_type_variable = `Pre "mf_"
      let right_type_variable = `Pre "mf_"
      let left_type_id = id
      let right_type_id =
        match module_name with
        | None  -> (id :>full_id_transform)
        | Some m ->
            `Last
              ((fun s  ->
                  `IdAcc
                    (_loc, (`Uid (_loc, m)),
                      (`Lid (_loc, (basic_transform id s))))))
      let trail (_,number) =
        if number > 1
        then
          let patt = Patt.tuple_of_number (`Any _loc) arity in
          `Case (_loc, patt, (`Nil _loc), trail)
        else `Nil _loc
      let names = names
      let mk_record = mk_record
      let cons_transform = cons_transform
    end in
    let module MM = Frame.Make(M) in
      let open MM in
        str_item_of_module_types ?module_name normal_simple_expr_of_ctyp
let gen_object ?module_name  ?(arity= 1)  ?(trail=
  `ExApp
    (_loc, (`Id (_loc, (`Lid (_loc, "failwith")))),
      (`Str (_loc, "arity >= 2 in other branches"))))
   ?cons_transform  ~kind  ~base  ~class_name  =
  let make ~names  ~mk_tuple  ~mk_record  mk_variant =
    let module M =
      struct
        let mk_variant = mk_variant
        let mk_tuple = mk_tuple
        let arity = arity
        let left_type_variable = `Pre "mf_"
        let right_type_variable =
          `Exp
            (fun v  ->
               let v = basic_transform left_type_variable v in
               `ExApp
                 (_loc, (`Id (_loc, (`Lid (_loc, v)))),
                   (`Id (_loc, (`Lid (_loc, "self"))))))
        let left_type_id = `Pre ""
        let right_type_id = `Obj (basic_transform left_type_id)
        let trail (_,number) =
          if number > 1
          then
            let patt = Patt.tuple_of_number (`Any _loc) arity in
            `Case (_loc, patt, (`Nil _loc), trail)
          else `Nil _loc
        let names = names
        let mk_record = mk_record
        let cons_transform = cons_transform
      end in
      let module MM = Frame.Make(M) in
        let open MM in
          obj_of_module_types ?module_name base class_name
            obj_simple_expr_of_ctyp kind in
  make