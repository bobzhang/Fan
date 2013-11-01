%import{
Format:
  eprintf
  ;
Fan_ops:
  list_of_list
  ;
Ast_gen:
  tuple_com
  typing
  and_of_list
  seq_sem
  ;

};;

open FAst
open Util


let print_warning = eprintf "%a:\n%s@." Locf.print

  
let prefix = "__fan_"  
let ghost = Locf.ghost

let module_name =
  ref %exp'@ghost{Gramf} (* BOOTSTRAPING*)  

let gm () =
  match !Configf.compilation_unit with
  |Some "Gramf" (* BOOTSTRAPING*)
    -> `Uid(ghost,"")
  |Some _
  | None -> !module_name

  

let mk_prule ~prod ~action =
  let env = ref [] in
  let inner_env = ref [] in
  let i = ref 0 in 
  let prod =
    Listf.filter_map
      (function  (p:Gram_def.psymbol) ->
        match p with
          (* ? Lid i
             ? Lid 
           *)
        | {kind = KSome;  symbol = ({outer_pattern = None; bounds  ; _} as symbol) } ->
            begin
              inner_env :=
                List.map (fun (xloc,id) -> (%pat@xloc{$lid:id}, %exp@xloc{Some $lid:id}))
                  bounds @ !inner_env;
              incr i;
              Some symbol;
            end
        | {kind = KNormal; symbol} ->
            begin
              incr i;
              Some symbol 
            end
        (* ? Lid i as v 
         *)      
        | {kind = KSome; symbol = ({outer_pattern = Some (xloc,id) ; bounds; _} as s)} ->
            begin 
              env := (%pat@xloc{$lid:id}, %exp@xloc{Some $lid:id } ) :: !env;
              inner_env :=
                List.map (fun (xloc,id) -> (%pat@xloc{$lid:id}, %exp@xloc{Some $lid:id}))
                  bounds @ !inner_env;
              incr i;
              Some s
            end
              
        | {kind = KNone; symbol = {outer_pattern = None ; bounds; _}} ->
            begin
              inner_env :=
                List.map (fun (xloc,id) -> (%pat@xloc{$lid:id}, %exp@xloc{None})) bounds
                @ !inner_env;
              None
            end
        | {kind = KNone; symbol = {outer_pattern = Some (xloc,id); bounds; _}} ->
            begin
              env := (%pat@xloc{$lid:id}, %exp@xloc{None}) :: !env ;
              inner_env :=
                List.map (fun (xloc,id) -> (%pat@xloc{$lid:id}, %exp@xloc{None})) bounds
                @ !inner_env;
              None 
            end) prod in
  ({prod;
    action;
    inner_env = List.rev !inner_env;
    env = List.rev !env}:Gram_def.rule)


let gen_lid ()=
  let gensym  = let i = ref 0 in fun () -> (incr i; i) in
  prefix^string_of_int !(gensym ())
  


      

let rec make_exp (tvar : string) (x:Gram_def.text) =
  let rec aux tvar (x:Gram_def.text) =
    match x with
    | `List (_loc, min, t, ts) ->
        let txt = aux "" t.text in
        (match  ts with
        |  None -> if min then  %exp{ `List1 $txt } else %exp{ `List0 $txt } 
        | Some s ->
            let x = aux tvar s.text in
            if min then %exp{ `List1sep ($txt,$x)} else %exp{ `List0sep ($txt,$x) })
    | `Self _loc ->  %exp{ `Self}
    | `Keyword (_loc, kwd) ->  %exp{ `Keyword $str:kwd }
    | `Nterm (_loc, n, lev) ->
        let obj =
          %exp{ ($id{gm()}.obj
                   (${(n.id:>exp)} : '$lid{n.tvar} $id{(gm(): vid :> ident)}.t ))} in 
        (match lev with
        | Some lab -> %exp{ `Snterml ($obj,$str:lab)}
        | None ->
           if n.tvar = tvar then %exp{ `Self} else %exp{ `Nterm $obj })
    | `Try (_loc, t) -> %exp{ `Try ${aux "" t} }
    | `Peek (_loc, t) -> %exp{ `Peek ${aux "" t} }
    | `Token (_loc, match_fun,  mdescr, mstr ) ->
        %exp{`Token ($match_fun, $mdescr, $str:mstr)} in
  aux  tvar x


and make_exp_rules (_loc:loc)
    (rl : (Gram_def.text list  * exp * exp option) list) (tvar:string) =
  rl
  |> List.map (fun (sl,action,raw) ->
      let action_string =
        match raw with
        | None -> ""
        | Some e -> Ast2pt.to_string_exp e in
      let sl =
        sl
        |> List.map (make_exp tvar)
        |> list_of_list _loc in
      %exp{ ($sl,($str:action_string,$action)) } )
  |> list_of_list _loc

(**********************************************)
(* generate action of the right side   *)
(**********************************************)      
let make_action (_loc:loc)
    (x:Gram_def.rule)
    (rtvar:string)  : exp = 
  let locid = %pat{ $lid{!Locf.name} } in 
  let act = Option.default %exp{()} x.action in

  (* collect the patterns
     it is used for further destruction *)
  let tok_match_pl =
    snd @@
    Listf.fold_lefti
      (fun i ((oe,op) as acc)  x ->
        match (x:Gram_def.symbol) with 
        | {pattern=Some p ; text=`Token _;outer_pattern = None; _ } ->
            let id = prefix ^ string_of_int i in
            ( %exp{$lid:id} :: oe, p:: op)
        | {pattern=Some p ; text=`Token _;outer_pattern = Some (xloc,id) ;_ } ->
            ( %exp@xloc{$lid:id} :: oe, p:: op)
        | {pattern = Some p; text = `Keyword _;outer_pattern = None;  _} ->
            let id = prefix ^ string_of_int i in 
            (%exp{$lid:id}::oe, p :: op) (* TO be improved*)
        | {pattern = Some p; text = `Keyword _;outer_pattern = Some(xloc,id);  _} ->
            (* FIXME when the percent is replaced with '$',  a weird error message*)
            (%exp@xloc{$lid:id}::oe, p::op)
        | _ ->  acc) ([],[])  x.prod in
  let e =
    let binds =
        x.env |> List.map (fun (p,e) -> %bind{$p = $e}) in
    let inner_binds =
      x.inner_env |> List.map (fun (p,e) -> %bind{$p = $e}) in
    let e1 = %exp{ ($act : '$lid:rtvar ) } in
    let e1 = Ast_gen.binds inner_binds e1 in
    let e1 = Ast_gen.binds binds e1 in
    match tok_match_pl with
    | ([],_) ->
        (* let e1 = Ast_gen.binds binds e1  in *)
        %exp{fun ($locid : Locf.t) -> $e1 }
          (* BOOTSTRAPING, associated with module name [Locf] *)
    | (e,p) ->
        let (exp,pat) =
          match (e,p) with
          | ([x],[y]) -> (x,y) | _ -> (tuple_com e, tuple_com p) in
        (* let len = List.length e in *)
        (** it's dangerous to combine generated string with [fprintf] or [sprintf] *)
        (* let error_fmt = String.concat " " (Listf.init len (fun _ -> "%s")) in *)
        (* let es = *)
        (*   (\* BOOTSTRAPING, associated with module name [Tokenf] *\) *)
        (*   List.map (fun x -> %exp{Tokenf.to_string $x}) e in *)
        (* let error = *)
        (*   Ast_gen.appl_of_list ([ %exp{Printf.sprintf }; %exp{$str':error_fmt}]  @ es) in *)
        let e =
          (* Ast_gen.binds binds *)
          if Fan_ops.is_irrefut_pat pat then
            %exp{match $exp with $pat -> $e1}
          else 
            %exp{match $exp with
            | $pat -> $e1 (* record -- irrefutable pattern ? Prove *)
            | _ -> assert false
            (* | _ -> failwith $error *)} in 
        %exp{fun ($locid : Locf.t) (* BOOTSTRAPING, associated with module name [Locf] *) -> $e } in
  let make_ctyp (styp:Gram_def.styp) tvar : ctyp option =
    let module M = struct exception Token end in
    let rec aux  v = 
      match (v:Gram_def.styp) with
      | #vid' as x -> (x : vid' :>ctyp) 
      | `Quote _ as x -> x
      | %ctyp'{ $t2 $t1}-> %ctyp{${aux t2} ${aux t1}}
      | `Self _loc ->
          if tvar = "" then
            Locf.raise _loc @@ Streamf.Error ("S: illegal in anonymous entry level")
          else %ctyp{ '$lid:tvar }
      | `Tok _loc -> raise M.Token
          (* %ctyp{ Tokenf.t } *)  (** BOOTSTRAPPING, associated with module name Tokenf*)
            (* %ctyp{[Tokenf.t]} should be caught as error ealier *)
      | `Type t -> t  in
    try Some (aux styp) with M.Token -> None  in
  let (+:) v ty=
    match ty with
    | Some t -> typing v t
    | None -> v in
  let txt =
    snd @@
    Listf.fold_lefti
      (fun i txt (s:Gram_def.symbol) ->
        let mk_arg p = %pat{~$lid{ prefix ^string_of_int i} : $p } in
        match (s.outer_pattern, s.pattern) with
        | (Some (xloc,id),_)  -> (* (u:Tokenf.t)   *)
            let p =  %pat@xloc{$lid:id} +: make_ctyp s.styp rtvar in
            %exp{ fun ${mk_arg p} -> $txt }
        | (None, Some _) -> (* __fan_i, since we have inner binding*)            
            let p =
              %pat{ $lid{prefix^string_of_int i} } +: make_ctyp s.styp rtvar  in
            %exp{ fun ${mk_arg p} -> $txt }
        | (None,None) -> %exp{ fun ${mk_arg %pat{_}} -> $txt })  e x.prod in
  %exp{ $id{(gm())}.mk_action $txt }


  


(*
  return [(ent,pos,txt)] the [txt] has type [olevel],
  [ent] is something like
  {[
  (module_exp : 'mexp Gramf.t )
  ]}
  [pos] is something like
  {[(Some `LA)]} it has type [position option] *)
    
let make_extend safe  (e:Gram_def.entry) :exp =  with exp
  let _loc = e.name.loc in
  let gmid = (gm():vid:>ident) in
  let ent =
    %exp{(${(e.name.id :> exp)}:'$lid{e.name.tvar} $id:gmid.t)  }   in
  let pos = (* hastype Gramf.position option *)
    match e.pos with
    | Some pos -> %exp{Some $pos} 
    | None -> %exp{None}   in
  let apply (level:Gram_def.level)  =
    let lab =
      match level.label with 
      | Some lab ->   %exp{Some $str:lab}
      | None ->   %exp{None}   in
    let ass =
      match level.assoc with (* has type Gramf.assoc option *)
      | Some ass ->   %exp{Some $ass}
      | None ->    %exp{None}   in
    (* the [rhs] was already computed, the [lhs] was left *)
    let rl =
      level.rules 
      |> List.map
          (fun (r:Gram_def.rule) ->
          let sl =
            r.prod
            |> List.map (fun (s:Gram_def.symbol) -> s.text) in
          (sl,
           make_action _loc r e.name.tvar, (* compose the right side *)
           r.action)) in
    let prod = make_exp_rules _loc rl e.name.tvar in
    (* generated code of type [olevel] *)
    %exp{ ($lab, $ass, $prod) } in
  match e.levels with
  |`Single l ->
      let f =
        if safe then
          %exp{$id{gm()}.extend_single}
        else %exp{$id{gm()}.unsafe_extend_single} in
        %exp{$f $ent ($pos, (${apply l} : $id{(gm() : vid :> ident)}.olevel ))}
  |`Group ls ->
      let txt = list_of_list _loc (List.map apply ls) in
      let f =
        if safe then %exp{$id{gm()}.extend}
        else %exp{$id{gm()}.unsafe_extend} in
      %exp{$f $ent ($pos, ($txt : $id{(gm() : vid :>ident)}.olevel list))}



      
(* We don't do any parsing for antiquots here, so it's parser-independent *)  
let capture_antiquot  = object
  inherit Objs.map as super
  val mutable constraints : (exp * exp) list  =[]
  method! pat = function
    | `Ant(_loc,s) -> 
        begin
          let code = s.txt in
          let cons = %exp{ $lid:code } in
          let code' = "__fan__"^code in  (* prefix "fan__" FIXME *)
          let cons' = %exp{ $lid:code' } in 
          let () = constraints <- (cons,cons')::constraints in 
          %pat{ $lid:code' } (* only allows lidentifiers here *)
        end
    | p -> super#pat p 
  method get_captured_variables =
    constraints
  method clear_captured_variables =
    constraints <- []
end

let filter_pat_with_captured_variables pat= begin 
  capture_antiquot#clear_captured_variables;
  let pat=capture_antiquot#pat pat in
  let constraints = capture_antiquot#get_captured_variables in
  (pat,constraints)
end

(* let free_vars  = object *)
(*   inherit Objs.map as super *)
(*   method! exp (x:exp) = *)
(*     match x with *)
(*     | `Ant(_, (s:Tokenf.ant)) -> *)
        
(*     | p  -> super#exp p  *)
(* end *)
(* %exp{A.B.C.d.$x}     *)
(** [gl] is the name  list option

   {[
   loc -> ident option ->exp name list option ->
   (exp, 'a) entry list -> exp -> exp
   ]}

   This function generate some local entries *)               
let combine _loc (gram: vid option ) locals  extends  =
  let entry_mk =
    match gram with
    | Some g ->
        let g = (g:vid :> exp) in
        %exp{ $id{gm()}.mk_dynamic $g }
    | None -> %exp{ $id{gm()}.mk} in
  let local_bind_of_name (x:Gram_def.name) =
    match (x:Gram_def.name) with 
    | {id = `Lid (_,i) ; tvar = x; loc = _loc} ->
        %bind{ $lid:i =
               (grammar_entry_create $str:i : '$lid:x $id{(gm():vid :> ident)}.t )}
    | _  -> failwithf "internal error in the Grammar extension %s"
          (Objs.dump_vid x.id)   in
  match locals with
  | [] -> extends
  | ll ->
      let locals =
        ll |> List.map local_bind_of_name |> and_of_list in
      (** eta-expansion to avoid specialized types here  *)
      %exp{
      let grammar_entry_create x = $entry_mk  x in
      let $locals in
      $extends }    
    
(** entrance *)        
let make  _loc (x:Gram_def.entries) = 
  let extends =
    let el =
      x.items |> List.map (make_extend x.safe)    in
    match el with
    | [] ->  %exp{ () }
    | _ -> seq_sem el    in
  let locals  = (** FIXME the order matters here, check duplication later!!! *)
     x.items
     |> Listf.filter_map
         (fun (x:Gram_def.entry) -> if x.local then Some x.name else None ) in
  combine _loc x.gram locals extends




(* local variables: *)
(* compile-command: "cd .. && pmake main_annot/compile_gram.cmo " *)
(* end: *)
