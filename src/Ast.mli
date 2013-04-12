(* Note: when you modify these types you must increment
   ast magic numbers defined in FanConfig.ml.
   Todo:
   add phantom type to track some type invariants?
 *)
(*

    It provides:
      - Types for all kinds of structure.
      - Map: A base class for map traversals.
      - Map classes and functions for common kinds.

    == Core language ==
    ctyp               :: Representaion of types
    pat               :: The type of patterns
    exp               :: The type of expressions
    case         :: The type of cases for match/function/try constructions
    ident              :: The type of identifiers (including path like Foo(X).Bar.y)
    binding            :: The type of let bindings
    rec_exp        :: The type of record definitions

    == Modules ==
    mtyp        :: The type of module types
    sigi           :: The type of signature items
    stru           :: The type of structure items
    mexp        :: The type of module expressions
    mbind     :: The type of recursive module definitions
    constr        :: The type of `with' constraints

    == Classes ==
    cltyp         :: The type of class types
    class_sigi     :: The type of class signature items
    clexp         :: The type of class expressions
    cstru     :: The type of class structure items
 *)


type loc = FanLoc.t;
type ant = [= `Ant of (loc * FanUtil.anti_cxt)];
type nil = [= `Nil of loc];


type literal =
  [= `Chr of (loc * string)
  | `Int of (loc * string)
  | `Int32 of (loc * string)
  | `Int64 of (loc * string)
  | `Flo of (loc * string)
  | `Nativeint of (loc * string)
  | `Str of (loc * string)];   

type rec_flag =
  [= `Recursive of loc 
  | `ReNil of loc 
  | ant];

type direction_flag =
  [= `To of loc
  | `Downto of loc
  | ant ];

type mutable_flag =
  [= `Mutable of loc 
  | `MuNil of loc 
  | ant ];

type private_flag =
  [= `Private of loc 
  | `PrNil of loc 
  | ant ];

type virtual_flag =
  [= `Virtual of loc 
  | `ViNil of loc 
  | ant ];


type override_flag =
  [= `Override of loc 
  | `OvNil of loc 
  | ant ];

type row_var_flag =
  [= `RowVar of loc 
  | `RvNil of loc 
  | ant ];

type position_flag =
  [= `Positive of loc
  | `Negative of loc
  | `Normal of loc
  |ant];


type strings =
  [= `App of (loc * strings * strings)
  | `Str of (loc * string)
  | ant  ]  ;

type alident =
  [= `Lid of (loc * string)
  | ant];

type auident =
  [= `Uid of (loc * string)
  | ant];

type aident =
  [= alident
  | auident ];

type astring =
  [= `C of (loc * string)
  | ant ];

type uident =
  [= `Dot of (loc * uident * uident)
  | `App of (loc * uident * uident)
  | auident];

type ident =
  [= `Dot of (loc * ident * ident)
  | `Apply of (loc * ident * ident) 
  | alident
  | auident];

(* same as ident except without [outer-ant] *)
type ident'=
  [= `Dot of (loc * ident * ident)
  | `Apply of (loc * ident * ident )
  | `Lid of (loc * string)
  | `Uid of (loc * string)];

type vid =
  [= `Dot of (loc * vid * vid)
  | `Lid of (loc * string)
  | `Uid of (loc * string) | ant ];

type vid'=
  [= `Dot of (loc * vid * vid)
  | `Lid of (loc * string)
  | `Uid of (loc * string) ];

type dupath =
  [= `Dot of (loc * dupath * dupath)
  | auident];

type dlpath=
  [= `Dot of (loc * dupath * alident)
  | alident];


type any = [= `Any of loc];
(* type type_quote = *)
(*   [= `Quote of (loc * position_flag * alident) *)
(*   | `QuoteAny of (loc * position_flag) | any | ant ]; *)

(* type sid = [= `Id of (loc * ident)]; *)


type ctyp =
  [= `Alias of (loc * ctyp * alident)
  | any
  | `App of (loc * ctyp * ctyp) (* t t *) (* list 'a *)
  | `Arrow of (loc * ctyp * ctyp)
  | `ClassPath of (loc * ident) (* #i *) (* #point *)
  | `Label of (loc * alident * ctyp) (* ~s:t *)
  | `OptLabl of (loc * alident * ctyp ) (* ?s:t *)
  | ident'

    (* < (t)? (..)? > *) (* < move : int -> 'a .. > as 'a  *)
  | `TyObj of (loc * name_ctyp * row_var_flag )
  | `TyObjEnd of (loc * row_var_flag)

  | `TyPol of (loc * ctyp * ctyp) (* ! t . t *) (* ! 'a . list 'a -> 'a *)
  | `TyPolEnd of (loc *ctyp) (* !. t *)  
  | `TyTypePol of (loc * ctyp * ctyp) (* type t . t *) (* type a . list a -> a *)

  (*  +'s -'s 's +_ -_ *)      
  | `Quote of (loc * position_flag * alident)
  | `QuoteAny of (loc * position_flag )
  | `Par of (loc * ctyp) (* ( t ) *) (* (int * string) *)
  | `Sta of (loc * ctyp * ctyp) (* t * t *)
  | `PolyEq of (loc * row_field)
  | `PolySup of (loc * row_field )
  | `PolyInf of (loc * row_field)
  | `Com of (loc * ctyp * ctyp)
  | `PolyInfSup of (loc * row_field * tag_names)
  | `Package of (loc * mtyp) (* (module S) *)
  | ant ]
and type_parameters =
  [= `Com of (loc * type_parameters * type_parameters)
  | `Ctyp of (loc * ctyp)
  | ant]  
and row_field =
  [= ant
  | `Bar of (loc * row_field * row_field )
  | `TyVrn of (loc * astring)
  | `TyVrnOf of (loc * astring * ctyp)
  | `Ctyp of (loc * ctyp)]
and tag_names =
  [= ant
  | `App of (loc * tag_names * tag_names)
  | `TyVrn of (loc * astring )]   
and typedecl =
    (* {:stru| type  ('a, 'b, 'c) t = t |} *)
  [= `TyDcl of (loc * alident * opt_decl_params * type_info * opt_type_constr)
  | `TyAbstr of (loc * alident * opt_decl_params * opt_type_constr ) 
  | `And of (loc * typedecl * typedecl)
  | ant ]
(* original syntax
   {[ type v = u = A of int ]}
   revise syntax
   {[ type v = u = [A of int];]} *)
and type_constr =
  [= `And of (loc * type_constr * type_constr)
  | `Eq of (loc * ctyp * ctyp)
  | ant ]
and opt_type_constr =
 [= `Some of (loc * type_constr) (* changed to some and None later *)
 | `None of loc ]
and decl_param =
  [=  `Quote of (loc * position_flag * alident)
  | `QuoteAny of (loc * position_flag )
  | `Any of loc | ant]
and decl_params =
 [= `Quote of (loc * position_flag * alident)
  | `QuoteAny of (loc * position_flag )
  | `Any of loc 
  | `Com of (loc  * decl_params * decl_params) | ant]
      
and opt_decl_params =
 [= `Some of (loc * decl_params)
 | `None of loc  ]   
and type_info =        (* FIXME be more preicse *)
  [= (* type u = v = [A of int ] *)
   `TyMan of (loc  * ctyp * private_flag  * type_repr)
     (* type u = A.t = {x:int} *)
  | `TyRepr of (loc * private_flag * type_repr)
  | `TyEq of (loc * private_flag * ctyp) (* type u = int *)
  | ant]  
and type_repr =
  [= `Record of (loc * name_ctyp)
  | `Sum of (loc * or_ctyp)
  | ant]
and name_ctyp =
  [= `Sem of (loc * name_ctyp * name_ctyp)
  | `TyCol of (loc * alident * ctyp )
  | `TyColMut of (loc * alident * ctyp)
  | ant]
and or_ctyp =
  [= `Bar of (loc * or_ctyp * or_ctyp )
  | `TyCol of (loc * auident * ctyp)
  | `Of of (loc * auident * ctyp)
  | auident  ]
and of_ctyp = (* For exception definition*)
  [= `Of of (loc * vid * ctyp)
  | vid'
  | ant]
and pat =
  [=  vid
  | `App of (loc * pat * pat)
  | `Vrn of (loc * string)
  | `Com of (loc * pat * pat)
  | `Sem of (loc * pat * pat)
  | `Par of (loc * pat )
  | any
  | `Record of (loc * rec_pat)
  | literal
  | `Alias of (loc * pat * alident)
  | `ArrayEmpty of loc 
  | `Array of (loc * pat) (* [| p |] *)
  | `LabelS of (loc * alident) (* ~s *)
  | `Label of (loc * alident * pat) (* ~s or ~s:(p) *)
  | `OptLabl of (loc * alident * pat) (* ?s or ?s:(p)   *)
  | `OptLablS of (loc * alident)
    (* ?s:(p = e) or ?(p = e) *)
  | `OptLablExpr of (loc * alident * pat * exp)
  | `Bar of (loc * pat * pat) (* p | p *)
  | `PaRng (* `Range  *)of (loc * pat * pat) (* p .. p *)
  | `Constraint of (loc * pat * ctyp) (* (p : t) *)
  | `ClassPath of (loc * ident) (* #i *)
  | `Lazy of (loc * pat) (* lazy p *)
  | `ModuleUnpack of (loc * auident)
  | `ModuleConstraint of (loc * auident * ctyp) ]
and rec_pat =
  [= `RecBind of (loc * ident * pat)
  | `Sem of (loc  * rec_pat * rec_pat)
  | any
  | ant]  
and exp =
  [=  vid
  | `App of (loc * exp * exp)
  | `Vrn of (loc * string)
  | `Com of (loc * exp * exp)
  | `Sem of (loc * exp * exp)
  | `Par of (loc * exp)
  | any
  | `Record of (loc * rec_exp)
  | literal
      (* { (e) with rb }  *)
  | `RecordWith of (loc * rec_exp  * exp)
        (* FIXME give more restrict for the e *)         
  | `Field of (loc * exp * exp) (* e.e *)
  | `ArrayDot of (loc * exp * exp) (* e.(e) *)
  | `ArrayEmpty of loc 
  | `Array of (loc * exp) (* [| e |] *)
  | `Assert of (loc * exp) (* assert e *)
  | `Assign of (loc * exp * exp) (* e := e *)
        (* for s = e to/downto e do { e } *)
  | `For of (loc * alident * exp * exp * direction_flag * exp)
  | `Fun of (loc * case) (* fun [ mc ] *)
  | `IfThenElse of (loc * exp * exp * exp) (* if e then e else e *)
  | `IfThen of (loc * exp * exp) (* if e then e *)
  | `LabelS of (loc * alident) (* ~s *)
  | `Label of (loc * alident * exp) (* ~s or ~s:e *)
  | `Lazy of (loc * exp) (* lazy e *)
  | `LetIn of (loc * rec_flag * binding * exp)
  | `LetTryInWith of (loc * rec_flag * binding * exp * case)        
  | `LetModule of (loc * auident * mexp * exp) (* let module s = me in e *)
  | `Match of (loc * exp * case) (* match e with [ mc ] *)
  | `New of (loc * ident) (* new i *)
  | `Obj of (loc * cstru) (* object ((p))? (cst)? end *)
  | `ObjEnd of loc 
  | `ObjPat of (loc * pat * cstru)
  | `ObjPatEnd of (loc * pat)
  | `OptLabl of (loc *alident * exp) (* ?s or ?s:e *)
  | `OptLablS of (loc * alident)
  | `OvrInst of (loc * rec_exp) (* {< rb >} *)
  | `OvrInstEmpty of loc
  | `Seq of (loc * exp) (* do { e } *)
  | `Send of (loc * exp * alident) (* e#s *)
  | `StringDot of (loc * exp * exp) (* e.[e] *)
  | `Try of (loc * exp * case) (* try e with [ mc ] *)
  | `Constraint of (loc * exp * ctyp) (*(e : t) *)
  | `Coercion of (loc * exp * ctyp * ctyp) (* or (e : t :> t) *)
  | `Subtype of (loc * exp * ctyp) (* (e :> t) *)
  | `While of (loc * exp * exp)
  | `LetOpen of (loc * ident * exp)
        (* fun (type t) -> e *)
        (* let f x (type t) y z = e *)
  | `LocalTypeFun of (loc *  alident * exp)
        (* (module ME : S) which is represented as (module (ME : S)) *)
  | `Package_exp of (loc * mexp) ]
and rec_exp =
  [= `Sem of (loc * rec_exp * rec_exp)
  | `RecBind  of (loc * ident * exp)
  | any (* Faked here to be symmertric to rec_pat *)
  | ant ]

(*
  http://caml.inria.fr/pub/docs/manual-ocaml/manual018.html
 *)          
and mtyp =
  [= ident'
  | `Sig of (loc * sigi)
  | `SigEnd of loc
  | `Functor of (loc * auident * mtyp * mtyp)
  | `With of (loc * mtyp * constr) (* mt with wc *)

  (*
    http://caml.inria.fr/pub/docs/manual-ocaml/manual021.html#toc82
   *)      
  | `ModuleTypeOf of (loc * mexp)
  | ant  ]
and sigi =
  [=
      `Val of (loc * alident * ctyp)
    (* BNF for external_declaration is missing in OCaml manual
       primitive_declaration:
       | STRING                                      { [$1] }
       | STRING primitive_declaration                { $1 :: $2 } *)
  | `External of (loc * alident  * ctyp * strings) (* external s : t = s ... s *)
  | `Type of (loc * typedecl)
  | `Exception of (loc * of_ctyp) (* exception t *)

  | `Class of (loc * cltyp)
  | `ClassType of (loc * cltyp) (* class type cict *)

  | `Module of (loc * auident * mtyp) (* module s : mt *)

    (*
      Support in parser [module_declaration]
      | `ModuleApp of (loc * auident * mtbind * mtyp) *)
        
  | `ModuleTypeEnd of (loc * auident)
  | `ModuleType of (loc * auident * mtyp) (* module type s = mt *)

        
  | `Sem of (loc * sigi * sigi)
  | `DirectiveSimple of (loc * alident) (* # s or # s e *)
  | `Directive of (loc * alident * exp) (* semantics *)

  | `Open of (loc * ident)
  | `Include of (loc * mtyp)
  | `RecModule of (loc * mbind) (* module rec mb *)
        
  | ant  ]
(*
and mtbind =
  [= `App of (loc * mtbind * mtbind )
  | `Col of (auident * mtyp)
  | ant ]
*)          
and mbind =
(* module rec (s : mt) = me and (s : mt) = me *)
  [= `And of (loc * mbind * mbind)
  | `ModuleBind  of (loc *  auident * mtyp * mexp) (* s : mt = me *)
  | `Constraint  of (loc * auident * mtyp) (* s : mt *)
  | ant ]
          
and constr =
  [=
   `TypeEq of (loc * ctyp * ctyp)
  | `ModuleEq of (loc * ident * ident)
        
  | `TypeEqPriv of (loc * ctyp * ctyp)
  | `TypeSubst of (loc * ctyp * ctyp)
        
  | `ModuleSubst of (loc * ident * ident)
  | `And of (loc * constr * constr)
  | ant  ]
(* let-binding	::=	pattern =  exp  
    value-name  { parameter }  [: typexp] =  exp  
   value-name : type  { typeconstr } .  typexp =  exp
   *)           
and binding =
  [=  `And of (loc * binding * binding)
  | `Bind  of (loc * pat * exp)
  | ant  ]
and case =
  [= `Bar of (loc * case * case)
  | `Case of (loc * pat * exp)
  | `CaseWhen of (loc * pat * exp * exp)
  | ant  ]
and mexp =
  [= vid' 
  | `App of (loc * mexp * mexp) (* me me *)
  | `Functor of (loc * auident * mtyp * mexp)
  | `Struct of (loc * stru)
  | `StructEnd of loc 
  | `Constraint of (loc * mexp * mtyp) (* (me : mt) *)
        (* (value e) *)
        (* (value e : S) which is represented as (value (e : S)) *)
  | `PackageModule of (loc * exp)
  | ant  ]
and stru =
  [= `Class of (loc * clexp) (* class cice *)
  | `ClassType of (loc * cltyp) (* class type cict *)
  | `Sem of (loc * stru * stru)
  | `DirectiveSimple of (loc * alident)
  | `Directive of (loc * alident * exp)
  (* exception t or exception t = i *)
  (* | `Exception of ( loc * ctyp * meta_option(\*FIXME*\) ident) *)
  | `Exception of ( loc * of_ctyp)
        (* TODO ExceptionRebind
           http://caml.inria.fr/pub/docs/manual-ocaml/manual016.html
         *)     
  | `StExp of (loc * exp)
  | `External of (loc * alident  * ctyp *  strings)
  | `Include of (loc * mexp)
  | `Module of (loc * auident * mexp)
  | `RecModule of (loc * mbind)
  | `ModuleType of (loc * auident * mtyp) (* module type s = mt *)
  | `Open of (loc * ident) (* open i *)
  | `Type of (loc * typedecl) (* type t *)
  | `Value of (loc * rec_flag * binding) (* value (rec)? bi *)
  | ant  ]

(*
  classtype-definition ::=
    class type classtype-def {and classtype-def}
  
  classtype-def ::=
    [virtual] [[type-parameters]] class-name = class-body-type

  class-type ::=
      class-body-type
    | [[?]label-name:] typexpr -> class-type

  class-body-type
      ::= object [(typexpr)] {class-field-spec} end
      | class-path
      | [ typexpr {,typexpr} ] class-path



  class_type_declaration:  virtual_flag class_type_parameters
  LIDENT EQUAL  class_signature

  class_signature:
    LBRACKET core_type_comma_list RBRACKET clty_longident
  | clty_longident
  | OBJECT class_sig_body END
  class_sig_body: class_self_type class_sig_fields
 *)    
and cltyp = (* class body type *)         
  [= 
   `ClassCon of (loc * virtual_flag * ident *  type_parameters)
       (* (virtual)? i [ t ] *)
  | `ClassConS of (loc * virtual_flag * ident)
        (* (virtual)? i *)
  | `CtFun of (loc * ctyp * cltyp)
        (* [t] -> ct *)
  | `ObjTy of (loc * ctyp * clsigi) (*object (ty) ..  end*)
  | `ObjTyEnd of (loc * ctyp) (*object (ty) end*)
  | `Obj of (loc * clsigi) (* object ... end *)
  | `ObjEnd of (loc) (* object end*)
  | `And of (loc * cltyp * cltyp)
  | `CtCol of (loc * cltyp * cltyp) (* ct : ct *)
  | `Eq  of (loc * cltyp * cltyp) (* ct = ct *)
  | ant ]

(* and clfun = [`Fun of (loc * ctyp * cltyp)]
   class_signature:
    LBRACKET core_type_comma_list RBRACKET clty_longident
  | clty_longident
  | OBJECT class_sig_body END
  | OBJECT class_sig_body error
   class-field-sec 
   ::= inherit class-type
   | val [mutable] [virtual] inst-var-name : typexpr
   | method [private] method-name : poly-typeexpr
   | method [private] virtual method-name : poly-typexpr
   | constraint typeexpr = typeexpr 
 *)
and clsigi =
  [= 
    `Sem of (loc * clsigi * clsigi)
  | `SigInherit of (loc * cltyp)

        (* val (virtual)? (mutable)? s : t *)
  | `CgVal of (loc * alident * mutable_flag * virtual_flag * ctyp)
      (* method s : t or method private s : t *)
  | `Method of (loc * alident * private_flag * ctyp)
      (* method virtual (private)? s : t *)
  | `VirMeth of (loc *  alident * private_flag * ctyp)
  | `Eq of (loc * ctyp * ctyp)        
  | ant ]
(* and clfieldi = *)
(*   [= `InheritI of (loc * clsigi) *)
(*   | ]       *)
and clexp =
  [= `CeApp of (loc * clexp * exp)   (* ce e *)
  | `ClassCon of (loc * virtual_flag * ident * type_parameters)(* virtual v [t]*)
  | `ClassConS of (loc * virtual_flag * ident) (* virtual v *)
  | `CeFun of (loc * pat * clexp) (* fun p -> ce *)
  | `LetIn of (loc * rec_flag * binding * clexp) (* let (rec)? bi in ce *)
  | `Obj of (loc  * cstru) (* object ((p))? (cst)? end *)
  | `ObjEnd of loc (*object end*)
  | `ObjPat of (loc * pat * cstru)(*object (p) .. end*)
  | `ObjPatEnd of (loc * pat) (* object (p) end*)
  | `Constraint of (loc * clexp * cltyp) (* ce : ct *)
  | `And of (loc * clexp * clexp)
  | `Eq  of (loc * clexp * clexp)
  | ant ]
and cstru =
  [=
   `Sem of (loc * cstru * cstru)
  | `Eq of (loc * ctyp * ctyp)
  | `Inherit of (loc * override_flag * clexp)
  | `InheritAs of (loc * override_flag * clexp * alident)
  | `Initializer of (loc * exp)
        (* method(!)? (private)? s : t = e or method(!)? (private)? s = e *)
  | `CrMth of (loc * alident * override_flag * private_flag * exp * ctyp)
  | `CrMthS of (loc * alident * override_flag * private_flag * exp )
        (* value(!)? (mutable)? s = e *)
  | `CrVal of (loc *  alident * override_flag * mutable_flag * exp)
        (* method virtual (private)? s : t *)
  | `VirMeth of (loc * alident * private_flag * ctyp)
        (* val virtual (mutable)? s : t *)
  | `CrVvr of (loc * alident * mutable_flag * ctyp)
  | ant  ]; 
(* Any is necessary, since sometimes you want to [meta_loc_pat] to [_]
   Faked here to make a common subtyp of exp pat to be expnessive enough *)
type ep =
  [= vid
  | `App of (loc * ep * ep)
  | `Vrn of (loc * string)
  | `Com of (loc * ep * ep)
  | `Sem of (loc * ep * ep)
  | `Par of (loc * ep)
  | any
  | `ArrayEmpty of loc 
  | `Array of (loc * ep )
  | `Record of (loc * rec_bind)
  | literal ]
and rec_bind =
  [=  `RecBind of (loc * ident * ep)
  | `Sem of (loc * rec_bind * rec_bind)
  | any
  | ant];
      
      
(* let _loc = FanLoc.ghost; *)
(* #filter "serialize";; *)