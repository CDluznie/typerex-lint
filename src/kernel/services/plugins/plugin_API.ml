(**************************************************************************)
(*                                                                        *)
(*                        OCamlPro Typerex                                *)
(*                                                                        *)
(*   Copyright OCamlPro 2011-2016. All rights reserved.                   *)
(*   This file is distributed under the terms of the GPL v3.0             *)
(*   (GNU General Public Licence version 3.0).                            *)
(*                                                                        *)
(*     Contact: <typerex@ocamlpro.com> (http://www.ocamlpro.com/)         *)
(*                                                                        *)
(*  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,       *)
(*  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES       *)
(*  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND              *)
(*  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS   *)
(*  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN    *)
(*  ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN     *)
(*  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE      *)
(*  SOFTWARE.                                                             *)
(**************************************************************************)

open Plugin_error
open Sempatch

let register_plugin plugin =
  try
    let _ = Plugin.find Globals.plugins plugin in
    raise (Plugin_error(Plugin_already_registered plugin))
  with Not_found ->
    Plugin.add Globals.plugins plugin Lint.empty

let register_main plugin cname new_lint =
  try
    let lints = Plugin.find Globals.plugins plugin in
    try
      let lint = Lint.find cname lints in
      let module Old_Lint = (val lint : Lint_types.LINT) in
      let module New_Lint = (val new_lint : Lint_types.LINT) in
      let module Merge = struct
        let inputs = Old_Lint.inputs @ New_Lint.inputs
        let warnings = Old_Lint.warnings
      end in
      let new_lints =
        Lint.add cname (module Merge : Lint_types.LINT) lints in
      Plugin.add Globals.plugins plugin new_lints
    with Not_found ->
      Plugin.add Globals.plugins plugin (Lint.add cname new_lint lints)
  with Not_found ->
    raise (Plugin_error(Plugin_not_found plugin))

module MakePlugin(P : Plugin_types.PluginArg) = struct

  let name = P.name
  let short_name = P.short_name
  let details = P.details

  module Plugin = struct
    let name = name
    let short_name = short_name
    let details = details
  end
  let plugin = (module Plugin : Plugin_types.PLUGIN)

  let create_option options short_help lhelp ty default =
    Globals.Config.create_option options short_help lhelp 0 ty default

  module MakeLintPatch (C : Lint_types.LintPatchArg) = struct

    let name = C.name
    let short_name = C.short_name
    let details = C.details
    let warnings = Warning.empty ()
    let patches = C.patches

    let create_option option short_help lhelp ty default =
      let option = [P.short_name; C.short_name; option] in
      Globals.Config.create_option option short_help lhelp 0 ty default

    let new_warning loc num cats ~short_name ~msg ~args = (* TODO *)
      let msg = Utils.subsitute msg args in
      Warning.add loc num cats short_name msg warnings

    (* TODO This function should be exported in ocp-sempatch. *)
    let map_args env args =
      List.map (fun str ->
            match Substitution.get str env with
            | Some ast -> (str, Ast_element.to_string ast)
            | None -> (str, "xx"))
        args

    let report matching kinds patch =
      let msg =
        match Patch.get_msg patch with
        (* TODO replace by the result of the patch. *)
          None -> "You should use ... instead of ..."
        | Some msg -> msg in
      (* TODO Warning number can be override by the user. *)
      new_warning (Match.get_location matching) 1 kinds
        ~short_name:(Patch.get_name patch)
        ~msg
        ~args:(map_args
                 (Match.get_substitutions matching)
                 (Patch.get_metavariables patch))

    let patches =
      List.map (fun filename ->
          if Sys.file_exists filename then
            let ic = open_in filename in
            let patches = Patch.from_channel ic in
            close_in ic;
            patches
          else
            (raise (Plugin_error(Patch_file_not_found filename))))
        C.patches

    let iter =
      let module IterArg = struct
        include ParsetreeIter.DefaultIteratorArgument
        let enter_expression expr =
          List.iter (fun patches ->
              let matches =
                Patch.parallel_apply_nonrec patches (Ast_element.Expression expr) in
              List.iter (fun matching ->
                  let patch =
                    List.find
                      (fun p ->
                         Patch.get_name p = Match.get_patch_name matching)
                      patches in
                  report matching [Warning.kind_code] patch)
                matches)
            patches
      end in
      (module IterArg : ParsetreeIter.IteratorArgument)

    let () =
      let module Lint = struct
        let inputs = [Input.InStruct (ParsetreeIter.iter_structure iter)]
        let warnings = warnings
      end in
      let lint = (module Lint : Lint_types.LINT) in

      register_main plugin C.short_name lint;
      let details =  Printf.sprintf "Enable/Disable warnings from %S" name in
      ignore @@
      create_option "warnings" details details SimpleConfig.string_option "+A"
  end (* MakeLintPatch *)

  module MakeLint (C : Lint_types.LintArg) = struct

    let name = C.name
    let short_name = C.short_name
    let details = C.details
    let warnings = Warning.empty ()

    let new_warning loc num cats ~short_name ~msg ~args = (* TODO *)
      let msg = Utils.subsitute msg args in
      Warning.add loc num cats short_name msg warnings

    let create_option option short_help lhelp ty default =
      let option = [P.short_name; C.short_name; option] in
      Globals.Config.create_option option short_help lhelp 0 ty default

    module MakeWarnings (WA : Warning_types.WarningArg) = struct
      type t = WA.t
      let report = WA.report
    end

    module Register(I : Input.INPUT) =
    struct
      let () =
        let module Lint = struct
          let inputs = [ I.input ]
          let warnings = warnings
        end in
        let lint = (module Lint : Lint_types.LINT) in
        register_main plugin C.short_name lint;
        let details =  Printf.sprintf "Enable/Disable warnings from %S" name in
        ignore @@
        create_option "warnings" details details SimpleConfig.string_option "+A"
    end

    module MakeInputStructure(S : Input.STRUCTURE) = struct
      module R = Register(struct let input = Input.InStruct S.main end)
    end

    module MakeInputInterface (I : Input.INTERFACE) = struct
      module R = Register (struct let input = Input.InInterf I.main end)
    end

    module MakeInputToplevelPhrase (T : Input.TOPLEVEL) = struct
      module R = Register (struct let input = Input.InTop T.main end)
    end

    module MakeInputCMT(C : Input.CMT) = struct
      module R = Register (struct let input = Input.InCmt C.main end)
    end

    module MakeInputML (ML : Input.ML) = struct
      module R = Register (struct let input = Input.InMl ML.main end)
    end

    module MakeInputMLI (MLI : Input.MLI) = struct
      module R = Register (struct let input = Input.InMli MLI.main end)
    end

    module MakeInputAll (All : Input.ALL) = struct
      module R = Register (struct let input = Input.InAll All.main end)
    end
  end (* MakeCheck *)

  let () =
    (* Creating default options for plugins: "--plugin.enable" *)
    ignore @@
    create_option
      [P.short_name; "flag"]
      details
      details
      SimpleConfig.enable_option true;

    try
      register_plugin plugin
    with Plugin_error(error) ->
      failwith (Plugin_error.to_string error)
end (* MakePlugin*)
