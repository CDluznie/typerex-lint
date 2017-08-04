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
open Lint_warning_types
open Lint_web_analysis_info
open Web_file_content_data

let warning_content_code_view_header warning_info =
  div
    ~a:[
      a_class ["panel-heading"];
    ]
    [
      a
        ~a:[
          a_href (Web_utils.file_href warning_info.warning_file);
        ]
        [pcdata warning_info.warning_file.file_name]
    ]

let warning_content_code_view_body warning_info =
  div
    ~a:[
      a_class ["panel-body"];
    ]
    [
      Web_utils.warning_code_viewer warning_info;
    ]

let warning_content_code_view warning_info =
  div
    ~a:[
      a_class ["panel"; "panel-default"];
    ]
    [
      warning_content_code_view_header warning_info;
      warning_content_code_view_body warning_info;
    ]

let warning_content warning_info =
  let warning_desc =
    Printf.sprintf "Warning #%d :"
      warning_info.warning_id
  in
  let linter_desc =
    Printf.sprintf "%s : %s"
      warning_info.warning_linter.linter_name
      warning_info.warning_linter.linter_description
  in
  let code_view =
    if Web_utils.warning_info_is_ghost warning_info then
      Web_utils.html_empty_node ()
    else
      div
	[
	  br ();
	  warning_content_code_view warning_info;
	]
  in
  div
    ~a:[
      a_class ["hideable-content"];
    ]
    [
      h3 [pcdata warning_desc];
      br ();
      h4 [pcdata linter_desc];
      code_view;
    ]

let error_content error_info =
  let error_desc =
    Printf.sprintf "Error #%d :"
      error_info.error_id
  in
  let output_desc =
    Printf.sprintf "%s : %s"
      (Web_utils.error_type error_info)
      (Web_utils.error_description error_info)
  in
  div
    ~a:[
      a_class ["hideable-content"];
    ]
    [
      h3 [pcdata error_desc];
      br ();
      h4 [pcdata output_desc];
    ]

let file_code_viewer_header file_info =
  div
    ~a:[
      a_class ["panel-heading"];
    ]
    [
      a
       ~a:[
          a_href (Web_utils.file_href file_info);
        ]
        [pcdata file_info.file_name]
    ]

let file_code_viewer_body file_info =
  div
    ~a:[
      a_class ["panel-body"];
    ]
    [
      Web_utils.file_code_viewer file_info;
    ]

let file_code_viewer file_info =
  div
    ~a:[
      a_class ["panel"; "panel-default"];
    ]
    [
      file_code_viewer_header file_info;
      file_code_viewer_body file_info;
    ]

let all_file_content file_info =
  div
    ~a:[
      a_class ["hideable-content"];
    ]
    [
      h3 [pcdata "All file"];
      br ();
      file_code_viewer file_info;
    ]

let main_content_creator file_info file_content_type =
  let content =
    match file_content_type with
    | File_content ->
       all_file_content file_info
    | Warning_content warning_info ->
       (* todo maybe check if warning.file = file *)
       warning_content warning_info
    | Error_content error_info ->
       (* todo maybe check if error.file = file *)
       error_content error_info
  in
  Tyxml_js.To_dom.of_element content

let filter_dropdown_simple_selection value label_value on_click =
  let severity_selection =
    a
      [
	label
	  ~a:[
            a_class ["filter-label";];
	  ]
	  [
            pcdata label_value;
	  ]
      ]
  in
  let dom_selection = Tyxml_js.To_dom.of_a severity_selection in
  dom_selection##onclick <- Dom_html.handler begin fun _ ->
    on_click value dom_selection;
    Js._true
  end;
  li
    [
      severity_selection;
    ]

let filter_dropdown_checkbox_selection value label_value on_select on_deselect =
  let checkbox =
    input
      ~a:[
        a_class ["filter-checkbox"];
        a_input_type `Checkbox;
        a_checked ();
      ] ();
  in
  let dom_checkbox = Tyxml_js.To_dom.of_input checkbox in
  let is_selected () = Js.to_bool dom_checkbox##checked in
  dom_checkbox##onclick <- Dom_html.handler begin fun _ ->
    if is_selected () then
      on_select value
    else
      on_deselect value
    ;
    Js._true
  end;
  li
    [
      a
        [
	  checkbox;
          label
            ~a:[
              a_class ["filter-label";];
            ]
            [
              pcdata label_value;
            ];
	]
    ]

let filter_dropdown_menu label_value dropdown_selections =
  div
    ~a:[
      a_class ["dropdown"];
    ]
    [
      button
        ~a:[
          a_class ["btn"; "btn-default"; "dropdown-toggle"];
          a_button_type `Button;
          a_user_data "toggle" "dropdown";
        ]
        [
          pcdata (label_value ^ " "); (* todo change *)
          span ~a:[a_class ["caret"]] [];
        ];
      ul
        ~a:[
          a_class ["dropdown-menu"];
        ]
        dropdown_selections;
      ]

let warnings_dropdown warnings_info file_content_data =
  let on_select warning =
    Web_filter_system.remove_filter
      file_content_data.file_content_filtersys
      (Warning_type_filter warning)
    ;
    Web_filter_system.eval_filters
      file_content_data.file_content_filtersys
  in
  let on_deselect warning =
    let filter_type = Warning_type_filter warning in
    Web_filter_system.add_filter
      file_content_data.file_content_filtersys
      filter_type
      (Web_file_content_data.filter_value filter_type)
    ;
    Web_filter_system.eval_filters
      file_content_data.file_content_filtersys
  in
  let selections =
    List.map begin fun warning_info ->
      filter_dropdown_checkbox_selection
        warning_info
        (Web_utils.warning_name warning_info)
        on_select
        on_deselect
    end warnings_info
  in
  filter_dropdown_menu "warnings" selections

let severity_dropdown file_content_data =
  let active_class = Js.string "dropdown-selection-active" in
  let previous_severity = ref None in
  let on_click severity label =
    begin match !previous_severity with
    | Some (svt, lbl) ->
       Web_filter_system.remove_filter
         file_content_data.file_content_filtersys
         (Higher_severity_filter svt)
       ;
       lbl##classList##remove (active_class)
    | None ->
       ()
    end;
    let filter_type = Higher_severity_filter severity in
    Web_filter_system.add_filter
      file_content_data.file_content_filtersys
      filter_type
      (Web_file_content_data.filter_value filter_type)
    ;
    label##classList##add (active_class);
    previous_severity := Some (severity, label);
    Web_filter_system.eval_filters
      file_content_data.file_content_filtersys
  in
  let selections =
    List.map begin fun severity ->
      filter_dropdown_simple_selection
        severity
	(string_of_int severity)
	on_click
    end [1;2;3;4;5;6;7;8;9;10]
  in
  filter_dropdown_menu "severity" selections

let filter_searchbox file_content_data =
  let searchbox =
    input
      ~a:[
        a_input_type `Text;
        a_class ["form-control"; "filter-searchbox"];
        a_placeholder "Search..."
      ] ()
  in
  let searchbox_dom = Tyxml_js.To_dom.of_input searchbox in
  let get_keyword () =
    let str = Js.to_string (searchbox_dom##value) in
    if str = "" then
      None
    else
      Some str
  in
  let previous_keyword = ref None in
  searchbox_dom##onkeyup <- Dom_html.handler begin fun _ ->
    let keyword = get_keyword () in
    begin match !previous_keyword with
    | Some kwd ->
       Web_filter_system.remove_filter
         file_content_data.file_content_filtersys
         (Keyword_filter kwd)
    | None ->
       ()
    end;
    begin match keyword with
    | Some kwd ->
       let filter_type = Keyword_filter kwd in
       Web_filter_system.add_filter
         file_content_data.file_content_filtersys
         filter_type
         (Web_file_content_data.filter_value filter_type)
    | None ->
       ()
    end;
    previous_keyword := keyword;
    Web_filter_system.eval_filters
      file_content_data.file_content_filtersys
    ;
    Js._true
  end;
  searchbox

let warnings_filter warnings_info file_content_data =
  let uniq_warnings_info =
    warnings_info
    |> List.sort Web_utils.warning_compare
    |> Web_utils.remove_successive_duplicates Web_utils.warning_equals
  in
  div
    ~a:[
      a_class ["dashboard-filter"];
    ]
    [
      warnings_dropdown uniq_warnings_info file_content_data;
      div ~a:[a_class ["filter-separator"]] [];
      severity_dropdown file_content_data;
      div ~a:[a_class ["filter-separator"]] [];
      filter_searchbox file_content_data;
    ]

let warnings_table_col_id warning_info =
  pcdata (string_of_int warning_info.warning_id)

let warnings_table_col_plugin warning_info =
  pcdata warning_info.warning_linter.linter_plugin.plugin_name

let warnings_table_col_linter warning_info =
  pcdata warning_info.warning_linter.linter_name

let warnings_table_col_warning warning_info =
  pcdata warning_info.warning_type.decl.short_name

let warnings_table_col_severity warning_info =
  pcdata (string_of_int warning_info.warning_type.decl.severity)

let warnings_table_entry warning_info file_content_data =
  let tr =
    tr
      [
        td [warnings_table_col_id warning_info];
        td [warnings_table_col_plugin warning_info];
        td [warnings_table_col_linter warning_info];
        td [warnings_table_col_warning warning_info];
	td [warnings_table_col_severity warning_info];
      ]
  in
  let dom_tr = Tyxml_js.To_dom.of_element tr in
  dom_tr##onclick <-Dom_html.handler begin fun _ ->
    focus_file_content file_content_data (Warning_content warning_info);
    Js._true
  end;
  Web_filter_system.register_element
    file_content_data.file_content_filtersys
    warning_info
    dom_tr
  ;
  tr

let warnings_table_head () =
  thead
    [
      tr
        [
          th [pcdata "Identifier"];
          th [pcdata "Plugin"];
          th [pcdata "Linter"];
          th [pcdata "Warning"];
	  th [pcdata "Severity"];
        ]
    ]

let warnings_table warnings_info file_content_data =
  let entry_creator warning_info =
    warnings_table_entry warning_info file_content_data
  in
  let table =
    tablex
      ~a:[
        a_class ["file-content-table"; "warnings-file-content-table"];
      ]
      ~thead:(warnings_table_head ())
      [
        tbody (List.map entry_creator warnings_info);
      ]
  in
  table

let errors_table_col_id error_info =
  pcdata (string_of_int error_info.error_id)

let errors_table_col_error error_info =
  let str_error =
    match error_info.error_type with
    | Lint_db_types.Db_error _ -> "db_error"
    | Lint_db_types.Plugin_error _ -> "plugin_error"
    | Lint_db_types.Sempatch_error _ -> "sempatch_error"
    | Lint_db_types.Ocplint_error _ -> "ocplint_error"
  in
  pcdata str_error
    
let errors_table_entry error_info file_content_data =
  let tr =
    tr
      [
        td [errors_table_col_id error_info];
        td [errors_table_col_error error_info];
      ]
  in
  let dom_tr = Tyxml_js.To_dom.of_element tr in
  dom_tr##onclick <-Dom_html.handler begin fun _ ->
    focus_file_content file_content_data (Error_content error_info);
    Js._true
  end;
  tr

let errors_table_head () =
  thead
    [
      tr
        [
          th [pcdata "Identifier"];
          th [pcdata "Error"];
        ]
    ]

let errors_table errors_info file_content_data =
  let entry_creator error_info =
    errors_table_entry error_info file_content_data
  in
  tablex
    ~a:[
      a_class ["file-content-table"; "errors-file-content-table"];
    ]
    ~thead:(errors_table_head ())
    [
      tbody (List.map entry_creator errors_info);
    ]

let hideable_summary title content =
  let opened_icon = "glyphicon-menu-down" in
  let closed_icon = "glyphicon-menu-right" in
  let title =
    div
      ~a:[
	a_class ["subsummary-title"];
      ]
      [
	h3 [pcdata title];
      ]
  in
  let icon =
    span
      ~a:[
	a_class ["glyphicon"];
      ]
      [
      ]
  in
  let dom_title = Tyxml_js.To_dom.of_element title in
  let dom_icon = Tyxml_js.To_dom.of_element icon in
  let dom_content = Tyxml_js.To_dom.of_element content in
  let set_close () =
    Web_utils.dom_element_undisplay dom_content;
    dom_icon##classList##remove (Js.string opened_icon);
    dom_icon##classList##add (Js.string closed_icon)
  in
  let set_open () =
    Web_utils.dom_element_display dom_content;
    dom_icon##classList##remove (Js.string closed_icon);
    dom_icon##classList##add (Js.string opened_icon);
  in
  let reverse_content_display _ =
    if Web_utils.dom_element_is_display dom_content then begin
      set_close ()
    end else begin
      set_open ()
    end;
    Js._true
  in
  set_close ();
  dom_title##onclick <-Dom_html.handler reverse_content_display;
  dom_icon##onclick <-Dom_html.handler reverse_content_display;
  div
    [
      div
	~a:[
	  a_class ["row"];
	]
	[
	  div
	    ~a:[
	      a_class [
		  "col-md-2";
		  "row-vertical-center"
		];
	    ]
	    [
	      title;
	      icon;
	    ];
	  div
	    ~a:[
	      a_class [
		  "col-md-10";
		  "row-vertical-center";
		  "horizontal-separator";
	      ];
	    ]
	    [];
	];
      content;
    ]

let warnings_summary_content all_file_warnings_info file_content_data =
  div
    [
      br ();
      br ();
      warnings_filter all_file_warnings_info file_content_data;
      br ();
      warnings_table all_file_warnings_info file_content_data;
    ]

let warnings_summary_content_empty () =
  div
    [
      br ();
      h4 [pcdata "No provided warnings in this file"];
    ]

let warnings_summary all_file_warnings_info file_content_data =
  let content = 
  if Web_utils.list_is_empty all_file_warnings_info then
    warnings_summary_content_empty ()
  else
    warnings_summary_content all_file_warnings_info file_content_data
  in
  hideable_summary "All warnings" content

let errors_summary_content all_file_errors_info file_content_data =
  div
    [
      br ();
      br ();
      (* todo filter *)
      br ();
      errors_table all_file_errors_info file_content_data;
    ]

let errors_summary_content_empty () =
  div
    [
      br ();
      h4 [pcdata "No provided errors in this file"];
    ]
 
let errors_summary all_file_errors_info file_content_data =
  let content =
    if Web_utils.list_is_empty all_file_errors_info then
      errors_summary_content_empty ()
    else
      errors_summary_content all_file_errors_info file_content_data
  in
  hideable_summary "All errors" content

let content_head file_content_data =
  let warnings_button =
    button
      ~a:[
        a_button_type `Button;
        a_class ["btn"; "btn-warning"];
      ]
      [pcdata "Show warnings"]
  in
  let errors_button =
    button
      ~a:[
        a_button_type `Button;
        a_class ["btn"; "btn-danger"];
      ]
      [pcdata "Show errors"]
  in
  let all_file_button =
    button
      ~a:[
        a_button_type `Button;
        a_class ["btn"; "btn-info"];
      ]
      [pcdata "See all file"]
  in
  (Tyxml_js.To_dom.of_element all_file_button)##onclick <-Dom_html.handler
  begin fun _ ->
    focus_file_content file_content_data File_content;
    Js._true
  end;
  div
    ~a:[
      a_class ["row"; "content-head"];
    ]
    [
      div
	~a:[
	  a_class ["col-md-6"; "row-vertical-center"];
	]
	[
	  h2 [pcdata file_content_data.file_content_info.file_name];
	];
      div
	~a:[
	  a_class ["col-md-2"; "row-vertical-center"];
	]
	[
	  warnings_button;
	];
      div
	~a:[
	  a_class ["col-md-2"; "row-vertical-center"];
	]
	[
	  errors_button;
	];
      div
	~a:[
	  a_class ["col-md-2"; "row-vertical-center"];
	]
	[
	  all_file_button;
	];
    ]

let content all_file_warnings_info all_file_errors_info file_content_data =
  let content_div =
    Tyxml_js.Of_dom.of_element
      (file_content_data.file_content_container)
  in
  let separator () =
    div
      ~a:[
	a_class ["row"];
      ]
      [
	div
	  ~a:[
	    a_class ["col-md-12"; "horizontal-separator"];
	  ]
	  [];
      ]
  in
  div
    ~a:[
      a_class ["container"];
    ]
    [
      content_head file_content_data;
      br ();
      br ();
      separator ();
      br ();
      br ();
      content_div;
      br ();
      br ();
      warnings_summary all_file_warnings_info file_content_data;
      br ();
      br ();
      errors_summary all_file_errors_info file_content_data;
    ]

let new_file_content_data_of_file_info file_info =
  Web_file_content_data.create_file_content_data
    file_info
    (div [])
    (main_content_creator file_info)

let open_tab file_info file_warnings_info file_errors_info =
  let open Web_navigation_system in
  (* todo improve *)
  let file_content_data = new_file_content_data_of_file_info file_info in
  let content =
    content file_warnings_info file_errors_info file_content_data
  in
  let attach =
    open_tab
      (FileElement file_info)
      (Web_utils.file_short_name file_info)
      (content)
      begin fun () ->
        File_content_attached_data file_content_data
      end
  in
  match attach with
  | File_content_attached_data file_content_data -> file_content_data
  | _ -> failwith "bad attach" (* todo web err *)
