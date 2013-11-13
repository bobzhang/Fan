let cstream = Compile_stream.cstream
let exp = Syntaxf.exp
let stream_exp = Gramf.mk "stream_exp"
let stream_exp_comp = Gramf.mk "stream_exp_comp"
let stream_exp_comp_list = Gramf.mk "stream_exp_comp_list"
let _ =
  Gramf.extend_single (stream_exp : 'stream_exp Gramf.t )
    ({
       label = None;
       assoc = true;
       productions =
         [{
            symbols =
              [Token
                 ({ descr = { tag = `Key; word = (A "!"); tag_name = "Key" }
                  } : Tokenf.pattern );
              Token
                ({ descr = { tag = `Uid; word = Any; tag_name = "Uid" } } : 
                Tokenf.pattern )];
            annot =
              "Ref.protect Compile_stream.grammar_module_name n\n  (fun _  -> Compile_stream.empty _loc)\n";
            fn =
              (Gramf.mk_action
                 (fun ~__fan_1:(__fan_1 : Tokenf.txt)  ~__fan_0:_ 
                    (_loc : Locf.t)  ->
                    let n = __fan_1.txt in
                    (Ref.protect Compile_stream.grammar_module_name n
                       (fun _  -> Compile_stream.empty _loc) : 'stream_exp )))
          };
         {
           symbols =
             [Token
                ({ descr = { tag = `Key; word = (A "!"); tag_name = "Key" } } : 
                Tokenf.pattern );
             Token
               ({ descr = { tag = `Uid; word = Any; tag_name = "Uid" } } : 
               Tokenf.pattern );
             Nterm
               (Gramf.obj
                  (stream_exp_comp_list : 'stream_exp_comp_list Gramf.t ))];
           annot =
             "Ref.protect Compile_stream.grammar_module_name n (fun _  -> cstream _loc sel)\n";
           fn =
             (Gramf.mk_action
                (fun ~__fan_2:(sel : 'stream_exp_comp_list) 
                   ~__fan_1:(__fan_1 : Tokenf.txt)  ~__fan_0:_ 
                   (_loc : Locf.t)  ->
                   let n = __fan_1.txt in
                   (Ref.protect Compile_stream.grammar_module_name n
                      (fun _  -> cstream _loc sel) : 'stream_exp )))
         };
         {
           symbols =
             [Nterm
                (Gramf.obj
                   (stream_exp_comp_list : 'stream_exp_comp_list Gramf.t ))];
           annot = "cstream _loc sel\n";
           fn =
             (Gramf.mk_action
                (fun ~__fan_0:(sel : 'stream_exp_comp_list)  (_loc : Locf.t) 
                   -> (cstream _loc sel : 'stream_exp )))
         };
         {
           symbols = [];
           annot = "Compile_stream.empty _loc\n";
           fn =
             (Gramf.mk_action
                (fun (_loc : Locf.t)  ->
                   (Compile_stream.empty _loc : 'stream_exp )))
         }]
     } : Gramf.olevel );
  Gramf.extend_single (stream_exp_comp : 'stream_exp_comp Gramf.t )
    ({
       label = None;
       assoc = true;
       productions =
         [{
            symbols = [Nterm (Gramf.obj (exp : 'exp Gramf.t ))];
            annot = "(Trm (_loc, e) : Compile_stream.sexp_comp )\n";
            fn =
              (Gramf.mk_action
                 (fun ~__fan_0:(e : 'exp)  (_loc : Locf.t)  ->
                    ((Trm (_loc, e) : Compile_stream.sexp_comp ) : 'stream_exp_comp )))
          };
         {
           symbols =
             [Token
                ({ descr = { tag = `Key; word = (A "'"); tag_name = "Key" } } : 
                Tokenf.pattern );
             Nterm (Gramf.obj (exp : 'exp Gramf.t ))];
           annot = "Ntr (_loc, e)\n";
           fn =
             (Gramf.mk_action
                (fun ~__fan_1:(e : 'exp)  ~__fan_0:_  (_loc : Locf.t)  ->
                   (Ntr (_loc, e) : 'stream_exp_comp )))
         }]
     } : Gramf.olevel );
  Gramf.extend_single (stream_exp_comp_list : 'stream_exp_comp_list Gramf.t )
    ({
       label = None;
       assoc = true;
       productions =
         [{
            symbols =
              [Nterm
                 (Gramf.obj (stream_exp_comp : 'stream_exp_comp Gramf.t ));
              Token
                ({ descr = { tag = `Key; word = (A ";"); tag_name = "Key" } } : 
                Tokenf.pattern );
              Self];
            annot = "se :: sel\n";
            fn =
              (Gramf.mk_action
                 (fun ~__fan_2:(sel : 'stream_exp_comp_list)  ~__fan_1:_ 
                    ~__fan_0:(se : 'stream_exp_comp)  (_loc : Locf.t)  -> (se
                    :: sel : 'stream_exp_comp_list )))
          };
         {
           symbols =
             [Nterm (Gramf.obj (stream_exp_comp : 'stream_exp_comp Gramf.t ));
             Token
               ({ descr = { tag = `Key; word = (A ";"); tag_name = "Key" } } : 
               Tokenf.pattern )];
           annot = "[se]\n";
           fn =
             (Gramf.mk_action
                (fun ~__fan_1:_  ~__fan_0:(se : 'stream_exp_comp) 
                   (_loc : Locf.t)  -> ([se] : 'stream_exp_comp_list )))
         };
         {
           symbols =
             [Nterm (Gramf.obj (stream_exp_comp : 'stream_exp_comp Gramf.t ))];
           annot = "[se]\n";
           fn =
             (Gramf.mk_action
                (fun ~__fan_0:(se : 'stream_exp_comp)  (_loc : Locf.t)  ->
                   ([se] : 'stream_exp_comp_list )))
         }]
     } : Gramf.olevel )
let _ = Ast_quotation.of_exp ~name:(Ns.lang, "stream") ~entry:stream_exp ()
