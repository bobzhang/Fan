open Ocamlbuild_plugin
open Command
open Printf 
open Ocamlbuild_pack
open Tags.Operators
open Tags

  
(** interactive with toplevel
    #directory "+ocamlbuild";;
   #load "ocamlbuildlib.cma";;
   for interactive debugging
 *)

(** utility *)  
let (//) = Filename.concat
let flip f x y = f y x
let verbose = ref false
let debug = ref false    
let menhir_opts = S [A"--dump";A"--explain"; A"--infer";]
let trim_endline str = 
  let len = String.length (str) in 
  if len = 0 then str 
  else if str.[len-1] = '\n' 
  then String.sub str 0 (len-1)
  else str
let site_lib () =
  trim_endline (run_and_read ("ocamlfind printconf destdir"))
let prerr_endlinef fmt =
    ksprintf (fun str-> if !verbose then prerr_endline str) fmt
let run_and_read      = Ocamlbuild_pack.My_unix.run_and_read
let blank_sep_strings = Ocamlbuild_pack.Lexers.blank_sep_strings


(** handle package *)    
let find_packages () =
  blank_sep_strings &
    Lexing.from_string &
    run_and_read "ocamlfind list | cut -d' ' -f1"      

(** list extensions for debug purpose *)
let extensions () = 
  let pas = List.filter 
    (fun x ->
      String.contains_string x  0 "pa_" <> None) (find_packages ()) in 
  let tbl = List.map 
    (fun pkg -> 
      let dir = 
        trim_endline (run_and_read ("ocamlfind query " ^ pkg))in 
      (pkg, dir)) pas in 
  tbl
(** not turned on by default *)    
let _ = 
  if !debug then begin 
    List.iter (fun (pkg,dir) -> Printf.printf "%s,%s\n" pkg dir)
      (extensions ()); 
    Printf.printf "%s\n" (site_lib())
  end

(** test whether compiler_lib installed *)
let compiler_lib_installed =
  try
    Sys.(file_exists &
         (Filename.dirname &
          run_and_read "ocamlfind ocamlc -where | cut -d' ' -f1" ) // "compiler-lib")
  with e -> false

(**
   configuration syntax extensions
   the key is used by ocamlfind query to get its path.
   for example: ocamlfind query bitstring
*)    
let syntax_lib_file
    = ["bitstring",[`D "bitstring.cma" ;
		    `D "bitstring_persistent.cma";
		    `D "pa_bitstring.cmo"]
      ;"ulex",     [`D "pa_ulex.cma"]
      ;"bolt",     [`D "bolt_pp.cmo"]
      ;"xstrp4",   [`D "xstrp4.cma"]
      ;"sexplib",     [`P ("type-conv", "Pa_type_conv.cma"); `D "pa_sexp_conv.cma"]
      ;"mikmatch_pcre", [`D "pa_mikmatch_pcre.cma"]
      ;"meta_filter",    [`D "meta_filter.cma"]
      ;"text", [`D "text.cma"; `D "text-pcre-syntax.cma"]
      ;"type_conv", [`D "pa_type_conv.cma"]   
      ]
let syntax_lib_file_cache
    = ".syntax_lib_file_cache"
let argot_installed  () =
  try
    let path = (trim_endline & run_and_read "ocamlfind query argot") in 
    if Sys.(file_exists path) then  begin 
      flag ["ocaml"; "doc"] (S[A"-i"; A path; A"-g"; A"argot.cmxs"; A"-search"]);
      Log.dprintf 1 "argot plugin hooked to ocamldoc"
    end 
    else Log.dprintf 1 "argot not installed"
  with
    e -> Log.dprintf 1 "argot not installed"
  
exception Next
  
let syntax_path syntax_lib_file = (
  if Sys.file_exists syntax_lib_file_cache then begin
    Log.dprintf 1 "read from .syntax_lib_file_cache";
    let chin = open_in syntax_lib_file_cache in 
    let lst = Marshal.from_channel chin in
    (* List.iter (fun (package,(x,y)) -> (flag x y )) lst ; *)
    List.iter (fun (x,_) ->
      try
        let (a,b) = List.assoc x lst in
        flag a b 
      with
        Not_found ->
          Log.dprintf 1 "syntax package %s not setup" x
              ) syntax_lib_file;
    close_in chin ;
  end 
  else begin
    Log.dprintf 1  ".syntax_lib_file_cache not found";
    let chan = open_out syntax_lib_file_cache in
    let args = ref [] in 
    flip List.iter syntax_lib_file (fun (package, files) ->
      try
        (let package_path =
	  try
	    trim_endline & run_and_read ("ocamlfind query " ^ package )
	  with Failure _ ->
	    prerr_endlinef "package %s does not exist" package;
	    raise Next 
        in
        if Sys.file_exists package_path then
	  let all_path_files  =
	    List.map (fun file ->
	      match file with
	      | `D file ->
		  if Sys.file_exists (package_path//file)
		  then (package_path // file)
		  else
		    (prerr_endlinef "%s does not exist " (package_path//file);
		     raise Next)
	      | `P (package,file) ->
		  let sub_pack =
		    try
		      trim_endline & run_and_read ("ocamlfind query " ^ package)
		    with Failure _ -> begin 
		      prerr_endlinef "%s does not exist in subpackage definition" package;
		      raise Next
		    end 
		  in
		  if Sys.file_exists (sub_pack//file) then
		    (sub_pack // file)
		  else
		    (prerr_endlinef "%s does not exist " (sub_pack//file);
		     raise Next )
	             ) files
	  in begin
            args :=
              (package,
               (["ocaml"; "pp"; "use_"^ package],
               (S(List.map (fun file -> A file)
		   all_path_files)))) ::!args
          end 
        else begin 
	  prerr_endlinef "package %s does not exist" package;
        end 
        )
      with Next -> ());
    Marshal.to_channel chan !args [];
    List.iter (fun (package, (x,y)) -> flag x y ) !args;
    close_out chan
  end )
let camlp4 ?(default = A "camlp4r") ?(printer=A "r")
    tag i o env build = (
  let ml = env i and pp_ml = env o in
  (**
     add a pp here to triger the rule 
     pp, camlp4rf ==> camlp4rf
     don't tag file pp,camlp4rf, it will be inherited by
     .cmo file, and cause trouble there 
   *)
  let tags = (((tags_of_pathname ml) ++ "ocaml" ++ "pp") ) ++ tag in
  (* let () = Log.dprintf 1 "tags: %a" Tags.print tags in *)
  (* let () = List.iter (fun (t,c) *)
  (*   -> Log.dprintf 1 "tag: %a ==> %s" *)
  (*       Tags.print t (Command.string_of_command_spec c)) *)
  (*     (Flags.get_flags ()) in *)
  (** add a
      ocamldep here to trigger the rule
      ocamldep, use_geneq => examples/geneq.cma
      Rule.build_deps_of_tags will try to build the deps 
   *)
  let _deps = Rule.build_deps_of_tags build (tags ++ "ocamldep") in
  (* let () = Log.dprintf 1 "%s" ("["^List.fold_left (^) "" paths ^"]") in *)
  let pp = Command.reduce (Flags.of_tags tags) in
  (* let () = Log.dprintf 1 "pp is reduced to: %s" *)
      (* (Command.string_of_command_spec pp) in *)
  let pp = match pp with | N -> default | _ -> pp in
  (* let () = tag_file o ["pp"; "camlp4r"] in *)
  Cmd (S [ pp; P ml; A "-printer";printer; A "-o"; Px pp_ml ])
)    

      
(** ocamlfind can only handle these two flags *)
let find_syntaxes () = ["camlp4o"; "camlp4r"]
let ocamlfind x = S[A"ocamlfind"; x]
module Default = struct
  let before_options () = (
    Options.ocamlc     := ocamlfind & S[A"ocamlc"; A"-annot";
                                        A"-warn-error";
                                        A"+a-4-6-7-9-27..29"
                                      ];
    Options.ocamlopt   := ocamlfind & S[A"ocamlopt";A"-annot"];
    Options.ocamldep   := ocamlfind & A"ocamldep";
    Options.ocamldoc   := ocamlfind & A"ocamldoc";
    Options.ocamlmktop := ocamlfind & A"ocamlmktop")
  let after_rules () = (
    (*when one link an ocaml library/binary/package, should use -linkpkg*)
    flag ["ocaml"; "byte"; "link";"program"] & A"-linkpkg";
    flag ["ocaml"; "native"; "link";"program"] & A"-linkpkg";
    List.iter begin fun pkg ->
      flag ["ocaml"; "compile";  "pkg_"^pkg] & S[A"-package"; A pkg];
      flag ["ocaml"; "ocamldep"; "pkg_"^pkg] & S[A"-package"; A pkg];
      flag ["ocaml"; "doc";      "pkg_"^pkg] & S[A"-package"; A pkg];
      flag ["ocaml"; "link";     "pkg_"^pkg] & S[A"-package"; A pkg];
      flag ["ocaml"; "infer_interface"; "pkg_"^pkg] & S[A"-package"; A pkg];
      flag ["menhir"] menhir_opts; (* add support for menhir*)
    end (find_packages ());
    (* Like -package but for extensions syntax. Morover -syntax is
     * useless when linking. *)
    List.iter begin fun syntax ->
      flag ["ocaml"; "compile";  "syntax_"^syntax] & S[A"-syntax"; A syntax];
      flag ["ocaml"; "ocamldep"; "syntax_"^syntax] & S[A"-syntax"; A syntax];
      flag ["ocaml"; "doc";      "syntax_"^syntax] & S[A"-syntax"; A syntax];
      flag ["ocaml"; "infer_interface";  "syntax_"^syntax] & S[A"-syntax"; A syntax];
    end (find_syntaxes ());
    (* The default "thread" tag is not compatible with ocamlfind.
       Indeed, the default rules add the "threads.cma" or
       "threads.cmxa" options when using this tag. When using the
       "-linkpkg" option with ocamlfind, this module will then be
       added twice on the command line.
       To solve this, one approach is to add the "-thread" option when using
       the "threads" package using the previous plugin.
     *)
    flag ["ocaml"; "pkg_threads"; "compile"]  (S[A "-thread"]);
    flag ["ocaml"; "pkg_threads"; "link"]     (S[A "-thread"]);
    flag ["ocaml"; "pkg_threads"; "infer_interface"] (S[A "-thread"]);
    
    (** use_compiler_lib support *)
    (if compiler_lib_installed then  begin 
      flag["ocaml"; "byte"; "compile"; "use_compiler_lib"]
        (S[A"-I"; A"+../compiler-lib"]);
      flag["ocaml"; "program"; "byte"; "use_compiler_lib"]
        (S[A"toplevellib.cma"]);
    end 
    else
      prerr_endline "compiler_lib not installed"
    );
    flag["pp"  ; "ocaml"; "use_macro"]  (S[A"-parser"; A"macro"]);
    flag["pp"  ; "ocaml"; "use_map"] (S[A"-filter"; A"map"]);
    flag["pp"  ; "ocaml"; "use_lift"] (S[A"-filter"; A"lift"]);
    flag["pp"  ; "ocaml"; "use_fold"] (S[A"-filter"; A"fold"]);
    flag["pp"  ; "ocaml"; "use_debug"] (S[A"-parser"; A"Camlp4DebugParser.cmo"]);
    flag ["link";"ocaml";"g++";] (S[A"-cc"; A"g++"]);
    flag ["ocaml"; "doc"]  (S [A"-keep-code"]);
    argot_installed ();
    flag ["ocaml"; "doc"; "use_camlp4"] (S[A"-I"; A"+camlp4"]);)
end


type actions =  (unit -> unit) list ref
let before_options : actions = ref []
and after_options : actions = ref []
and before_rules : actions = ref []
and after_rules : actions = ref []
let (+>) x l =  l := x :: !l

(** demo how to use external libraries
    ocaml_lib ~extern:true "llvm";
    ocaml_lib ~extern:true "llvm_analysis";
    ocaml_lib ~extern:true "llvm_bitwriter";
    dep ["link"; "ocaml"; "use_plus_stubs"] ["plus_stubs.o"];
    flag["link"; "ocaml"; "byte"] (S[A"-custom"]);
    dep ["ocamldep"; "file:test_lift_filter_r.ml"] ["test_type_r.ml"];
    dep ["ocamldep"; "file:test_lift_filter.ml"] ["test_type.ml"];
    dep ["ocamldep"; "file:test_dump.ml"] ["test_type_r.ml"];
    dep ["ocamldep"; "file:test_lift_filter.pp.ml"] ["test_type.ml"];
    demo how to use dep
        dep ["ocamldep"; "file:test/test_string.ml"]
        ["test/test_data/string.txt";
        "test/test_data/char.txt"];
    *)
  
let apply  () = (
  Default.before_options +> before_options;
  Default.after_rules +> after_rules;
  (fun _ -> begin
    syntax_path syntax_lib_file;
    flag ["ocaml"; "pp"; "use_camlp4ext"] (A"camlp4util.cma");
    dep ["ocamldep"; "use_camlp4ext"] ["camlp4util.cma"];
    (** insert here *)
  end) +> after_rules;
  dispatch begin function
    | Before_options -> begin
        List.iter (fun f -> f () ) !before_options;
    end
    | After_rules -> begin
        List.iter (fun f -> f ()) !after_rules;
    end
    | _ -> ()
  end ;
 )


let _ = (
  rule "preprocess: ml -> _pp.ml" ~dep: "%.ml" ~prod: "%_pp.ml"
    (camlp4 "%_pp.ml" "%.ml" "%_pp.ml");
  rule "preprocess: ml -> _ppo.ml" ~dep: "%.ml" ~prod: "%_ppo.ml"
    (camlp4 ~printer:(A"o") "%_ppo.ml" "%.ml" "%_ppo.ml");
  apply ();
 )
  
  


