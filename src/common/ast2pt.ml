

(** Dump the FanAst to Parsetree, this file should introduce minimal
    dependency or only dependent on those generated files*)



open Parsetree
open Longident
open Asttypes
open LibUtil
open ParsetreeHelper
open! FAst (* FIXME later*)
open Ast_basic


(** An unsafe version introduced is mainly for reducing
    unnecessary dependency when bootstrapping
    relies on the fact:
    Location.t and Lexing.position have different sizes *)
let unsafe_loc_of node =
  let open Obj in
  let u = field (repr node) 1 in
  let s  = Obj.size u in
    if s = 3 && size (field u 0) = 4 then
      (magic u : FLoc.t) (* `a loc *)
    else (* `a (loc,...)  => size (field u 0) = 3 *)
      (magic @@ field u 0 : FLoc.t)


(*************************************************************************)
(* utility begin *)

(*
   {[remove_underscores "_a" = "a"
       remove_underscores "__a" = "a"
       remove_underscores "__a___b" =  "ab"
       remove_underscores "__a___b__" = "ab"]}
*)    
let remove_underscores s =
  let l = String.length s in
  let buf = Buffer.create l in
  let () = String.iter (fun ch ->
      if ch <> '_' then ignore (Buffer.add_char buf ch) else () ) s in
  Buffer.contents buf 


(** Forward declarations *)
let dump_ident           = ref (fun _ -> failwith "Ast2pt.dump_ident not implemented")
let dump_ctyp            = ref (fun _ -> failwith "Ast2pt.dump_ctyp not implemented")
let dump_row_field       = ref (fun _ -> failwith "Ast2pt.dump_row_field not implemented")
let dump_name_ctyp       = ref (fun _ -> failwith "Ast2pt.dump_name_ctyp not implemented")
let dump_constr          = ref (fun _ -> failwith "Ast2pt.dump_constr not implemented")
let dump_mtyp            = ref (fun _ -> failwith "Ast2pt.dump_mtyp not implemented")
let dump_ctyp            = ref (fun _ -> failwith "Ast2pt.dump_ctyp not implemented")
let dump_or_ctyp         = ref (fun _ -> failwith "Ast2pt.dump_or_ctyp not implemented")
let dump_pat             = ref (fun _ -> failwith "Ast2pt.dump_pat not implemented")
let dump_type_parameters = ref (fun _ -> failwith "Ast2pt.dump_type_parameters not implemented")
let dump_exp             = ref (fun _ -> failwith "Ast2pt.dump_exp not implemented")
let dump_case            = ref (fun _ -> failwith "Ast2pt.dump_case not implemented")
let dump_rec_exp         = ref (fun _ -> failwith "Ast2pt.dump_rec_exp not implemented")
let dump_type_constr     = ref (fun _ -> failwith "Ast2pt.dump_type_constr not implemented")
let dump_typedecl        = ref (fun _ -> failwith "Ast2pt.dump_typedecl not implemented")
let dump_sigi            = ref (fun _ -> failwith "Ast2pt.dump_sigi not implemented")
let dump_mbind           = ref (fun _ -> failwith "Ast2pt.dump_mbind not implemented")
let dump_mexp            = ref (fun _ -> failwith "Ast2pt.dump_mexp not implemented")
let dump_stru            = ref (fun _ -> failwith "Ast2pt.dump_stru not implemented")
let dump_cltyp           = ref (fun _ -> failwith "Ast2pt.dump_cltyp not implemented")
let dump_cldecl          = ref (fun _ -> failwith "Ast2pt.dump_cldecl not implemented")
let dump_cltdecl         = ref (fun _ -> failwith "Ast2pt.dump_cltdecl not implemented")
let dump_clsigi          = ref (fun _ -> failwith "Ast2pt.dump_clsigi not implemented")
let dump_clexp           = ref (fun _ -> failwith "Ast2pt.dump_clexp not implemented")
let dump_clfield         = ref (fun _ -> failwith "Ast2pt.dump_clfield not implemented")



let generate_type_code :
  (FAst.loc -> FAst.typedecl -> FAst.strings -> FAst.stru) ref =
  ref (fun _ -> failwith "Ast2pt.generate_type_code not implemented")


let ant_error loc = error loc "antiquotation not expected here"

let mkvirtual  (x:flag)  : Asttypes.virtual_flag =
  match x with 
  | `Positive _ -> Virtual
  | `Negative _  -> Concrete
  | `Ant (_loc,_) -> ant_error _loc 

let flag loc (x:flag) =
  match x with
  | `Positive _ -> Override
  | `Negative _  -> Fresh
  |  _ -> error loc "antiquotation not allowed here" 

let mkdirection (x: FAst.flag) : Asttypes.direction_flag =
  match x with 
  | `Positive _ -> Upto
  | `Negative _ -> Downto
  | `Ant (_loc,_) -> ant_error _loc 

let mkrf (x: FAst.flag) : Asttypes.rec_flag =
  match x with 
  | `Positive _  -> Recursive
  | `Negative _  -> Nonrecursive
  | `Ant(_loc,_) -> ant_error _loc


let ident_tag (i : FAst.ident) :  Longident.t * [> `app | `lident | `uident ] =
  let rec self (i:FAst.ident) acc =
    let _loc = unsafe_loc_of i in
    match i with
    | `Dot (_,`Lid (_,"*predef*"),`Lid (_,"option")) ->
      Some (ldot (lident "*predef*") "option", `lident)
    | `Dot (_,i1,i2)  -> self i2 (self i1 acc)
    | `Apply (_,i1,i2) ->
      (match (self i1 None, self i2 None, acc) with
       | Some (l,_),Some (r,_),None  -> Some ((Lapply (l, r)), `app)
       | _ ->
         FLoc.failf  _loc "invalid long identifer %s" @@ !dump_ident i)
    | `Uid (_,s) ->
      (match acc, s with
       | (None ,"") -> None
       | (None ,s) -> Some (lident s, `uident)
       | (Some (_,(`uident|`app)),"") -> acc
       | (Some (x,(`uident|`app)),s) -> Some ((ldot x s), `uident)
       | _ ->
         FLoc.failf _loc "invalid long identifier %s" @@ !dump_ident i)
    | `Lid (_,s) ->
      let x =
        match acc with
        | None  -> lident s
        | Some (acc,(`uident|`app)) -> ldot acc s
        | _ ->
          FLoc.failf _loc "invalid long identifier %s" @@ !dump_ident i in
      Some (x, `lident)
    | `Ant (_,_) -> error _loc "invalid long identifier" in
  match self i None with
  | Some x -> x
  | None  -> error (unsafe_loc_of i) "invalid long identifier "        

let ident_noloc i = fst (ident_tag  i)

let ident (i:FAst.ident) :  Longident.t Location.loc  =
  with_loc (ident_noloc  i) (unsafe_loc_of i)

let long_lident  id =
  match ident_tag id with
  | (i,`lident) -> with_loc i (unsafe_loc_of id)
  | _ ->
    FLoc.failf (unsafe_loc_of id)  "invalid long identifier %s" (!dump_ident id)

let long_type_ident: FAst.ident -> Longident.t Location.loc =
  long_lident 

let long_class_ident = long_lident

let long_uident_noloc  (i:ident) =
  match ident_tag i with
  | (Ldot (i, s), `uident) -> ldot i s
  | (Lident s, `uident) -> lident s
  | (i, `app) -> i
  | _ -> FLoc.failf (unsafe_loc_of i) "uppercase identifier expected %s" (!dump_ident i) 

let long_uident  i =
  with_loc (long_uident_noloc  i) (unsafe_loc_of i)

let rec ctyp_long_id_prefix (t:FAst.ctyp) : Longident.t =
  match t with
  | #FAst.ident' as i  -> ident_noloc i
  | `App(_loc,m1,m2) ->
    let li1 = ctyp_long_id_prefix m1 in
    let li2 = ctyp_long_id_prefix m2 in
    Lapply (li1, li2)
  | t -> FLoc.failf (unsafe_loc_of t) "invalid module expression %s" (!dump_ctyp t) 

let ctyp_long_id (t:FAst.ctyp) : (bool *   Longident.t Location.loc) =
  match t with
  | #FAst.ident' as i -> false, long_type_ident i
  | `ClassPath (_, i) -> true, ident i
  | t -> FLoc.failf (unsafe_loc_of t) "invalid type %s" @@ !dump_ctyp t

let predef_option loc : FAst.ctyp =
  `Dot (loc, `Lid (loc, "*predef*"), `Lid (loc, "option"))

let rec ctyp (x:FAst.ctyp) : Parsetree.core_type =
  let _loc = unsafe_loc_of x in
  match x with 
  |  (#FAst.ident' as i) ->
    let li = long_type_ident (i:>FAst.ident) in
    mktyp _loc @@ Ptyp_constr (li, [])
  | `Alias(_,t1,`Lid(_,s)) -> 
    mktyp _loc @@ Ptyp_alias ((ctyp t1), s)
  | `Any _ -> mktyp _loc Ptyp_any
  | `App _ as f ->
    let (f, al) =view_app [] f in
    let (is_cls, li) = ctyp_long_id f in
    if is_cls then mktyp _loc  @@ Ptyp_class (li, (List.map ctyp al), [])
    else mktyp _loc @@ Ptyp_constr (li, (List.map ctyp al))
  | `Arrow (_, (`Label (_,  `Lid(_,lab), t1)), t2) ->
    mktyp _loc (Ptyp_arrow (lab, (ctyp t1), (ctyp t2)))
  | `Arrow (_, (`OptLabl (loc1, `Lid(_,lab), t1)), t2) ->
    let t1 = `App (loc1, (predef_option loc1), t1) in
    mktyp _loc (Ptyp_arrow ("?" ^ lab, ctyp t1, ctyp t2))
  | `Arrow (_loc, t1, t2) -> mktyp _loc @@ Ptyp_arrow ("", ctyp t1, ctyp t2)

  | `TyObjEnd(_,row) ->
    let xs =
      match row with
      |`Negative _ -> []
      | `Positive _ -> [mkfield _loc Pfield_var]
      | `Ant _ -> ant_error _loc in
    mktyp _loc @@ Ptyp_object xs
  | `TyObj(_,fl,row) ->
    let xs  =
      match row with
      |`Negative _ -> []
      | `Positive _  -> [mkfield _loc Pfield_var]
      | `Ant _ -> ant_error _loc  in
    mktyp _loc (Ptyp_object (meth_list fl xs))

  | `ClassPath (_, id) -> mktyp _loc  @@ Ptyp_class ((ident id), [], [])
  | `Package(_,pt) ->
    let (i, cs) = package_type pt in
    mktyp _loc (Ptyp_package (i, cs))
  | `TyPolEnd (_,t2) ->
    mktyp _loc (Ptyp_poly ([], (ctyp t2)))
  | `TyPol (_, t1, t2) ->
    let rec to_var_list  =
      function
      | `App (_,t1,t2) -> to_var_list t1 @ to_var_list t2
      | `Quote (_, (`Normal _ | `Positive _ | `Negative _), `Lid (_,s)) -> [s]
      | _ -> assert false in 
    mktyp _loc (Ptyp_poly (to_var_list t1, ctyp t2))
  (* QuoteAny should not appear here? *)      
  | `Quote (_,`Normal _, `Lid(_,s)) -> mktyp _loc (Ptyp_var s)
  | `Par(_,`Sta(_,t1,t2)) ->
    mktyp _loc (Ptyp_tuple (List.map ctyp (list_of_star t1 (list_of_star t2 []))))

  | `PolyEq(_,t) ->
    mktyp _loc (Ptyp_variant (row_field t [], true, None))
  | `PolySup(_,t) ->
    mktyp _loc (Ptyp_variant (row_field t [], false, None))
  | `PolyInf(_,t) ->
    mktyp _loc (Ptyp_variant ((row_field t []), true, (Some [])))
  | `PolyInfSup(_,t,t') ->
    let rec name_tags (x:tag_names) =
      match x with 
      | `App(_,t1,t2) -> name_tags t1 @ name_tags t2
      | `TyVrn (_, `C (_,s))    -> [s]
      | _ -> assert false  in 
    mktyp _loc (Ptyp_variant ((row_field t []), true, (Some (name_tags t'))))
  |  x -> FLoc.failf _loc "ctyp: %s" @@ !dump_ctyp x

and row_field (x:row_field) acc : Parsetree.row_field list =
  match x with 
  |`TyVrn (_loc,`C(_,i)) -> Rtag (i, true, []) :: acc
  | `TyVrnOf(_loc,`C(_,i),t) ->
    Rtag (i, false, [ctyp t]) :: acc 
  | `Bar(_,t1,t2) -> row_field t1 ( row_field t2 acc)
  | `Ant(_loc,_) -> ant_error _loc
  | `Ctyp(_,t) -> Rinherit (ctyp t) :: acc
  | t -> FLoc.failf (unsafe_loc_of t) "row_field: %s" (!dump_row_field t)

and meth_list (fl:name_ctyp) acc : Parsetree.core_field_type list   =
  match fl with
  |`Sem (_loc,t1,t2) -> meth_list t1 (meth_list t2 acc)
  | `TyCol(_loc,`Lid(_,lab),t) ->
    mkfield _loc (Pfield (lab, (mkpolytype (ctyp t)))) :: acc
  | x -> FLoc.failf (unsafe_loc_of x) "meth_list: %s" (!dump_name_ctyp x )

and package_type_constraints
    (wc:constr)
    (acc: (Longident.t Asttypes.loc  * Parsetree.core_type) list )
  : (Longident.t Asttypes.loc   * Parsetree.core_type) list  =
  match wc with
  | `TypeEq(_, (#ident' as id),ct) -> (ident id, ctyp ct) :: acc
  | `And(_,wc1,wc2) ->
    package_type_constraints wc1 (package_type_constraints wc2 acc)
  | x ->
    FLoc.failf (unsafe_loc_of x) "unexpected `with constraint:%s' for a package type"
      (!dump_constr x) 

and package_type (x : mtyp) :
  Longident.t Asttypes.loc *
    (Longident.t Asttypes.loc * Parsetree.core_type) list  =
  match x with 
  | `With(_loc,(#ident' as i),wc) ->
    (long_uident i, package_type_constraints wc [])
  | #ident' as i  -> (long_uident i, [])
  | mt -> FLoc.failf (unsafe_loc_of mt) "unexpected package type: %s" @@ !dump_mtyp mt

let mktype loc tl cl ~type_kind ~priv ~manifest =
  let (params, variance) = List.split tl in
  {Parsetree.ptype_params = params;
    ptype_cstrs = cl;
    ptype_kind = type_kind;
    ptype_private = priv;
    ptype_manifest = manifest;
    ptype_loc =  loc;
    ptype_variance = variance} 

let mkprivate (x:flag)=
  match x with 
  | `Positive _ -> Private
  | `Negative _ -> Public
  | `Ant(_loc,_)-> ant_error _loc 

let mktrecord (x: name_ctyp) :
  string Location.loc * Asttypes.mutable_flag * Parsetree.core_type *  loc=
  match x with 
  |`TyColMut(_loc,`Lid(sloc,s),t) ->
    (with_loc s sloc, Mutable, mkpolytype (ctyp t),  _loc)
  | `TyCol(_loc,`Lid(sloc,s),t) ->
    (with_loc s sloc, Immutable, mkpolytype (ctyp t),  _loc)
  | t -> FLoc.failf (unsafe_loc_of t) "mktrecord %s "
           (!dump_name_ctyp t)

let mkvariant (x:or_ctyp) :
  string Location.loc * Parsetree.core_type list *  Parsetree.core_type option * FLoc.t =
  let _loc = unsafe_loc_of x in
  match x with
  | `Uid(_,s) -> (with_loc  s _loc, [], None,  _loc)
  | `Of(_,`Uid(sloc,s),t) ->
    (with_loc  s sloc, List.map ctyp (list_of_star t []), None,  _loc)

  | `TyCol(_,`Uid(sloc,s),( `Arrow _  as t )) -> (*GADT*)
    (match List.rev (list_of_arrow_r t []) with
     | u::t ->
       (with_loc s sloc, List.map ctyp t, Some (ctyp u),  _loc)  
     | [] -> assert false)

  | `TyCol(_,`Uid(sloc,s),t) ->
    (with_loc  s sloc, [], Some (ctyp t),  _loc)
  | t -> FLoc.failf _loc "mkvariant %s " @@ !dump_or_ctyp t



let type_kind (x:type_repr) : Parsetree.type_kind  =
  match x with
  | `Record (_,t) ->
    Parsetree.Ptype_record (List.map mktrecord (list_of_sem t []))
  | `Sum(_,t) ->
    Ptype_variant (List.map mkvariant (list_of_or t []))
  | `Ant(_loc,_) -> ant_error _loc



let mkvalue_desc loc t (p:  strings list) : Parsetree.value_description =
  let ps = List.map (fun p ->
      match p with
      | `Str (_,p) -> p
      | _ -> failwithf  "mkvalue_desc") p in
  {Parsetree.pval_type = ctyp t; pval_prim = ps; pval_loc =  loc}


let mkmutable (x:flag)=
  match x with
  |`Positive _ -> Mutable
  | `Negative _ -> Immutable
  | `Ant(_loc,_) -> ant_error _loc 

let paolab (lab:string) (p:pat) : string =
  match (lab, p) with
  | ("",(`Lid(_loc,i) | `Constraint(_loc,`Lid(_,i),_)))
    -> i
  | ("", p) ->
    FLoc.failf (unsafe_loc_of p) "paolab %s" (!dump_pat p)
  | _ -> lab 


let quote_map x =
  match x with
  |`Quote (_loc,p,`Lid(sloc,s)) ->
    let tuple =
      match p with
      |`Positive _ -> (true,false)
      |`Negative _ -> (false,true)
      |`Normal _ -> (false,false)
      |`Ant (_loc,_) -> ant_error _loc  in
    (Some ( with_loc s sloc),tuple)
  |`QuoteAny(_loc,p) ->
    let tuple =
      match p with
      |`Positive _ -> (true,false)
      |`Negative _ -> (false,true)
      |`Normal _ -> (false,false)
      |`Ant (_loc,_) -> ant_error _loc  in
    (None,tuple)
  | _ ->
    FLoc.failf (unsafe_loc_of x) "quote_map %s" (!dump_ctyp x)

let optional_type_parameters (t:ctyp) = 
  List.map quote_map (list_of_app t [])

let mk_type_parameters (tl:opt_decl_params)
  :  ( (string Asttypes.loc ) option   * (bool * bool))list  =
  match tl with
  | `None _ -> []
  | `Some(_,x) ->
    List.map
      (function
        | #decl_param as x ->
          quote_map (x:>ctyp)
        |  _ -> assert false) (list_of_com x [])



(* ['a,'b,'c']*)
let  class_parameters (t:type_parameters) =
  let _loc = unsafe_loc_of t in
  List.filter_map
    (fun (y:type_parameters) ->
       match y with 
      |`Ctyp(_, x) ->
        begin match quote_map x with
          |(Some x,v) -> Some (x,v)
          | (None,_) ->
            FLoc.failf _loc  "class_parameters %s" @@ !dump_type_parameters t
        end
      | _ ->  FLoc.failf _loc "class_parameters %s" @@ !dump_type_parameters t) 
    (list_of_com t [])


let type_parameters_and_type_name (t:ctyp)  =
  let rec aux (t:ctyp) acc = 
    match t with
    |`App(_,t1,t2) ->
      aux (t1:>ctyp) (optional_type_parameters (t2:>ctyp) @ acc)
    | #ident' as i  -> (ident i, acc)
    | x ->
      FLoc.failf (unsafe_loc_of x) "type_parameters_and_type_name %s"
      @@ !dump_ctyp x  in
  aux t []



let rec pat_fa (al: pat list) (x:pat) =
  match x with
  | `App (_,f,a) -> pat_fa (a :: al) f
  | f -> (f, al) 

let rec deep_mkrangepat loc c1 c2 =
  if c1 = c2 then mkghpat loc (Ppat_constant (Const_char c1))
  else
    mkghpat loc
      (Ppat_or
         ((mkghpat loc (Ppat_constant (Const_char c1))),
          (deep_mkrangepat loc (Char.chr (Char.code c1 + 1)) c2)))

let rec mkrangepat loc c1 c2 =
  if c1 > c2 then mkrangepat loc c2 c1
  else if c1 = c2 then mkpat loc (Ppat_constant (Const_char c1))
  else
    mkpat loc
      (Ppat_or
         ((mkghpat loc (Ppat_constant (Const_char c1))),
          (deep_mkrangepat loc (Char.chr (Char.code c1 + 1)) c2)))

let  pat_literal _loc (x:literal) : Parsetree.pattern =
  match x with 
  | `Chr (_,s) ->
    mkpat _loc @@ Ppat_constant (Const_char (TokenEval.char_of_char_token _loc s))
  | `Int (_,s) ->
    let i =
      try int_of_string s
      with Failure _ ->
        error _loc
          "Integer literal exceeds the range of representable integers of type int" in
    mkpat _loc @@ Ppat_constant (Const_int i)
  | `Int32 (_,s) ->
    let i32 =
      try Int32.of_string s
      with Failure _ ->
        error _loc
          "Integer literal exceeds the range of representable integers of type int32" in
    mkpat _loc  @@ Ppat_constant (Const_int32 i32)
  | `Int64 (_,s) ->
    let i64 =
      try Int64.of_string s
      with
        Failure _ ->
        error _loc
          "Integer literal exceeds the range of representable integers of type int64" in
    mkpat _loc  @@ Ppat_constant (Const_int64 i64)
  | `Nativeint (_,s) ->
    let nati =
      try Nativeint.of_string s
      with
        Failure _ ->
        error _loc
          "Integer literal exceeds the range of representable integers of type nativeint" in
    mkpat _loc @@ Ppat_constant (Const_nativeint nati)
  | `Flo (_,s) ->
    mkpat _loc (Ppat_constant (Const_float (remove_underscores s)))
  | `Str (_,s) ->
    mkpat _loc @@
      Ppat_constant
        (Const_string (TokenEval.string_of_string_token _loc s))



let exp_literal _loc (x:literal) : Parsetree.expression =
  match x with
  | `Chr (_,s) ->
    mkexp _loc (Pexp_constant (Const_char (TokenEval.char_of_char_token _loc s)))
  | `Int (_,s) ->
    let i =
      try int_of_string s with Failure _ ->
        error _loc "Integer literal exceeds the range of representable integers of type int"
    in mkexp _loc (Pexp_constant (Const_int i))
  | `Int32 (_, s) ->
    let i32 =
      try Int32.of_string s with 
        Failure _ ->
        error _loc "Integer literal exceeds the range of representable integers of type int32"
    in mkexp _loc (Pexp_constant (Const_int32 i32))
  | `Int64 (_, s) ->
    let i64 = try Int64.of_string s with 
        Failure _ ->
        error _loc "Integer literal exceeds the range of representable integers of type int64"
    in mkexp _loc (Pexp_constant (Const_int64 i64))
  | `Flo (_,s) -> mkexp _loc (Pexp_constant (Const_float (remove_underscores s)))      
  | `Nativeint (_,s) ->
    let nati =
      try Nativeint.of_string s with 
        Failure _ ->
        error _loc "Integer literal exceeds the range of representable integers of type nativeint"
    in mkexp _loc (Pexp_constant (Const_nativeint nati))
  | `Str (_,s) ->
    mkexp _loc @@ Pexp_constant (Const_string (TokenEval.string_of_string_token _loc s))



let rec pat (x : pat) : Parsetree.pattern =
  let _loc = unsafe_loc_of x in 
  match x with
  | #literal as x -> pat_literal _loc x 
  | `Lid (_,("true"|"false" as txt)) ->
    mkpat _loc @@ Ppat_construct ({ txt = (Lident txt); loc = _loc }, None, false) 
  | `Lid (_,s) ->
    mkpat _loc @@ Ppat_var (with_loc s _loc)
  | `Uid _ |`Dot _ as i ->
    mkpat _loc @@ Ppat_construct ((long_uident (i : vid  :>ident)), None, false)
  | `Alias (_,p1,x) ->
    (match x with
     | `Lid (sloc,s) ->
       mkpat _loc  @@ Ppat_alias (pat p1, with_loc s sloc)
     | `Ant (_loc,_) -> error _loc "invalid antiquotations")
  | `Ant _ -> error _loc "antiquotation not allowed here"
  | `Any _  -> mkpat _loc Ppat_any
  | `App (_,`Uid (sloc,s),`Par (_,`Any loc_any )) ->
    mkpat _loc @@
      Ppat_construct
        (lident_with_loc s sloc, Some (mkpat loc_any Ppat_any), false)
  | `App (_,_,_) as f ->
    let (f,al) = pat_fa [] f in
    let al = List.map pat al in
    (match (pat f).ppat_desc with
     | Ppat_construct (li,None ,_) ->
       let a =
         match al with | a::[] -> a | _ -> mkpat _loc @@ Ppat_tuple al in
       mkpat _loc @@ Ppat_construct (li, (Some a), false)
     | Ppat_variant (s,None ) ->
       let a =
         match al with
         | [a] -> a
         | _ -> mkpat _loc (Ppat_tuple al) in
       mkpat _loc @@ Ppat_variant (s, (Some a))
     | _ ->
       error _loc "this is not a constructor, it cannot be applied in a pattern")
  | `Array (_,p)  ->
    mkpat _loc @@ Ppat_array (List.map pat (list_of_sem p []))
  | `ArrayEmpty _ -> mkpat _loc @@ Ppat_array []
  | `Bar (_,p1,p2) -> mkpat _loc  @@ Ppat_or (pat p1, pat p2)
  | `PaRng (_,p1,p2) ->
    (match p1, p2 with
     | `Chr (loc1,c1),`Chr (loc2,c2) ->
       let c1 = TokenEval.char_of_char_token loc1 c1 in
       let c2 = TokenEval.char_of_char_token loc2 c2 in
       mkrangepat _loc c1 c2
     | _ -> error _loc "range pattern allowed only for characters")

  | `Label _ | `LabelS _ | `OptLablExpr _ | `OptLabl _ | `OptLablS _ -> 
    error _loc "labeled pattern not allowed here"
  | `Record (_,p) ->
    let ps = list_of_sem p [] in
    let (wildcards,ps) =
      List.partition (function | `Any _ -> true | _ -> false) ps in
    let is_closed = if wildcards = [] then Closed else Open in
    let mklabpat (p : rec_pat) =
      match p with
      | `RecBind (_loc,i,p) -> ident i, pat p
      | p -> error (unsafe_loc_of p) "invalid pattern" in
    mkpat _loc (Ppat_record ((List.map mklabpat ps), is_closed))
  | `Par (_,`Com (_,p1,p2)) ->
    mkpat _loc
      (Ppat_tuple (List.map pat (list_of_com p1 (list_of_com p2 []))))
  | `Par (_,_) -> error _loc "singleton tuple pattern"
  | `Constraint (_loc,p,t) ->
    mkpat _loc (Ppat_constraint ((pat p), (ctyp t)))
  | `ClassPath (_,i) -> mkpat _loc @@ Ppat_type (long_type_ident i)
  | `Vrn (_,s)  -> mkpat _loc @@ Ppat_variant (s, None)
  | `Lazy (_,p) -> mkpat _loc @@ Ppat_lazy (pat p)
  | `ModuleUnpack (_,`Uid (sloc,m)) ->
    mkpat _loc (Ppat_unpack (with_loc m sloc))
  | `ModuleConstraint (_,`Uid (sloc,m),ty) ->
    mkpat _loc @@
      Ppat_constraint
        (mkpat sloc (Ppat_unpack (with_loc m sloc)), ctyp ty)
  | p -> FLoc.failf _loc "invalid pattern %s" @@ !dump_pat p


(**
   The input is either {|$_.$_|} or {|$(id:{:ident| $_.$_|})|}
   the type of return value and [acc] is
   [(loc* string list * exp) list]

   The [string list] is generally a module path, the [exp] is the last field

   Examples:
   {[
     sep_dot_exp [] {|A.B.g.U.E.h.i|};
     - : (loc * string list * exp) list =
     [(, ["A"; "B"], ExId (, Lid (, "g")));
      (, ["U"; "E"], ExId (, Lid (, "h"))); (, [], ExId (, Lid (, "i")))]

       sep_dot_exp [] {|A.B.g.i|};
     - : (loc * string list * exp) list =
     [(, ["A"; "B"], ExId (, Lid (, "g"))); (, [], ExId (, Lid (, "i")))]

       sep_dot_exp [] {|$(uid:"").i|};
     - : (loc * string list * exp) list =
     [(, [""], ExId (, Lid (, "i")))]  ]} *)

let rec exp (x : exp) : Parsetree.expression =
  let _loc = unsafe_loc_of x in
  match x with 
  | `Field(_,_,_)| `Dot (_,_,_)->
    let (e, l) =
      let rec normalize_acc (x:FAst.ident) : FAst.exp=
            let _loc = unsafe_loc_of x in
            match x with 
            | `Dot (_,i1,i2) ->
              `Field (_loc, normalize_acc i1, normalize_acc i2)
            | `Apply (_,i1,i2) ->
              `App (_loc, normalize_acc i1, normalize_acc i2)
            | `Ant _ | `Uid _ | `Lid _ as i ->  i in
      
      let rec sep_dot_exp acc (x: exp) : (loc * string list  * exp ) list =
        match x with
        | `Field(_,e1,e2) ->
          sep_dot_exp (sep_dot_exp acc e2) e1
        | (`Dot(_l,_,_) as i) ->
          sep_dot_exp acc (normalize_acc (i : vid :>ident)) 
        |  `Uid(loc,s) as e ->
          (match acc with
           | [] -> [(loc, [], e)]
           | (loc',sl,e)::l -> (FLoc.merge loc loc', s :: sl, e) :: l )
        | e -> (unsafe_loc_of e, [], e) :: acc in
      match sep_dot_exp [] x with
      | (loc, ml, `Uid(_,s)) :: l ->
        (mkexp loc (Pexp_construct (mkli loc  s ml, None, false)), l)
      | (loc, ml, `Lid(_,s)) :: l ->
        (mkexp loc (Pexp_ident (mkli loc s ml)), l)
      | (_, [], e) :: l -> (exp e, l)
      | _ -> FLoc.failf (unsafe_loc_of x) "exp: %s" (!dump_exp x) in
    let (_, e) =
      List.fold_left
        (fun (loc_bp, e1) (loc_ep, ml, e2) ->
           match e2 with
           | `Lid(sloc,s) ->
             let loc = FLoc.merge loc_bp loc_ep in
             (loc, mkexp loc (Pexp_field (e1, (mkli sloc s ml))))
           | _ -> error (unsafe_loc_of e2) "lowercase identifier expected" )
        (_loc, e) l in e

  | `App _ as f ->
    let (f, al) = view_app [] f in
    let al = List.map label_exp al in
    begin match (exp f).pexp_desc with
      | Pexp_construct (li, None, _) ->
        let al = List.map snd al in
        let a =
          match al with
          | [a] -> a
          | _ -> mkexp _loc (Pexp_tuple al)  in
        mkexp _loc (Pexp_construct (li, (Some a), false))
      | Pexp_variant (s, None) ->
        let al = List.map snd al in
        let a =
          match al with
          | [a] -> a
          | _ -> mkexp _loc (Pexp_tuple al) in
        mkexp _loc (Pexp_variant (s, (Some a)))
      | _ -> mkexp _loc @@ Pexp_apply (exp f, al)
    end
  | `ArrayDot (_, e1, e2) ->
    mkexp _loc
      (Pexp_apply
         (mkexp _loc @@ Pexp_ident (array_function _loc "Array" "get"),
          [("", exp e1); ("", exp e2)]))
  | `Array (loc,e) -> mkexp loc
                        (Pexp_array
                           (List.map exp (list_of_sem e []))) (* be more precise*)
  | `ArrayEmpty _ -> mkexp _loc (Pexp_array [])
  | `Assert(_,`Lid(_,"false")) -> mkexp _loc Pexp_assertfalse
  | `Assert(_,e) -> mkexp _loc (Pexp_assert (exp e)) 
  | `Assign (_,e,v) ->   (* {:exp| $e :=  $v|} *) (* FIXME refine to differentiate *)
    let e =
      match (e:exp) with
      | `Field (loc,x,`Lid (_,"contents")) ->
        Pexp_apply
          ((mkexp loc (Pexp_ident (lident_with_loc ":=" loc))),
           [("", (exp x)); ("", (exp v))])
      | `Field (loc,_,_) ->
        begin match (exp e).pexp_desc with
          | Pexp_field (e, lab) -> Pexp_setfield (e, lab, (exp v))
          | _ -> error loc "bad record access"  end
      | `ArrayDot (loc, e1, e2) ->
        Pexp_apply
          ((mkexp loc (Pexp_ident (array_function loc "Array" "set"))),
           [("", exp e1); ("", exp e2); ("", exp v)])
      | `Lid(lloc,lab)  ->
        Pexp_setinstvar (with_loc lab lloc, exp v)
      | `StringDot (loc, e1, e2) ->
        Pexp_apply
          ((mkexp loc (Pexp_ident (array_function loc "String" "set"))),
           [("", exp e1); ("", exp e2); ("", exp v)])
      | x -> FLoc.failf _loc "bad left part of assignment:%s" (!dump_exp x)  in
    mkexp _loc e
  | `Subtype (_,e,t2) ->
    mkexp _loc (Pexp_constraint (exp e, None, (Some (ctyp t2))))
  | `Coercion (_, e, t1, t2) ->
    let t1 = Some (ctyp t1) in
    mkexp _loc (Pexp_constraint (exp e, t1, (Some (ctyp t2))))

  | `For (_loc, `Lid(sloc,i), e1, e2, df, el) ->
    let e3 = `Seq (_loc, el) in
    mkexp _loc @@
      Pexp_for
         (with_loc i sloc, exp e1, exp e2, mkdirection df, exp e3)

  | `Fun(_loc,
         `Case(_,
               (`LabelS _ | `Label _ | `OptLablS _
               | `OptLabl _ | `OptLablExpr _  as l)  ,e)) ->
    let lab, p,e1  =
      match l with
      |`LabelS(_,(`Lid (_,lab) as l)) ->
        lab,pat l,None
      |`OptLablS(_,(`Lid(_,lab) as l)) ->
        "?"^lab, pat l,None
      |`Label(_,`Lid(_,lab),po) -> lab,pat po,None
      |`OptLabl(_,`Lid(_,lab),po) ->
        "?" ^ paolab lab po, pat po,None
      |`OptLablExpr(_,`Lid(_,lab),po,e1) ->
        "?" ^ paolab lab po, pat po, Some (exp e1)
      | _ -> assert false in
    mkexp _loc @@
      Pexp_function (lab, e1, [(p,exp e)])
  | `Fun(_,
         `CaseWhen(_,
                   (`LabelS _ | `Label _ | `OptLablS _  | `OptLablExpr _ | `OptLabl _ as l ),
                   w,e)) ->
    let lab,p,e1 =
      match l with
      |`LabelS(_,(`Lid(_,lab) as l)) ->
        lab,pat l,None
      |`Label (_,`Lid(_,lab),po) ->
        lab, pat po,None
      |`OptLablS(_,(`Lid(_,lab) as l)) ->
        "?"^lab, pat l,None
      |`OptLabl(_,`Lid(_,lab),po) ->
        "?"^paolab lab po, pat po,None
      |`OptLablExpr(_,`Lid(_,lab),po,e1) ->
        "?"^ paolab lab po, pat po, Some (exp e1)
      | _ -> assert false in
    mkexp _loc @@ Pexp_function
        (lab, e1, [( p, mkexp (unsafe_loc_of w) (Pexp_when (exp w, exp e)))])
  | `Fun (_,a) -> mkexp _loc @@ Pexp_function ("", None ,case a )

  | `IfThenElse (_, e1, e2, e3) ->
    mkexp _loc @@ Pexp_ifthenelse (exp e1,exp e2,Some (exp e3))

  | `IfThen (_,e1,e2) -> mkexp _loc @@ Pexp_ifthenelse (exp e1,exp e2, None)
  | #literal as x -> exp_literal _loc x 
  | `Any _ -> FLoc.failf _loc "Any should not appear in the position of expression"
  | `Label _ | `LabelS _ -> error _loc "labeled expression not allowed here"
  | `Lazy (_loc,e) -> mkexp _loc @@ Pexp_lazy (exp e)
  | `LetIn (_,rf,bi,e) ->
    mkexp _loc @@ Pexp_let (mkrf rf,bind bi [], exp e)
  | `LetTryInWith(_,rf,bi,e,cas) ->
    let cas =
      let rec f (x:case)  : case=
        match x with
        | `Case (_loc,p,e)  ->
          `Case (_loc, p, `Fun (_loc, (`Case (_loc, `Uid (_loc, "()"), e))))
        | `CaseWhen (_loc,p,c,e) -> 
          `CaseWhen
            (_loc, p, c,
              (`Fun (_loc, (`Case (_loc, (`Uid (_loc, "()")), e))))) 
        | `Bar (_loc,a1,a2) -> `Bar (_loc, f a1, f a2)
        | `Ant (_loc,_) -> ant_error _loc in
      f cas in  
    exp
      (`App
         (_loc,
          (`Try
             (_loc,
              (`LetIn
                 (_loc, rf, bi,
                  (`Fun (_loc, (`Case (_loc, (`Uid (_loc, "()")), e)))))),
              cas)), (`Uid (_loc, "()"))) : FAst.exp )
  (* {:exp| *)
  (*  (try let $rec:rf $bi in fun () -> $e with | $cas  ) () |} *)

  | `LetModule (_,`Uid(sloc,i),me,e) ->
    mkexp _loc @@ Pexp_letmodule (with_loc i sloc,mexp me,exp e)
  | `Match (_,e,a) -> mkexp _loc @@ Pexp_match (exp e,case a )
  | `New (_,id) -> mkexp _loc @@ Pexp_new (long_type_ident id)
  | `ObjEnd _ ->
    mkexp _loc @@ Pexp_object{pcstr_pat= pat (`Any _loc); pcstr_fields=[]}
  | `Obj(_,cfl) ->
    let p = `Any _loc in 
    let cil = clfield cfl [] in
    mkexp _loc @@ Pexp_object { pcstr_pat = pat p; pcstr_fields = cil }
  | `ObjPatEnd(_,p) ->
    mkexp _loc @@ Pexp_object{pcstr_pat=pat p; pcstr_fields=[]}

  | `ObjPat (_,p,cfl) ->
    let cil = clfield cfl [] in
    mkexp _loc @@ Pexp_object { pcstr_pat = pat p; pcstr_fields = cil }
      
  | `OvrInstEmpty _ -> mkexp _loc @@ Pexp_override []
  | `OvrInst (_,iel) ->
    let rec mkideexp (x:rec_exp) acc  = 
      match x with 
      |`Sem(_,x,y) ->  mkideexp x (mkideexp y acc)
      | `RecBind(_,`Lid(sloc,s),e) -> (with_loc s sloc, exp e) :: acc
      | _ -> assert false  in
    mkexp _loc @@ Pexp_override (mkideexp iel [])
  | `Record (_,lel) ->
    mkexp _loc @@ Pexp_record (mklabexp lel, None)
  | `RecordWith(_loc,lel,eo) ->
    mkexp _loc @@ Pexp_record (mklabexp lel,Some (exp eo))
  | `Seq (_,e) ->
    let rec loop = function
      | [] -> exp (`Uid (_loc, "()") : FAst.exp )
      | [e] -> exp e
      | e :: el ->
        let _loc = FLoc.merge (unsafe_loc_of e) _loc in
        mkexp _loc (Pexp_sequence (exp e,loop el))  in
    loop (list_of_sem e []) 
  | `Send (_,e,`Lid(_,s)) ->
    mkexp _loc (Pexp_send (exp e, s))
  | `StringDot (_, e1, e2) ->
    mkexp _loc
      (Pexp_apply
         (mkexp _loc (Pexp_ident (array_function _loc "String" "get")),
          [("", exp e1); ("", exp e2)]))

  | `Try (_,e,a) -> mkexp _loc @@ Pexp_try (exp e,case a )
  | `Par (_,e) ->
    let l = list_of_com e [] in
    begin match l with
      | []
      | [_] -> FLoc.failf _loc "tuple should have at least two items" (!dump_exp x)
      | _ -> 
        mkexp _loc (Pexp_tuple (List.map exp l))
    end
  | `Constraint (_,e,t) -> mkexp _loc (Pexp_constraint (exp e,Some (ctyp t), None))
  | `Uid(_,s) ->
    mkexp _loc @@ Pexp_construct (lident_with_loc  s _loc, None, true)
  | `Lid(_,("true"|"false" as s)) -> 
    mkexp _loc @@ Pexp_construct (lident_with_loc s _loc,None, true)
  | `Lid(_,s) ->
    mkexp _loc @@ Pexp_ident (lident_with_loc s _loc)
  | `Vrn (_,s) -> mkexp _loc @@ Pexp_variant  (s, None)
  | `While (_, e1, el) ->
    let e2 = `Seq (_loc, el) in
    mkexp _loc @@ Pexp_while (exp e1,exp e2)
  | `LetOpen(_,f, i,e) ->
    mkexp _loc (Pexp_open (flag _loc f, long_uident i,exp e))
  | `Package_exp (_,`Constraint(_,me,pt)) -> 
    mkexp _loc @@
      Pexp_constraint
         (mkexp _loc (Pexp_pack (mexp me)),
          Some (mktyp _loc (Ptyp_package (package_type pt))), None)
  | `Package_exp(_,me) -> 
    mkexp _loc @@ Pexp_pack (mexp me)
  | `LocalTypeFun (_,`Lid(_,i),e) -> mkexp _loc @@ Pexp_newtype (i, exp e)
  | x -> FLoc.failf _loc "exp:%s" @@ !dump_exp x
and label_exp (x : exp) =
  match x with 
  | `Label (_,`Lid(_,lab),eo) -> (lab,  exp eo)
  | `LabelS(_,`Lid(sloc,lab)) -> (lab,exp (`Lid(sloc,lab)))
  | `OptLabl (_,`Lid(_,lab),eo) -> ("?" ^ lab, exp eo)
  | `OptLablS(loc,`Lid(_,lab)) -> ("?"^lab, exp (`Lid(loc,lab)))
  | e -> ("", exp e) 

and bind (x:bind) acc =
  match x with
  | (`And (_loc,x,y) : FAst.bind) -> bind x (bind y acc)
  | (`Bind
       (_loc,(`Lid (sloc,bind_name) : FAst.pat),`Constraint
          (_,e,`TyTypePol (_,vs,ty)))
     : FAst.bind) ->
    let rec id_to_string (x : ctyp) =
      match x with
      | `Lid (_,x) -> [x]
      | `App (_loc,x,y) -> (id_to_string x) @ (id_to_string y)
      | x ->
        FLoc.failf (unsafe_loc_of x) "id_to_string %s" @@ !dump_ctyp x in
    let vars = id_to_string vs in
    let ampersand_vars = List.map (fun x  -> "&" ^ x) vars in
    let ty' = varify_constructors vars (ctyp ty) in
    let mkexp = mkexp _loc in
    let mkpat = mkpat _loc in
    let e = mkexp (Pexp_constraint ((exp e), (Some (ctyp ty)), None)) in
    let rec mk_newtypes x =
      match x with
      | newtype::[] -> mkexp (Pexp_newtype (newtype, e))
      | newtype::newtypes ->
        mkexp (Pexp_newtype (newtype, (mk_newtypes newtypes)))
      | [] -> assert false in
    let pat =
      mkpat
        (Ppat_constraint
           ((mkpat (Ppat_var (with_loc bind_name sloc))),
            (mktyp _loc (Ptyp_poly (ampersand_vars, ty'))))) in
    let e = mk_newtypes vars in (pat, e) :: acc
  | (`Bind (_loc,p,`Constraint (_,e,`TyPol (_,vs,ty))) : FAst.bind) ->
    ((pat (`Constraint (_loc, p, (`TyPol (_loc, vs, ty))) : FAst.pat )),
     (exp e))
    :: acc
  | (`Bind (_loc,p,e) : FAst.bind) -> ((pat p), (exp e)) :: acc
  | _ -> assert false
and case (x:case) = 
  let cases = list_of_or x [] in
  List.filter_map
    (fun (x:case) ->
       let _loc = unsafe_loc_of x in
       match x with 
       | `Case (_,p,e) -> Some (pat p, exp e)
       | `CaseWhen (_,p,w,e) ->
         Some
           (pat p, mkexp (unsafe_loc_of w) (Pexp_when (exp w, exp e)))
       | x -> FLoc.failf _loc "case %s" @@ !dump_case x)
    cases

and mklabexp (x:rec_exp)  =
  let binds = list_of_sem x [] in
  List.filter_map
    (function
      | (`RecBind (_loc,i,e) : FAst.rec_exp) -> Some ((ident i), (exp e))
      | x -> FLoc.failf (unsafe_loc_of x) "mklabexp : %s" @@ !dump_rec_exp x)
    binds

and mktype_decl (x:typedecl)  =
  let type_decl tl cl loc (x:type_info) =
    match x with
    |`TyMan(_,t1,p,t2) ->
      mktype loc tl cl
        ~type_kind:(type_kind t2) ~priv:(mkprivate p) ~manifest:(Some (ctyp t1))
    | `TyRepr (_,p1,repr) ->
      mktype loc tl cl
        ~type_kind:(type_kind repr)
        ~priv:(mkprivate p1) ~manifest:None
    | `TyEq (_loc,p1,t1) ->
      mktype loc tl cl ~type_kind:(Ptype_abstract) ~priv:(mkprivate p1)
        ~manifest:(Some (ctyp t1 ))
    | `Ant (_loc,_) -> ant_error _loc  in
  let tys = list_of_and x [] in
  List.map
    (function 
      |`TyDcl (cloc,`Lid(sloc,c),tl,td,cl) ->
        let cl =
          match cl with
          |`None _ -> []
          | `Some(_,cl) ->
            list_of_and cl []
            |> List.map
              (function
                |`Eq(loc,t1,t2) ->
                  (ctyp t1, ctyp t2, loc)
                | _ -> FLoc.failf (unsafe_loc_of x) "invalid constraint: %s" (!dump_type_constr cl)) in
        (with_loc c sloc,
         type_decl
           (mk_type_parameters tl)
           cl cloc td)
      | `TyAbstr(cloc,`Lid(sloc,c),tl,cl) ->
        let cl =
          match cl with
          |`None _ -> []
          | `Some(_,cl) ->
            list_of_and cl []
            |> List.map
              (function
                |`Eq(loc,t1,t2) ->
                  (ctyp t1, ctyp t2, loc)
                | _ -> FLoc.failf (unsafe_loc_of x) "invalid constraint: %s" (!dump_type_constr cl)) in            
        (with_loc c sloc,
         mktype cloc
           (mk_type_parameters tl) cl
           ~type_kind:Ptype_abstract ~priv:Private ~manifest:None)

      | (t:typedecl) ->
        FLoc.failf (unsafe_loc_of t) "mktype_decl %s" (!dump_typedecl t)) tys
and mtyp : FAst.mtyp -> Parsetree.module_type =
  let  mkwithc (wc:constr)  =
    let mkwithtyp pwith_type loc priv id_tpl ct =
      let (id, tpl) = type_parameters_and_type_name id_tpl in
      let (params, variance) = List.split tpl in
      (id, pwith_type
         {ptype_params = params; ptype_cstrs = [];
          ptype_kind =  Ptype_abstract;
          ptype_private = priv;
          ptype_manifest = Some (ctyp ct);
          ptype_loc =  loc; ptype_variance = variance}) in
    let constrs = list_of_and wc [] in
    List.filter_map (function
        |`TypeEq(_loc,id_tpl,ct) ->
          Some (mkwithtyp (fun x -> Pwith_type x) _loc Public id_tpl ct)
        |`TypeEqPriv(_loc,id_tpl,ct) ->
          Some (mkwithtyp (fun x -> Pwith_type x) _loc Private id_tpl ct)
        | `ModuleEq(_loc,i1,i2) ->
          Some (long_uident i1, Pwith_module (long_uident i2))
        | `TypeSubst(_loc,id_tpl,ct) ->
          Some (mkwithtyp (fun x -> Pwith_typesubst x) _loc Public id_tpl ct )
        | `ModuleSubst(_loc,i1,i2) ->
          Some (long_uident i1, Pwith_modsubst (long_uident i2))
        | t -> FLoc.failf (unsafe_loc_of t) "bad with constraint (antiquotation) : %s" (!dump_constr t)) constrs in
  function 
  | #ident' as i  -> let loc = unsafe_loc_of i in mkmty loc (Pmty_ident (long_uident i))
  | `Functor(loc,`Uid(sloc,n),nt,mt) ->
    mkmty loc (Pmty_functor (with_loc n sloc,mtyp nt,mtyp mt))
  | `Sig(loc,sl) ->
    mkmty loc (Pmty_signature (sigi sl []))
  | `SigEnd(loc) -> mkmty loc (Pmty_signature [])
  | `With(loc,mt,wc) -> mkmty loc (Pmty_with (mtyp mt,mkwithc wc ))
  | `ModuleTypeOf(_loc,me) ->
    mkmty _loc (Pmty_typeof (mexp me))
  | t -> FLoc.failf (unsafe_loc_of t) "mtyp: %s" (!dump_mtyp t) 
and sigi (s:sigi) (l:signature) :signature =
  match s with 
  | `Class (loc,cd) ->
    mksig loc (Psig_class
                 (List.map class_info_cltyp (list_of_and cd []))) :: l
  | `ClassType (loc,ctd) ->
    mksig loc (Psig_class_type
                 (List.map class_info_cltyp (list_of_and ctd []))) :: l
  | `Sem(_,sg1,sg2) -> sigi sg1 (sigi sg2 l)
  | `Directive _ | `DirectiveSimple _  -> l

  | `Exception(_loc,`Uid(_,s)) ->
    mksig _loc (Psig_exception (with_loc s _loc, [])) :: l
  | `Exception(_loc,`Of(_,`Uid(sloc,s),t)) ->
    mksig _loc
      (Psig_exception
         (with_loc s sloc,
          List.map ctyp (list_of_star t []))) :: l
  | `Exception (_,_) -> assert false (*FIXME*)
  | `External (loc, `Lid(sloc,n), t, sl) ->
    mksig loc
      (Psig_value
         (with_loc n sloc,
          mkvalue_desc loc t (list_of_app sl []))) :: l
  | `Include (loc,mt) -> mksig loc (Psig_include (mtyp mt)) :: l
  | `Module (loc,`Uid(sloc,n),mt) ->
    mksig loc (Psig_module (with_loc n sloc,mtyp mt)) :: l
  | `RecModule (loc,mb) ->
    mksig loc (Psig_recmodule (module_sig_bind mb [])) :: l
  | `ModuleTypeEnd(loc,`Uid(sloc,n)) ->
    mksig loc (Psig_modtype (with_loc n sloc , Pmodtype_abstract) ) :: l
  | `ModuleType (loc,`Uid(sloc,n),mt) ->
    let si =  Pmodtype_manifest (mtyp mt)  in
    mksig loc (Psig_modtype (with_loc n sloc, si)) :: l
  | `Open (loc,g,id) ->
    mksig loc (Psig_open (flag loc g, long_uident id)) :: l
  | `Type (loc,tdl) -> mksig loc (Psig_type (mktype_decl tdl )) :: l
  | `Val (loc,`Lid(sloc,n),t) ->
    mksig loc (Psig_value (with_loc n sloc,mkvalue_desc loc t [])) :: l
  | t -> FLoc.failf (unsafe_loc_of t) "sigi: %s" (!dump_sigi t)
and module_sig_bind (x:mbind) 
    (acc: (string Asttypes.loc * Parsetree.module_type) list )  =
  match x with 
  | `And(_,x,y) -> module_sig_bind x (module_sig_bind y acc)
  | `Constraint(_loc,`Uid(sloc,s),mt) ->
    (with_loc s sloc, mtyp mt) :: acc
  | t -> FLoc.failf (unsafe_loc_of t) "module_sig_bind: %s" (!dump_mbind t) 
and module_str_bind (x:FAst.mbind) acc =
  match x with 
  | `And(_,x,y) -> module_str_bind x (module_str_bind y acc)
  | `ModuleBind(_loc,`Uid(sloc,s),mt,me)->
    (with_loc s sloc, mtyp mt, mexp me) :: acc
  | t -> FLoc.failf (unsafe_loc_of t) "module_str_bind: %s" (!dump_mbind t)
and mexp (x:FAst.mexp)=
  match x with 
  | #vid'  as i ->
    let loc = unsafe_loc_of i in  mkmod loc (Pmod_ident (long_uident (i:vid':>ident)))
  | `App(loc,me1,me2) ->
    mkmod loc (Pmod_apply (mexp me1,mexp me2))
  | `Functor(loc,`Uid(sloc,n),mt,me) ->
    mkmod loc (Pmod_functor (with_loc n sloc,mtyp mt,mexp me))
  | `Struct(loc,sl) -> mkmod loc (Pmod_structure (stru sl []))
  | `StructEnd(loc) -> mkmod loc (Pmod_structure [])
  | `Constraint(loc,me,mt) ->
    mkmod loc (Pmod_constraint (mexp me,mtyp mt))
  | `PackageModule(loc,`Constraint(_,e,`Package(_,pt))) ->
    mkmod loc
      (Pmod_unpack (
          mkexp loc
            (Pexp_constraint
               (exp e, Some (mktyp loc (Ptyp_package (package_type pt))), None))))
  | `PackageModule(loc,e) -> mkmod loc (Pmod_unpack (exp e))
  | t -> FLoc.failf (unsafe_loc_of t) "mexp: %s" (!dump_mexp t) 
and stru (s:stru) (l:structure) : structure =
  let loc = unsafe_loc_of s in
  match s with
  (* ad-hoc removing the empty statement, a more elegant way is in need*)
  | (`StExp (_, (`Uid (_, "()")))) -> l 
  | `Sem(_,st1,st2) ->  stru st1 (stru st2 l)        
  | (`Class (loc,cd) :stru) ->
    mkstr loc (Pstr_class
                 (List.map class_info_clexp (list_of_and cd []))) :: l
  | `ClassType (_,ctd) ->
    mkstr loc (Pstr_class_type
                 (List.map class_info_cltyp (list_of_and ctd []))) :: l

  | `Directive _ | `DirectiveSimple _  -> l
  | `Exception(_,`Uid(_,s)) ->
    mkstr loc (Pstr_exception (with_loc s loc, [])) :: l 
  | `Exception (_, `Of (_,  `Uid (_, s), t)) ->
    mkstr loc
      (Pstr_exception
         (with_loc s loc,
          List.map ctyp (list_of_star t []))) :: l 
  (* TODO *)     
  (* | {@loc| exception $uid:s = $i |} -> *)
  (*     [mkstr loc (Pstr_exn_rebind (with_loc s loc) (ident i)) :: l ] *)
  (* | {@loc| exception $uid:_ of $_ = $_ |} -> *)
  (*     error loc "type in exception alias" *)
  | `Exception (_,_) -> assert false (*FIXME*)
  | `StExp (_,e) -> mkstr loc (Pstr_eval (exp e)) :: l
  | `External(_,`Lid(sloc,n),t,sl) ->
    mkstr loc
      (Pstr_primitive
         (with_loc n sloc,
          mkvalue_desc loc t (list_of_app sl [] ))) :: l
  | `Include (_,me) -> mkstr loc (Pstr_include (mexp me)) :: l
  | `Module (_,`Uid(sloc,n),me) ->
    mkstr loc (Pstr_module (with_loc n sloc,mexp me)) :: l
  | `RecModule (_,mb) ->
    mkstr loc (Pstr_recmodule (module_str_bind mb [])) :: l
  | `ModuleType (_,`Uid(sloc,n),mt) ->
    mkstr loc (Pstr_modtype (with_loc n sloc,mtyp mt)) :: l
  | `Open (_,g,id) ->
    mkstr loc (Pstr_open (flag loc g ,long_uident id)) :: l
  | `Type (_,tdl) -> mkstr loc (Pstr_type (mktype_decl tdl )) :: l
  | `TypeWith(_loc,tdl, ns) ->
    (* FIXME all traversal needs to deal with TypeWith later .. *)
    stru (!generate_type_code _loc tdl ns) l
  (* stru (`Sem(_loc,x,code)) l *)

  | `Value (_,rf,bi) ->
    mkstr loc (Pstr_value (mkrf rf,bind bi [])) :: l
  | x-> FLoc.failf loc "stru : %s" (!dump_stru x) 
and cltyp (x:FAst.cltyp) =
  match x with
  | `ClApply(loc, id, tl) -> 
    mkcty loc
      (Pcty_constr
         (long_class_ident (id:>ident),
          List.map (function
              | `Ctyp (_loc,x) -> ctyp x
              | _ -> assert false) (list_of_com tl [])))
  | #vid' as id ->
    let loc = unsafe_loc_of id in
    mkcty loc (Pcty_constr (long_class_ident (id:vid' :> ident), []))
  | `CtFun (loc, (`Label (_, `Lid(_,lab), t)), ct) ->
    mkcty loc (Pcty_fun (lab, ctyp t, cltyp ct))

  | `CtFun (loc, (`OptLabl (loc1, `Lid(_,lab), t)), ct) ->
    let t = `App (loc1, (predef_option loc1), t) in
    mkcty loc (Pcty_fun ("?" ^ lab, ctyp t, cltyp ct))

  | `CtFun (loc,t,ct) -> mkcty loc (Pcty_fun ("" ,ctyp t, cltyp ct))

  | `ObjEnd(loc) ->
    mkcty loc (Pcty_signature {pcsig_self=ctyp (`Any loc);pcsig_fields=[];pcsig_loc=loc})
  | `ObjTyEnd(loc,t) ->
    mkcty loc (Pcty_signature {pcsig_self= ctyp t; pcsig_fields = []; pcsig_loc = loc;})
  | `Obj(loc,ctfl) ->
    let cli = clsigi ctfl [] in
    mkcty loc (Pcty_signature {pcsig_self = ctyp(`Any loc);pcsig_fields=cli;pcsig_loc=loc})
  | `ObjTy (loc,t,ctfl) ->
    let cil = clsigi ctfl [] in
    mkcty loc (Pcty_signature {pcsig_self = ctyp t; pcsig_fields = cil; pcsig_loc =  loc;})
  |  x -> FLoc.failf (unsafe_loc_of x) "class type: %s" (!dump_cltyp x) 

and class_info_clexp (ci:cldecl) =
  match ci with 
  | (`ClDecl(loc,vir,`Lid(nloc,name),params,ce) : cldecl) -> 
    let (loc_params, (params, variance)) =
      (unsafe_loc_of params, List.split (class_parameters params)) in
    {pci_virt = mkvirtual vir;
     pci_params = (params,  loc_params);
     pci_name = with_loc name nloc;
     pci_expr = clexp ce;
     pci_loc =  loc;
     pci_variance = variance}
  | `ClDeclS(loc,vir,`Lid(nloc,name),ce) -> 
    {pci_virt = mkvirtual vir;
     pci_params = ([],  loc);
     pci_name = with_loc name nloc;
     pci_expr = clexp ce;
     pci_loc =  loc;
     pci_variance = []}
  | ce -> FLoc.failf  (unsafe_loc_of ce) "class_info_clexp: %s" (!dump_cldecl ce) 
and class_info_cltyp (ci:cltdecl)  =
  match ci with 
  | (`CtDecl(loc, vir,`Lid(nloc,name),params,ct) :cltdecl) ->
    let (loc_params, (params, variance)) =
      (unsafe_loc_of params, List.split (class_parameters params)) in
    {pci_virt = mkvirtual vir;
     pci_params = (params,  loc_params);
     pci_name = with_loc name nloc;
     pci_expr = cltyp ct;
     pci_loc =  loc;
     pci_variance = variance}
  | (`CtDeclS (loc,vir,`Lid(nloc,name),ct) : cltdecl) -> 
    {pci_virt = mkvirtual vir;
     pci_params = ([],  loc);
     pci_name = with_loc name nloc;
     pci_expr = cltyp ct;
     pci_loc =  loc;
     pci_variance = []}
  | ct -> FLoc.failf (unsafe_loc_of ct) "bad class/class type declaration/definition %s " (!dump_cltdecl ct)
and clsigi (c:clsigi) (l:  class_type_field list) : class_type_field list =
  match c with 
  |`Eq (loc, t1, t2) ->
    mkctf loc (Pctf_cstr (ctyp t1, ctyp t2)) :: l
  | `Sem(_,csg1,csg2) -> clsigi csg1 (clsigi csg2 l)
  | `SigInherit (loc,ct) -> mkctf loc (Pctf_inher (cltyp ct)) :: l
  | `Method (loc,`Lid(_,s),pf,t) ->
    mkctf loc (Pctf_meth (s, mkprivate pf, mkpolytype (ctyp t))) :: l
  | `CgVal (loc, `Lid(_,s), b, v, t) ->
    mkctf loc (Pctf_val (s, mkmutable b, mkvirtual v, ctyp t)) :: l
  | `VirMeth (loc,`Lid(_,s),b,t) ->
    mkctf loc (Pctf_virt (s, mkprivate b, mkpolytype (ctyp t))) :: l
  | t -> FLoc.failf (unsafe_loc_of t) "clsigi :%s" (!dump_clsigi t) 

and clexp  (x:FAst.clexp) :  Parsetree.class_expr =
  let loc = unsafe_loc_of x in
  match x with 
  | `CeApp _ ->
    let rec view_app acc (x:clexp)  =
      match x  with 
      | `CeApp (_loc,ce,(a:exp)) -> view_app (a :: acc) ce
      | ce -> (ce, acc) in
    let (ce, el) = view_app [] x in
    let el = List.map label_exp el in
    mkcl loc (Pcl_apply (clexp ce, el))

  | `ClApply (_,id,tl) ->
    mkcl loc
      (Pcl_constr (long_class_ident (id:>ident),
                   (List.map (function |`Ctyp (_loc,x) -> ctyp x | _ -> assert false)
                       (list_of_com tl []))))
  | #vid' as id  ->
    mkcl loc @@ Pcl_constr (long_class_ident (id : vid' :>ident), [])
  | `CeFun (_, (`Label (_,`Lid(_,lab), po)), ce) ->
    mkcl loc @@ Pcl_fun (lab, None, pat po , clexp ce)
  | `CeFun(_,`OptLablExpr(_,`Lid(_loc,lab),p,e),ce) ->
    let lab = paolab lab p in
    mkcl loc (Pcl_fun ("?" ^ lab,Some (exp e), pat p, clexp ce))
  | `CeFun (_,`OptLabl(_,`Lid(_loc,lab),p), ce) -> 
    let lab = paolab lab p in
    mkcl loc (Pcl_fun ("?" ^ lab, None, pat p, clexp ce))
  | `CeFun (_,p,ce) ->
    mkcl loc (Pcl_fun ("", None, pat p, clexp ce))
  | `LetIn (_, rf, bi, ce) ->
    mkcl loc (Pcl_let (mkrf rf, bind bi [], clexp ce))

  | `ObjEnd _ ->
    mkcl loc (Pcl_structure{pcstr_pat= pat (`Any loc); pcstr_fields=[]})
  | `Obj(_,cfl) ->
    let p = `Any loc in
    let cil = clfield cfl [] in
    mkcl loc (Pcl_structure {pcstr_pat = pat p; pcstr_fields = cil;})
  | `ObjPatEnd(_,p) ->
    mkcl loc (Pcl_structure {pcstr_pat= pat p; pcstr_fields = []})
  | `ObjPat (_,p,cfl) ->
    let cil = clfield cfl [] in
    mkcl loc (Pcl_structure {pcstr_pat = pat p; pcstr_fields = cil;})
  | `Constraint (_,ce,ct) ->
    mkcl loc (Pcl_constraint (clexp ce,cltyp ct))
  | t -> FLoc.failf (unsafe_loc_of t) "clexp: %s" (!dump_clexp t)

and clfield (c:clfield) l =
  let loc = unsafe_loc_of c in 
  match c with
  | `Eq (_, t1, t2) -> mkcf loc (Pcf_constr (ctyp t1, ctyp t2)) :: l
  | `Sem(_,cst1,cst2) -> clfield cst1 (clfield cst2 l)
  | `Inherit (_, ov, ce) ->
    mkcf loc (Pcf_inher (flag loc ov,clexp ce, None)) :: l
  | `InheritAs(_,ov,ce,`Lid(_,x)) ->
    mkcf loc (Pcf_inher (flag loc ov,clexp ce,Some x)) :: l
  | `Initializer (_,e) -> mkcf loc (Pcf_init (exp e)) :: l
  | `CrMthS(loc,`Lid(sloc,s),ov,pf,e) ->
    let e = mkexp loc (Pexp_poly (exp e,None)) in
    mkcf loc (Pcf_meth (with_loc s sloc, mkprivate pf, flag loc ov, e)) :: l
  | `CrMth (_, `Lid(sloc,s), ov, pf, e, t) ->
    let t = Some (mkpolytype (ctyp t)) in
    let e = mkexp loc (Pexp_poly (exp e, t)) in
    mkcf loc (Pcf_meth (with_loc s sloc, mkprivate pf, flag loc ov, e)) :: l
  | `CrVal (_, `Lid(sloc,s), ov, mf, e) ->
    mkcf loc (Pcf_val (with_loc s sloc, mkmutable mf, flag loc ov, exp e)) :: l
  | `VirMeth (_,`Lid(sloc,s),pf,t) ->
    mkcf loc (Pcf_virt (with_loc s sloc, mkprivate pf, mkpolytype (ctyp t))) :: l
  | `VirVal (_,`Lid(sloc,s),mf,t) ->
    mkcf loc (Pcf_valvirt (with_loc s sloc, mkmutable mf, ctyp t)) :: l
  | x  -> FLoc.failf  loc "clfield: %s" @@ !dump_clfield x

let sigi (ast:sigi) : signature = sigi ast []
let stru ast = stru ast []

let directive (x:exp) =
  match x with 
  |`Str(_,s) -> Pdir_string s
  |`Int(_,i) -> Pdir_int (int_of_string i)
  |`Lid(_loc,("true"|"false" as x)) ->
    if x ="true" then Pdir_bool true
    else Pdir_bool false
  | e ->
    let ident_of_exp : FAst.exp -> FAst.ident =
      let error () = invalid_arg "ident_of_exp: this expession is not an identifier" in
      let rec self (x:FAst.exp) : ident =
        let _loc = unsafe_loc_of x in
        match x with 
        | `App(_,e1,e2) -> `Apply(_loc,self e1, self e2)
        | `Field(_,e1,e2) -> `Dot(_loc,self e1,self e2)
        | `Lid _  -> error ()
        | `Uid _ | `Dot _ as i -> (i:vid:>ident)
        (* | `Id (_loc,i) -> if is_module_longident i then i else error () *)
        | _ -> error ()  in 
      function
      | #vid as i ->  (i:vid :>ident)
      | `App _ -> error ()
      | t -> self t  in
    Pdir_ident (ident_noloc (ident_of_exp e)) 

let phrase (x: stru) =
  match x with 
  | `Directive (_, `Lid(_,d),dp) -> Ptop_dir (d ,directive dp)
  | `DirectiveSimple(_,`Lid(_,d)) -> Ptop_dir (d, Pdir_none)
  | `Directive (_, `Ant(_loc,_),_) -> error _loc "antiquotation not allowed"
  | si -> Ptop_def (stru si) 


open Format
let pp = fprintf

let print_exp f  e =
  pp f "@[%a@]@." AstPrint.expression (exp e)
let to_string_exp = to_string_of_printer print_exp
(* let p_ident = eprintf "@[%a@]@." opr#ident ;     *)

let print_pat f e =
  pp f "@[%a@]@." AstPrint.pattern (pat e)

let print_stru f e =
  pp f "@[%a@]@." AstPrint.structure (stru e)

let print_ctyp f e =
  pp f "@[%a@]@." AstPrint.core_type (ctyp e)





(* local variables: *)
(* compile-command: "cd .. && pmake common/ast2pt.cmo" *)
(* end: *)