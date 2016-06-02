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

open SimpleConfig (* for !! *)
open Plugin_text

let default_value = 80

let details =
  Printf.sprintf
    "Checks long lines in your code. The default value is %d."
    default_value

module CodeLength = PluginText.MakeLint(struct
    let name = "Code Length"
    let short_name = "code_length"
    let details = details
    let enable = false
  end)

type warning = LongLine of (int * int)

let line_too_long = CodeLength.new_warning
    ~id:1
    ~short_name:"long_line"
    ~msg:"This line is too long ('$line'): it should be at \
          most of size '$max'."

module Warnings = CodeLength.MakeWarnings(struct
    type t = warning

    let to_warning = function
      | LongLine (max, len) ->
        line_too_long,
        [("line", string_of_int len); ("max", string_of_int max)]
  end)

let check_line lnum max_line_length file line =
  let line_len = String.length line in
  if line_len > max_line_length then
    Warnings.report_file file (LongLine (max_line_length, line_len))

let check_file max_line_length file =
  let ic = open_in file in
  let rec loop lnum ic =
    try
      check_line lnum max_line_length file (input_line ic);
      loop (lnum + 1) ic
    with End_of_file -> () in
  loop 1 ic;
  close_in ic

(* Defining/Using option from configuration file / command line *)
let max_line_length = CodeLength.create_option
    "max_line_length"
    "Maximum line length"
    "Maximum line length"
    SimpleConfig.int_option
    default_value

(* Registering a main entry to the linter *)
module MainSRC = CodeLength.MakeInputML(struct
    let main source = check_file !!max_line_length source
  end)