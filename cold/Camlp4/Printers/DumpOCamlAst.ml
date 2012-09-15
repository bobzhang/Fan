module Id : Sig.Id =
 struct
  let name = "Camlp4Printers.DumpOCamlAst"

  let version = Sys.ocaml_version

 end

module Make =
       functor (Syntax : Sig.Camlp4Syntax) ->
        (struct
          module Ast2pt = (Struct.Camlp4Ast2OCamlAst.Make)(Syntax.Ast)

          let print_interf =
           fun ?(input_file = "-") ->
            fun ?output_file ->
             fun ast ->
              let pt = (Ast2pt.sig_item ast) in
              let open
              FanUtil in
              (with_open_out_file output_file (
                (dump_pt FanConfig.ocaml_ast_intf_magic_number input_file pt)
                ))

          let print_implem =
           fun ?(input_file = "-") ->
            fun ?output_file ->
             fun ast ->
              let pt = (Ast2pt.str_item ast) in
              let open
              FanUtil in
              (with_open_out_file output_file (
                (dump_pt FanConfig.ocaml_ast_impl_magic_number input_file pt)
                ))

         end : Sig.Printer(Syntax.Ast).S)