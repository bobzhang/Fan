open Structure;
open LibUtil;
let get_cur_loc = Tools.get_cur_loc;
let get_prev_loc = Tools.get_prev_loc;
(* [bp] means begining position, [ep] means ending position
   apply the [parse_fun] and get the result and the location of
   consumed areas
 *)
let add_loc bp parse_fun strm =
  let x = parse_fun strm in
  let ep = get_prev_loc strm in
  let loc =
    if FanLoc.start_off bp > FanLoc.stop_off ep then
      (* If nothing has been consumed, create a 0-length location. *)
      FanLoc.join bp
    else
      FanLoc.merge bp ep in
  (x, loc);


(* given a level string, return a number from 0 *)  
let level_number entry lab =
  let rec lookup levn = fun
    [ [] -> failwith ("unknown level " ^ lab)
    | [lev :: levs] ->
        if Tools.is_level_labelled lab lev then levn else lookup (succ levn) levs ] in
  match entry.edesc with
  [ Dlevels elev -> lookup 0 elev
  | Dparser _ -> raise Not_found ] ;
    

(* pomote the level to top *)
let rec top_symb entry =fun
  [ `Sself | `Snext -> `Snterm entry
  | `Snterml (e, _) -> `Snterm e
  | `Slist1sep (s, sep) -> `Slist1sep ((top_symb entry s), sep)
  | _ -> raise Stream.Failure ];

(* given an entry and a tree return the top tree *)  
let top_tree entry = fun
  [ Node ({node = s; _} as x) ->
    Node ({(x) with node = top_symb entry s})
  | LocAct _ _ | DeadEnd -> raise Stream.Failure ];

let entry_of_symb entry = fun
  [ `Sself | `Snext -> entry
  | `Snterm e -> e
  | `Snterml (e, _) -> e
  | _ -> raise Stream.Failure ] ;




  
let continue entry  s son (p1:parse Action.t) loc a = parser
  [[< a = (entry_of_symb entry s).econtinue 0 loc a;
     act = p1 ?? Failed.tree_failed entry a s son >] ->
       Action.mk (fun _ -> Action.getf act a) ];

(* PR#4603, PR#4330, PR#4551:
   Here get_cur_loc replaced get_prev_loc to fix all these bugs.
   If you do change it again look at these bugs. *)
let skip_if_empty bp strm =
  if get_cur_loc strm = bp then
    Action.mk (fun _ -> raise Stream.Failure)
  else
    raise Stream.Failure ;


(* in case of syntax error, the system attempts to recover the error by applying
   the [continue] function of the previous symbol(if the symbol is a call to an entry),
   so there's no behavior difference between [LA] and [NA]
 *)
let do_recover ~from_tree entry s son loc a = parser
  [ [<b = from_tree (top_tree entry son) >] -> b
  | [<b = skip_if_empty loc >] -> b
  | [<b = continue entry s son (from_tree son) loc a >] -> b];
    
let recover  ~from_tree entry  s son loc a strm =
  if !FanConfig.strict_parsing then
    raise (Stream.Error (Failed.tree_failed entry a s son))
  else
    let _ =
      if !FanConfig.strict_parsing_warning then begin
        let msg = Failed.tree_failed entry a s son;
          Format.eprintf "Warning: trying to recover from syntax error";
          if entry.ename <> "" then Format.eprintf " in [%s]" entry.ename else ();
          Format.eprintf "\n%s%a@." msg FanLoc.print loc;
      end else () in
    do_recover ~from_tree entry  s son loc a strm ;

let rec parser_cont  ~from_tree entry s son p1 loc a =  parser
  [ [< b = p1 >] -> b
  | [< b = recover ~from_tree entry s son loc a >] -> b
  | [< >] -> raise (Stream.Error (Failed.tree_failed entry a s son)) ]

(*
  It outputs a stateful parser, but it is functional itself
 *)    
and parser_of_tree entry (lev,assoc) x =
  let alevn = match assoc with
    [`LA|`NA -> lev + 1 | `RA -> lev ] in
  let rec from_tree  = fun 
  [ DeadEnd -> raise Stream.Failure
  | LocAct act _ -> parser [< >] -> act
  (* rules ending with [SELF] or with the current entry name, for this last symbol
     there's a call to the [start] function: of the current level if the level is
     [`RA] or of the next level otherwise. (This can be verified by
     [start_parser_of_levels]) *)      
  | Node {node = `Sself; son = LocAct act _; brother = bro}
    ->  parser
        [ [< a = entry.estart alevn >] -> Action.getf act a
        | [< a = from_tree bro >] -> a ]
  (* [son] will never be [DeadEnd] *)        
  | Node ({node ; son; brother } as y) ->
      match Tools.get_terminals  y with
      [ None ->
        let ps = parser_of_symbol entry node  lev  in
        let p1 = from_tree son |> parser_cont  ~from_tree entry  node son in
        fun strm ->
          let bp = get_cur_loc strm in
          match strm with parser
          [ [< a = ps; act = p1 bp a >] -> Action.getf act a
          | [< a = from_tree brother >] -> a ]
      | Some (tokl, last_tok, son) ->
          let p1 =
            from_tree son
            |> parser_cont  ~from_tree entry  (last_tok:>symbol) son
            |>  LL.parser_of_terminals  tokl in 
          parser
            [ [< a = p1 >] -> a
            | [< a = from_tree brother >] -> a ] ] ] in
  from_tree x 

and parser_of_terminals
    (terminals:list terminal ) (cont:cont_parse Action.t) (strm:token_stream) =
  let bp = Tools.get_cur_loc strm in (* FIXME more precise Location *)
  let rec p ?(first=true) (acc:list FanSig.token) (ts:list terminal) =
    match ts with
    [ [] -> acc
    | [x::xs] ->
        match strm with parser
        [[< (t,_) when
          match x with [`Stoken(f,_) -> f t | `Skeyword kwd -> FanToken.match_keyword kwd t] >] ->   
            p  ~first:false [t::acc] xs
        |[<>] -> 
           if first then raise Stream.Failure
           else raise (Stream.Error "")]]in

  let (ts:list FanSig.token) = p [] terminals in
      match ts with
      [ [] -> invalid_arg "parser_of_terminals"
      | [x::_] ->
          let action = Obj.magic cont bp (Action.mk x) strm in
          List.fold_left
            (fun a arg -> Action.getf a arg)
            action ts ]  
(* only for [Smeta] it might not be functional *)
and parser_of_symbol entry s nlevn =
  let rec aux s = 
    match s with 
   [ `Smeta _ symbls act ->
     let act = Obj.magic act entry symbls and pl = List.map aux symbls in
     Obj.magic (List.fold_left (fun act p -> Obj.magic act p) act pl)
   | `Slist0 s ->
     let ps = aux s in  Comb.slist0 ps ~f:(fun l -> Action.mk (List.rev l))
   | `Slist0sep (symb, sep) ->
     let ps = aux symb and pt =  aux sep  in
     Comb.slist0sep ps pt ~err:(fun v -> Failed.symb_failed entry v sep symb)
       ~f:(fun l -> Action.mk (List.rev l))
   | `Slist1 s -> let ps =  aux s  in
     Comb.slist1 ps ~f:(fun l -> Action.mk (List.rev l))
   | `Slist1sep (symb, sep) ->
     let ps = aux symb and pt = aux sep  in
     let rec kont al = parser
       [ [< v = pt; a = parser
         [ [< a = ps >] -> a
         | [< a = parse_top_symb entry symb >] -> a
         | [< >] ->
             raise (Stream.Error (Failed.symb_failed entry v sep symb)) ];
           's >] ->kont [a :: al] s
         | [< >] -> al ] in
     parser [< a = ps; 's >] -> Action.mk (List.rev (kont [a] s))
  | `Sopt s ->
      let ps = aux s  in
      Comb.opt ps ~f:Action.mk
  | `Stry s -> let ps = aux s in Comb.tryp ps
  | `Stree t ->
      let pt = parser_of_tree entry (0, `RA)  t (* FIXME*) in
      fun strm ->
        let bp = get_cur_loc strm in
        match strm with parser
        [ [< (act, loc) = add_loc bp pt >] ->  Action.getf act loc]
  | `Snterm e -> parser [< a = e.estart 0 >] -> a
  | `Snterml (e, l) -> parser [< a = e.estart (level_number e l) >] -> a
  | `Sself -> parser [< a = entry.estart 0 >] -> a
  | `Snext -> parser [< a = entry.estart (nlevn+1) >] -> a
  | `Skeyword kwd -> parser
        [ [< (tok, _) when FanToken.match_keyword kwd tok >] ->
          Action.mk tok ]
  | `Stoken (f, _) ->
     parser [ [< (tok,_) when f tok >] -> Action.mk tok ]] in
  aux s
and parse_top_symb entry symb  =
  parser_of_symbol entry (top_symb entry symb) 0 ;


(* entrance for the start
   [clevn] is the current level 
 *)  
let start_parser_of_levels entry =
  let rec aux clevn : list level -> int -> parse Action.t =  fun
    [ [] -> fun _ -> parser [] 
    | [lev :: levs] ->
        let hstart = aux  (clevn+1) levs in
        match lev.lprefix with
        [ DeadEnd -> hstart (* try the upper levels *)
        | tree ->
          let cstart = 
            parser_of_tree entry (clevn, lev.assoc) tree  in
          (* the [start] function tires its associated tree. If it works
             it calls the [continue] function of the same level, giving the
             result of [start] as parameter.
             If this continue fails, the parameter is simply returned.
             If this [start] function fails, the start function of the
             next level is tested, if there is no more levels, the parsing fails
           *)    
          fun levn strm ->
            if levn > clevn && (not ([]=levs))then
              hstart levn strm (* only higher level allowed here *)
            else
              let bp = get_cur_loc strm in
              match strm with parser
              [ [< (act, loc) = add_loc bp cstart >] ->
                let a = Action.getf act loc in
                entry.econtinue levn loc a strm
              | [< act = hstart levn >] -> act ] ] ] in
  aux 0;
  
let start_parser_of_entry entry =
  debug gram "start_parser_of_entry: @[<2>%a@]@." Print.text#entry entry in
  match entry.edesc with
  [ Dlevels [] -> Tools.empty_entry entry.ename
  | Dlevels elev -> start_parser_of_levels entry  elev
  | Dparser p -> fun _ -> p ] ;
    


let rec continue_parser_of_levels entry clevn = fun
  [ [] -> fun _ _ _ -> parser []
  | [lev :: levs] ->
      let hcontinue = continue_parser_of_levels entry  (clevn+1) levs in
      match lev.lsuffix with
      [ DeadEnd -> hcontinue
          (* the continue function first tries the [continue] function of the next level,
             if it fails or if it's the last level, it tries its associated tree, then
             call itself again, giving the result as parameter. If the associated tree
             fails, it returns its extra parameter
           *)
      | tree ->
        let ccontinue = parser_of_tree entry (clevn, lev.assoc) tree in
        fun levn bp a strm ->
          if levn > clevn then
            hcontinue levn bp a strm
          else
            match strm with parser
            [ [< act = hcontinue levn bp a >] -> act
            | [< (act, loc) = add_loc bp ccontinue >] ->
                let a = Action.getf2 act a loc in
                entry.econtinue levn loc a strm ] ] ];

  
let continue_parser_of_entry entry =
  debug gram "continue_parser_of_entry: @[<2>%a@]@." Print.text#entry entry in
  match entry.edesc with
  [ Dlevels elev ->
    let p = continue_parser_of_levels entry 0 elev in
    fun levn bp a -> parser
    [ [< a = p levn bp a >] -> a
    | [< >] -> a ]
  | Dparser _ -> fun _ _ _ -> parser [] ];

