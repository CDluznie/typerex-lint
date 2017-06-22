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

open Tyxml_js.Html
open Ace
open Lint_warning_types
open Lint_web_warning
       
(* todo ajouter fonction pour voir tout le fichier avec les warnings *)
       
(*******)
let find_component id =
  match Js_utils.Manip.by_id id with
  | Some div -> div
  | None -> failwith ("Cannot find id " ^ id)
(*******)		     

let theme =
  "monokai"

let font_size =
  14

let line_size =
  17
    
let context_line_number =
  3
  
let code_viewer_register_warning ace warning =
  let begin_line, begin_col, end_line, end_col =
    let open Web_utils in
    match file_loc_of_loc warning.loc with
    | Some (Floc_line line) ->
       line, 0, line, String.length (Ace.get_line ace (line - 1)) 
    | Some (Floc_lines_cols (bline, bcol, eline, ecol)) ->
       bline, bcol, eline, ecol
    | None ->
       failwith "no location for this warning"
  in
  let length = Ace.get_length ace in (* todo change *)
  let begin_context = min (begin_line - 1) context_line_number in
  let end_context = min (length - end_line) context_line_number in
  let begin_with_context = begin_line - begin_context in
  let end_with_context = end_line + end_context in
  (***** verifier si warning au limite *****)
  let loc = {
    loc_start = begin_context + 1, begin_col;
    loc_end = begin_context + end_line - begin_line + 1, end_col
  } in
  (*****************************************)
  let content =
    Web_utils.array_joining
      "\n"
      (Ace.get_lines ace (begin_with_context - 1) (end_with_context - 1))
  in
  Ace.set_value ace content;
  Ace.clear_selection ace;
  Ace.set_option ace "firstLineNumber" begin_with_context;
  Ace.add_marker ace Ace.Warning loc;
  Ace.set_annotation ace Ace.Warning warning.output loc
  
let create_ocaml_code_viewer div warning =
  let ace = Ace.create_editor div in
  Ace.set_mode ace "ace/mode/ocaml";
  Ace.set_theme ace ("ace/theme/" ^ theme);
  Ace.set_font_size ace font_size;
  Ace.set_read_only ace true;
  code_viewer_register_warning ace warning

let set_div_ocaml_code_view warning =
  let code_div =
    find_component "ocp-code-viewer" (***** code id dans lint_web ****)
  in
  create_ocaml_code_viewer (Tyxml_js.To_dom.of_div code_div) warning
			   
let onload _ =
  let json = Web_utils.json_from_js_var "json" in
  let id =
    try
      int_of_string (Url.Current.get_fragment ())
    with
    | Failure _ -> failwith "invalid id"
  in
  let entry =
    try
      json
      |> database_warning_entries_of_json
      |> List.find (fun entry -> entry.id = id)
    with
    | Not_found -> failwith "invalid id"
  in
  set_div_ocaml_code_view entry.warning_result;
  Js._true

let () =
  Dom_html.window##onload <- Dom_html.handler onload

let file_code_viewer = (* todo *)
  ()
					      
let warning_code_viewer warning_entry =
  let warning = warning_entry.warning_result in
  (* todo fun *)
  let begin_line, end_line =
    let open Web_utils in
    match file_loc_of_loc warning.loc with
    | Some (Floc_line line) ->
       line, line
    | Some (Floc_lines_cols (bline, _, eline, _)) ->
       bline, eline
    | None ->
       failwith "no location for this warning"
  in
  let length = warning_entry.lines_count in
  let begin_context = min (begin_line - 1) context_line_number in
  let end_context = min (length - end_line) context_line_number in
  let begin_with_context = begin_line - begin_context in
  let end_with_context = end_line + end_context in
  (*          *)

  let height =
    line_size * (end_with_context - begin_with_context + 2)
  in
  iframe
    ~a:[
	a_src (Web_utils.warning_href warning_entry);
	a_style ("height: " ^ (string_of_int height) ^ "px");
    ]
    []