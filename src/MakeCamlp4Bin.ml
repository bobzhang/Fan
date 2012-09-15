

open Format;
open Camlp4;
open Camlp4Parsers;
open Camlp4Filters;
open FanUtil;
module Camlp4Bin
    (Loc:Sig.Loc) (PreCast:Sig.PRECAST with module Loc = Loc )
    =struct
      open PreCast;
      module CleanAst = Struct.CleanAst.Make PreCast.Ast;


      value printers : Hashtbl.t string (module Sig.PRECAST_PLUGIN) =
        Hashtbl.create 30;
      value dyn_loader = ref (fun () -> failwith "empty in dynloader");
      value rcall_callback = ref (fun () -> ());
      value loaded_modules = ref SSet.empty;
      value add_to_loaded_modules name =
        loaded_modules.val := SSet.add name loaded_modules.val;
          
      (* value plugins = Hashtbl.create 50;      *)
      value (objext,libext) =
        if PreCast.DynLoader.is_native then (".cmxs",".cmxs")
        else (".cmo",".cma");
      
      value rewrite_and_load n x =
        let dyn_loader = dyn_loader.val () in
        let find_in_path = PreCast.DynLoader.find_in_path dyn_loader in
        let real_load name = do {
          add_to_loaded_modules name;
          PreCast.DynLoader.load dyn_loader name
        } in
        let load =  begin fun n ->
          if SSet.mem n loaded_modules.val
          || List.mem n PreCast.loaded_modules.val then ()
          else begin
            add_to_loaded_modules n;
            PreCast.DynLoader.load dyn_loader (n ^ objext);
          end
        end in
        do {
          match (n, String.lowercase x) with
          [ ("Parsers"|"",
             "pa_r.cmo" | "r"|"ocamlr"|"ocamlrevised" | "camlp4ocamlrevisedparser.cmo")
            -> begin
              pa_r (module PreCast) ;
            end
          | ("Parsers"|"",
             "rr" | "reloaded" | "ocamlreloaded"| "camlp4ocamlreloadedparser.cmo")
            -> begin
              pa_rr (module PreCast) ;
          end 
          | ("Parsers"|"",
             "pa_o.cmo"| "o"| "ocaml" | "camlp4ocamlparser.cmo") ->
               begin
                 pa_r (module PreCast);
                 pa_o (module PreCast);
               end 
          | ("Parsers"|"",
             "pa_rp.cmo" | "rp" | "rparser" | "camlp4ocamlrevisedparserparser.cmo")
            -> begin
              pa_r (module PreCast);
              pa_rp (module PreCast);
            end 
          | ("Parsers"|"",
             "pa_op.cmo"| "op" | "parser" | "camlp4ocamlparserparser.cmo")
            -> begin
              pa_r (module PreCast);
              pa_o (module PreCast) ;
              pa_rp (module PreCast) ;
              pa_op (module PreCast);
            end 
          | ("Parsers"|"",
             "pa_extend.cmo" | "pa_extend_m.cmo" | "g" | "grammar" | "camlp4grammarparser.cmo")
            -> begin
              pa_g (module PreCast);
            end 
          | ("Parsers"|"",
             "pa_macro.cmo"  | "m"  | "macro" | "camlp4macroparser.cmo") -> begin
               pa_m (module PreCast);
             end 
          | ("Parsers"|"", "q" | "camlp4quotationexpander.cmo") -> begin
              pa_q (module PreCast); (* no pa_qb any more*)
          end 
          | ("Parsers"|"",
             "q_mlast.cmo" | "rq" | "camlp4ocamlrevisedquotationexpander.cmo")
            -> begin (* no pa_qb any more *)
              pa_rq (module PreCast) ;
            end
          | ("Parsers"|"",
             "oq" | "camlp4ocamloriginalquotationexpander.cmo")
            ->  begin
              pa_r (module PreCast);
              pa_o (module PreCast);
              (* pa_qb;*)
              pa_oq (module PreCast);
            end 
          | ("Parsers"|"", "rf") -> begin
              pa_r (module PreCast);
              pa_rp (module PreCast);
              (* pa_qb; *)
              pa_q (module PreCast);
              pa_g (module PreCast);
              pa_l (module PreCast);
              pa_m (module PreCast);
          end
          | ("Parsers"|"","debug") -> begin
              pa_debug (module PreCast);
          end
          | ("Parsers"|"", "of")
            -> begin
              pa_r (module PreCast);
              pa_o (module PreCast);
              pa_rp (module PreCast);
              pa_op (module PreCast);
              (* pa_qb; *)
              pa_q (module PreCast);
              pa_g (module PreCast);
              pa_l (module PreCast);
              pa_m (module PreCast);
            end
          | ("Parsers"|"",
             "comp" | "camlp4listcomprehension.cmo") ->
               begin
                 pa_l (module PreCast);
               end 
          | ("Filters"|"",
             "lift" | "camlp4astlifter.cmo") -> begin
               f_lift (module PreCast);
             end

          | ("Filters"|"",
             "exn" | "camlp4exceptiontracer.cmo") -> begin
               f_exn (module PreCast);
             end 
          | ("Filters"|"",
             "prof" | "camlp4profiler.cmo") -> begin 
               f_prof (module PreCast);
             end 
          (* map is now an alias of fold since fold handles map too *)
          | ("Filters"|"",
             "map" | "camlp4mapgenerator.cmo") -> begin
               f_fold (module PreCast);
             end 
          | ("Filters"|"", 
             "fold" | "camlp4foldgenerator.cmo") -> begin
               f_fold (module PreCast);
             end 
          | ("Filters"|"",
             "meta" | "camlp4metagenerator.cmo") -> begin
               f_meta (module PreCast);
             end 
          | ("Filters"|"",
             "trash" | "camlp4trashremover.cmo") -> begin
               f_trash (module PreCast);
             end 
          | ("Filters"|"",
             "striploc" | "camlp4locationstripper.cmo") -> begin
               f_striploc (module PreCast);
             end
          | ("Printers"|"",
             "pr_o.cmo" | "o" | "ocaml" | "camlp4ocamlprinter.cmo") -> begin
               PreCast.enable_ocaml_printer ();
             end 
          | ("Printers"|"",
             "pr_dump.cmo" | "p" | "dumpocaml" | "camlp4ocamlastdumper.cmo") ->
              PreCast.enable_dump_ocaml_ast_printer ()
          | ("Printers"|"",
             "d" | "dumpcamlp4" | "camlp4astdumper.cmo") ->
              PreCast.enable_dump_camlp4_ast_printer ()
          | ("Printers"|"",
             "a" | "auto" | "camlp4autoprinter.cmo") ->
               (* FIXME introduced dependency on Unix *)
               (* PreCast.enable_auto (fun [ () -> Unix.isatty Unix.stdout]) *)
               begin
                 load "Camlp4Autoprinter";
                 let (module P ) = Hashtbl.find printers "camlp4autoprinter" in
                 P.apply (module PreCast);
               end
          | _ ->
            let y = "Camlp4"^n^"/"^x^objext in
            real_load (try find_in_path y with [ Not_found -> x ])
          ];
          rcall_callback.val ();
        };
      
      value print_warning = eprintf "%a:\n%s@." PreCast.Loc.print;
      
      value rec parse_file dyn_loader name pa getdir =
        let directive_handler = Some (fun ast ->
          match getdir ast with
          [ Some x ->
              match x with
              [ (_, "load", s) -> do { rewrite_and_load "" s; None }
              | (_, "directory", s) -> do { PreCast.DynLoader.include_dir dyn_loader s; None }
              | (_, "use", s) -> Some (parse_file dyn_loader s pa getdir)
              | (_, "default_quotation", s) -> do { PreCast.Quotation.default.val := s; None }
              | (loc, _, _) -> PreCast.Loc.raise loc (Stream.Error "bad directive") ]
          | None -> None ]) in
        let loc = PreCast.Loc.mk name
        in do {
          PreCast.Syntax.current_warning.val := print_warning;
          let ic = if name = "-" then stdin else open_in_bin name;
          let cs = Stream.of_channel ic;
          let clear () = if name = "-" then () else close_in ic;
          let phr =
            try pa ?directive_handler loc cs
            with x -> do { clear (); raise x };
          clear ();
          phr
        };
      
      value output_file = ref None;
      
      value process dyn_loader name pa pr clean fold_filters getdir =
        let ast = parse_file dyn_loader name pa getdir in
        let ast = fold_filters (fun t filter -> filter t) ast in
        let ast = clean ast in
        pr ?input_file:(Some name) ?output_file:output_file.val ast;
      
      value gind =
        fun
        [ <:sig_item@loc< # $n$ $str:s$ >> -> Some (loc, n, s)
        | _ -> None ];
      
      value gimd =
        fun
        [ <:str_item@loc< # $n$ $str:s$ >> -> Some (loc, n, s)
        | _ -> None ];
      
      value process_intf dyn_loader name =
        process dyn_loader name PreCast.CurrentParser.parse_interf PreCast.CurrentPrinter.print_interf
                (new CleanAst.clean_ast)#sig_item
                AstFilters.fold_interf_filters gind;
      value process_impl dyn_loader name =
        process dyn_loader name PreCast.CurrentParser.parse_implem PreCast.CurrentPrinter.print_implem
                (new CleanAst.clean_ast)#str_item
                AstFilters.fold_implem_filters gimd;
      
      value just_print_the_version () =
        do { printf "%s@." FanConfig.version; exit 0 };
      
      value print_version () =
        do { eprintf "Camlp4 version %s@." FanConfig.version; exit 0 };
      
      value print_stdlib () =
        do { printf "%s@." FanConfig.camlp4_standard_library; exit 0 };
      
      value usage ini_sl ext_sl =
        do {
          eprintf "\
      Usage: camlp4 [load-options] [--] [other-options]\n\
      Options:\n\
      <file>.ml        Parse this implementation file\n\
      <file>.mli       Parse this interface file\n\
      <file>.%s Load this module inside the Camlp4 core@."
      (if DynLoader.is_native then "cmxs     " else "(cmo|cma)")
      ;
          Options.print_usage_list ini_sl;
          (* loop (ini_sl @ ext_sl) where rec loop =
            fun
            [ [(y, _, _) :: _] when y = "-help" -> ()
            | [_ :: sl] -> loop sl
            | [] -> eprintf "  -help         Display this list of options.@." ];    *)
          if ext_sl <> [] then do {
            eprintf "Options added by loaded object files:@.";
            Options.print_usage_list ext_sl;
          }
          else ();
        };
      
      value warn_noassert () =
        do {
          eprintf "\
      camlp4 warning: option -noassert is obsolete\n\
      You should give the -noassert option to the ocaml compiler instead.@.";
        };
      
      type file_kind =
        [ Intf of string
        | Impl of string
        | Str of string
        | ModuleImpl of string
        | IncludeDir of string ];
      
      value search_stdlib = ref True;
      value print_loaded_modules = ref False;
      value (task, do_task) =
        let t = ref None in
        let task f x =
          let () = FanConfig.current_input_file.val := x in
          t.val := Some (if t.val = None then (fun _ -> f x)
                         else (fun usage -> usage ())) in
        let do_task usage = match t.val with [ Some f -> f usage | None -> () ] in
        (task, do_task);
      value input_file x =
        let dyn_loader = dyn_loader.val () in
        do {
          rcall_callback.val ();
          match x with
          [ Intf file_name -> task (process_intf dyn_loader) file_name
          | Impl file_name -> task (process_impl dyn_loader) file_name
          | Str s ->
              begin
                let (f, o) = Filename.open_temp_file "from_string" ".ml";
                output_string o s;
                close_out o;
                task (process_impl dyn_loader) f;
                at_exit (fun () -> Sys.remove f);
              end
          | ModuleImpl file_name -> rewrite_and_load "" file_name
          | IncludeDir dir -> DynLoader.include_dir dyn_loader dir ];
          rcall_callback.val ();
        };
      
      value initial_spec_list =
        [("-I", Arg.String (fun x -> input_file (IncludeDir x)),
          "<directory>  Add directory in search patch for object files.");
        ("-where", Arg.Unit print_stdlib,
          "Print camlp4 library directory and exit.");
        ("-nolib", Arg.Clear search_stdlib,
          "No automatic search for object files in library directory.");
        ("-intf", Arg.String (fun x -> input_file (Intf x)),
          "<file>  Parse <file> as an interface, whatever its extension.");
        ("-impl", Arg.String (fun x -> input_file (Impl x)),
          "<file>  Parse <file> as an implementation, whatever its extension.");
        ("-str", Arg.String (fun x -> input_file (Str x)),
          "<string>  Parse <string> as an implementation.");
        ("-unsafe", Arg.Set FanConfig.unsafe,
          "Generate unsafe accesses to array and strings.");
        ("-noassert", Arg.Unit warn_noassert,
          "Obsolete, do not use this option.");
        ("-verbose", Arg.Set FanConfig.verbose,
          "More verbose in parsing errors.");
        ("-loc", Arg.Set_string Loc.name,
          "<name>   Name of the location variable (default: " ^ Loc.name.val ^ ").");
        ("-QD", Arg.String (fun x -> Quotation.dump_file.val := Some x),
          "<file> Dump quotation expander result in case of syntax error.");
        ("-o", Arg.String (fun x -> output_file.val := Some x),
          "<file> Output on <file> instead of standard output.");
        ("-v", Arg.Unit print_version,
          "Print Camlp4 version and exit.");
        ("-version", Arg.Unit just_print_the_version,
          "Print Camlp4 version number and exit.");
        ("-vnum", Arg.Unit just_print_the_version,
          "Print Camlp4 version number and exit.");
        ("-no_quot", Arg.Clear FanConfig.quotations,
          "Don't parse quotations, allowing to use, e.g. \"<:>\" as token.");
        ("-loaded-modules", Arg.Set print_loaded_modules, "Print the list of loaded modules.");
        ("-parser", Arg.String (rewrite_and_load "Parsers"),
          "<name>  Load the parser Camlp4Parsers/<name>.cm(o|a|xs)");
        ("-printer", Arg.String (rewrite_and_load "Printers"),
          "<name>  Load the printer Camlp4Printers/<name>.cm(o|a|xs)");
        ("-filter", Arg.String (rewrite_and_load "Filters"),
          "<name>  Load the filter Camlp4Filters/<name>.cm(o|a|xs)");
        ("-ignore", Arg.String ignore, "ignore the next argument");
        ("--", Arg.Unit ignore, "Deprecated, does nothing")
      ];
      
      Options.init initial_spec_list;
      
      value anon_fun name =
        input_file
        (if Filename.check_suffix name ".mli" then Intf name
          else if Filename.check_suffix name ".ml" then Impl name
          else if Filename.check_suffix name objext then ModuleImpl name
          else if Filename.check_suffix name libext then ModuleImpl name
          else raise (Arg.Bad ("don't know what to do with " ^ name)));
      
      value main argv =
        let usage () = do { usage initial_spec_list (Options.ext_spec_list ()); exit 0 } in
        try do {
          let dynloader = DynLoader.mk ~ocaml_stdlib:search_stdlib.val
                                       ~camlp4_stdlib:search_stdlib.val ();
          dyn_loader.val := fun () -> dynloader;
          let call_callback () =
            PreCast.iter_and_take_callbacks
              (fun (name, module_callback) ->
                 let () = add_to_loaded_modules name in
                 module_callback ());
          call_callback ();
          rcall_callback.val := call_callback;
          match Options.parse anon_fun argv with
          [ [] -> ()
          | ["-help"|"--help"|"-h"|"-?" :: _] -> usage ()
          | [s :: _] ->
              do { eprintf "%s: unknown or misused option\n" s;
                  eprintf "Use option -help for usage@.";
                  exit 2 } ];
          do_task usage;
          call_callback ();
          if print_loaded_modules.val then do {
            SSet.iter (eprintf "%s@.") loaded_modules.val;
          } else ()
        }
        with
        [ Arg.Bad s -> do { eprintf "Error: %s\n" s;
                            eprintf "Use option -help for usage@.";
                            exit 2 }
        | Arg.Help _ -> usage ()
        | exc -> do { eprintf "@[<v0>%a@]@." FanUtil.ErrorHandler.print exc; exit 2 } ];
      
      main Sys.argv;
            
            
    end ;
    